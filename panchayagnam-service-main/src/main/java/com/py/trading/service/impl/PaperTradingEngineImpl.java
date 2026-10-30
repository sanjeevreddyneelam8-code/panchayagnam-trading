package com.py.trading.service.impl;

import com.py.brokers.angel.dto.Order;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.easytrade.dto.IndividualOrderRequest;
import com.py.easytrade.entity.IndividualOrderAuditEntity;
import com.py.easytrade.repository.IndividualOrderAuditRepository;
import com.py.entity.PyUser;
import com.py.repo.PyUserRepository;
import com.py.trading.entity.PaperAccountBalanceEntity;
import com.py.trading.entity.PaperPositionEntity;
import com.py.trading.repository.PaperAccountBalanceRepository;
import com.py.trading.repository.PaperPositionRepository;
import com.py.trading.service.PaperTradingEngine;
import com.py.trading.service.PaperTradingService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
public class PaperTradingEngineImpl implements PaperTradingEngine {

    private static final Logger log = LoggerFactory.getLogger(PaperTradingEngineImpl.class);

    private final PaperTradingService paperTradingService;
    private final PaperAccountBalanceRepository balanceRepository;
    private final PaperPositionRepository positionRepository;
    private final IndividualOrderAuditRepository auditRepository;
    private final PyUserRepository userRepository;
    private final PaperAccountBalanceInitializer balanceInitializer;

    public PaperTradingEngineImpl(PaperTradingService paperTradingService,
                                  PaperAccountBalanceRepository balanceRepository,
                                  PaperPositionRepository positionRepository,
                                  IndividualOrderAuditRepository auditRepository,
                                  PyUserRepository userRepository,
                                  PaperAccountBalanceInitializer balanceInitializer) {
        this.paperTradingService = paperTradingService;
        this.balanceRepository = balanceRepository;
        this.positionRepository = positionRepository;
        this.auditRepository = auditRepository;
        this.userRepository = userRepository;
        this.balanceInitializer = balanceInitializer;
    }

    @Override
    @Transactional
    public Order executePaperOrder(PyBrokerAccountEntity dematAccount, IndividualOrderRequest request, String transactionType) {
        if (!paperTradingService.isPaperTradingEnabled()) {
            throw new IllegalStateException("Paper trading engine called while paper trading is disabled");
        }

        if (dematAccount == null) {
            throw new IllegalArgumentException("Demat account cannot be null");
        }

        // 1. Validate Account Ownership
        validateAccountOwnership(dematAccount);

        // 2. Validate Order Parameters
        validateOrderParameters(request, transactionType);

        String symbol = request.getTradingSymbol().trim().toUpperCase();
        String exchange = request.getExchange() != null ? request.getExchange().trim().toUpperCase() : "NSE";
        String productType = request.getProductType() != null ? request.getProductType().trim().toUpperCase() : "DELIVERY";
        if ("NRML".equalsIgnoreCase(productType)) {
            productType = "CARRYFORWARD";
        }
        int quantity = request.getQuantity();

        // 3. Resolve Execution Price
        double executedPrice = resolveExecutionPrice(request);

        // 4. Resolve Account & User Identity
        Long pyUserId = (dematAccount.getPyUser() != null) ? dematAccount.getPyUser().getId() : 0L;
        Long dematAccountId = dematAccount.getId();

        // 5. Audit Entity Initialization
        IndividualOrderAuditEntity audit = new IndividualOrderAuditEntity();
        audit.setDematAccountId(dematAccountId);
        audit.setClientId(dematAccount.getClientId());
        audit.setUserName(dematAccount.getUserName());
        audit.setTradingSymbol(symbol);
        audit.setSymbolToken(request.getSymbolToken());
        audit.setExchange(exchange);
        audit.setQuantity(quantity);
        audit.setPrice(executedPrice);
        audit.setOrderType(request.getOrderType());
        audit.setProductType(productType);
        audit.setTransactionType(transactionType);
        audit.setVariety(request.getVariety() != null ? request.getVariety() : "NORMAL");
        audit.setExecutedAt(LocalDateTime.now());
        audit.setBrokerType(dematAccount.getBrokerType());
        audit.setIdempotencyKey(request.getIdempotencyKey());
        audit.setIsSimulated(true);

        // 6. Pessimistic Lock on Virtual Balance
        PaperAccountBalanceEntity balance = getOrCreateBalanceForUpdate(pyUserId, dematAccountId);

        try {
            if ("BUY".equalsIgnoreCase(transactionType)) {
                double totalCost = executedPrice * quantity;
                if (balance.getVirtualCashBalance() < totalCost) {
                    String errorMsg = String.format("Insufficient virtual funds. Available: ₹%.2f, Required: ₹%.2f",
                            balance.getVirtualCashBalance(), totalCost);
                    audit.setStatus("FAILED");
                    audit.setRemarks("[PAPER TRADING] " + errorMsg);
                    auditRepository.save(audit);
                    throw new IllegalStateException(errorMsg);
                }

                // Deduct cash
                balance.setVirtualCashBalance(balance.getVirtualCashBalance() - totalCost);
                balanceRepository.save(balance);

                // Update Position with Lock
                Optional<PaperPositionEntity> existingPos = positionRepository
                        .findByDematAccountIdAndTradingSymbolAndProductTypeForUpdate(dematAccountId, symbol, productType);

                if (existingPos.isPresent()) {
                    PaperPositionEntity pos = existingPos.get();
                    int newQty = pos.getQuantity() + quantity;
                    double currentTotalCost = pos.getAverageBuyPrice() * pos.getQuantity();
                    double newAvgPrice = (currentTotalCost + totalCost) / newQty;

                    pos.setQuantity(newQty);
                    pos.setAverageBuyPrice(newAvgPrice);
                    pos.setLastSimulatedPrice(executedPrice);
                    positionRepository.save(pos);
                } else {
                    PaperPositionEntity newPos = new PaperPositionEntity(
                            pyUserId, dematAccountId, symbol, request.getSymbolToken(),
                            exchange, productType, quantity, executedPrice);
                    positionRepository.save(newPos);
                }

            } else if ("SELL".equalsIgnoreCase(transactionType)) {
                Optional<PaperPositionEntity> existingPos = positionRepository
                        .findByDematAccountIdAndTradingSymbolAndProductTypeForUpdate(dematAccountId, symbol, productType);

                if (existingPos.isEmpty() || existingPos.get().getQuantity() < quantity) {
                    int available = existingPos.map(PaperPositionEntity::getQuantity).orElse(0);
                    String errorMsg = String.format("Insufficient virtual holdings. Available: %d, Attempted: %d",
                            available, quantity);
                    audit.setStatus("FAILED");
                    audit.setRemarks("[PAPER TRADING] " + errorMsg);
                    auditRepository.save(audit);
                    throw new IllegalStateException(errorMsg);
                }

                PaperPositionEntity pos = existingPos.get();
                double saleProceeds = executedPrice * quantity;
                double costBasis = pos.getAverageBuyPrice() * quantity;
                double tradeRealizedPnl = saleProceeds - costBasis;

                // Credit cash and realized P&L
                balance.setVirtualCashBalance(balance.getVirtualCashBalance() + saleProceeds);
                balance.setRealizedPnl(balance.getRealizedPnl() + tradeRealizedPnl);
                balanceRepository.save(balance);

                // Update position
                pos.setQuantity(pos.getQuantity() - quantity);
                pos.setRealizedPnl(pos.getRealizedPnl() + tradeRealizedPnl);
                pos.setLastSimulatedPrice(executedPrice);
                positionRepository.save(pos);
            }

            // 7. Success Finalization
            String simOrderId = paperTradingService.generateSimulatedOrderId(dematAccount.getBrokerType());
            audit.setStatus("SUCCESS");
            audit.setOrderId(simOrderId);
            audit.setUniqueOrderId(simOrderId);
            audit.setRemarks("[PAPER TRADING - SIMULATED ORDER]");
            auditRepository.save(audit);

            Order order = new Order();
            order.orderId = simOrderId;
            order.uniqueOrderId = simOrderId;

            log.info("🛡️ [PAPER TRADING - SIMULATED FILL] {} {} x {} @ ₹{} | orderId={} | balanceAfter=₹{}",
                    transactionType, symbol, quantity, executedPrice, simOrderId, balance.getVirtualCashBalance());

            return order;

        } catch (RuntimeException e) {
            log.warn("Paper trading order rejected: {}", e.getMessage());
            throw e;
        }
    }

    private void validateAccountOwnership(PyBrokerAccountEntity dematAccount) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || "anonymousUser".equalsIgnoreCase(auth.getName())) {
            return; // In unauthenticated or test context, allow
        }

        String principalName = auth.getName();
        Optional<PyUser> authenticatedUserOpt = userRepository.findByPhoneNumber(principalName);
        if (authenticatedUserOpt.isEmpty()) {
            try {
                Long uid = Long.parseLong(principalName);
                authenticatedUserOpt = userRepository.findById(uid);
            } catch (NumberFormatException ignored) {}
        }

        if (authenticatedUserOpt.isPresent()) {
            PyUser user = authenticatedUserOpt.get();
            if (user.getRole() == PyUser.Role.SUPER_ADMIN) {
                return; // Super admins can test any account
            }
            if (dematAccount.getPyUser() != null && !dematAccount.getPyUser().getId().equals(user.getId())) {
                log.error("Security alert: User {} attempted to trade on demat account {} belonging to pyUser {}",
                        user.getId(), dematAccount.getId(), dematAccount.getPyUser().getId());
                throw new SecurityException("Unauthorized: You do not have ownership of demat account " + dematAccount.getId());
            }
        }
    }

    private void validateOrderParameters(IndividualOrderRequest request, String transactionType) {
        if (request == null) {
            throw new IllegalArgumentException("Order request cannot be null");
        }
        if (request.getTradingSymbol() == null || request.getTradingSymbol().trim().isEmpty()) {
            throw new IllegalArgumentException("Trading symbol is required");
        }
        if (!"BUY".equalsIgnoreCase(transactionType) && !"SELL".equalsIgnoreCase(transactionType)) {
            throw new IllegalArgumentException("Invalid transaction type: " + transactionType + ". Must be BUY or SELL.");
        }
        if (request.getQuantity() == null || request.getQuantity() <= 0) {
            throw new IllegalArgumentException("Order quantity must be greater than zero. Provided: " + request.getQuantity());
        }
        if (request.getQuantity() > 1_000_000) {
            throw new IllegalArgumentException("Order quantity exceeds maximum allowed limit (1,000,000). Provided: " + request.getQuantity());
        }
        if (request.getOrderType() == null || request.getOrderType().trim().isEmpty()) {
            throw new IllegalArgumentException("Order type is required (MARKET or LIMIT)");
        }
        String orderType = request.getOrderType().trim().toUpperCase();
        if (!"MARKET".equals(orderType) && !"LIMIT".equals(orderType)) {
            throw new IllegalArgumentException("Unsupported order type: " + orderType + ". Must be MARKET or LIMIT.");
        }
        if (request.getPrice() != null && (Double.isNaN(request.getPrice()) || Double.isInfinite(request.getPrice()) || request.getPrice() < 0.0)) {
            throw new IllegalArgumentException("Order price must be a finite positive number. Provided: " + request.getPrice());
        }
        if (request.getTriggerPrice() != null && (Double.isNaN(request.getTriggerPrice()) || Double.isInfinite(request.getTriggerPrice()) || request.getTriggerPrice() < 0.0)) {
            throw new IllegalArgumentException("Trigger price must be a finite positive number. Provided: " + request.getTriggerPrice());
        }
    }

    private double resolveExecutionPrice(IndividualOrderRequest request) {
        String orderType = request.getOrderType().trim().toUpperCase();

        if ("LIMIT".equals(orderType)) {
            Double price = request.getPrice();
            if (price == null || Double.isNaN(price) || Double.isInfinite(price) || price <= 0.0) {
                throw new IllegalArgumentException("Limit order requires a valid positive price. Provided: " + price);
            }
            return price;
        }

        if ("MARKET".equals(orderType)) {
            // Check if explicitly configured simulation price is provided
            Double price = request.getPrice();
            if (price != null && !Double.isNaN(price) && !Double.isInfinite(price) && price > 0.0) {
                return price;
            }
            // If price is 0 or null, check if reliable quote is available
            throw new IllegalStateException("Market order simulation failed: Live market quote unavailable for '"
                    + request.getTradingSymbol() + "'. Please specify a limit price or valid simulation price.");
        }

        throw new IllegalArgumentException("Cannot resolve execution price for order type: " + orderType);
    }

    @Override
    @Transactional
    public PaperAccountBalanceEntity getOrCreateBalance(Long pyUserId, Long dematAccountId) {
        return balanceRepository.findByPyUserIdAndDematAccountId(pyUserId, dematAccountId)
                .orElseGet(() -> balanceInitializer.initializeIfAbsent(pyUserId, dematAccountId, 1000000.0));
    }

    private PaperAccountBalanceEntity getOrCreateBalanceForUpdate(Long pyUserId, Long dematAccountId) {
        Optional<PaperAccountBalanceEntity> balanceOpt = balanceRepository.findByPyUserIdAndDematAccountIdForUpdate(pyUserId, dematAccountId);
        if (balanceOpt.isPresent()) {
            return balanceOpt.get();
        }
        // Initialize balance in an isolated transaction (REQUIRES_NEW) to prevent poisoning the current transaction on PostgreSQL
        balanceInitializer.initializeIfAbsent(pyUserId, dematAccountId, 1000000.0);
        return balanceRepository.findByPyUserIdAndDematAccountIdForUpdate(pyUserId, dematAccountId)
                .orElseThrow(() -> new IllegalStateException("Could not initialize paper balance"));
    }

    @Override
    @Transactional(readOnly = true)
    public List<PaperPositionEntity> getPositions(Long dematAccountId) {
        return positionRepository.findByDematAccountId(dematAccountId);
    }
}
