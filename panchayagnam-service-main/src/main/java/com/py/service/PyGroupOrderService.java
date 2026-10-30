package com.py.service;

import com.py.brokers.angel.dto.AngelOnePlaceOrderRequest;
import com.py.brokers.motilal.MotilalAccountService;
import com.py.brokers.motilal.dto.MotilalPlaceOrderRequest;
import com.py.brokers.motilal.dto.MotilolOrderParams;
import com.py.common.dto.ApiResponse;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.demataccount.repository.PyTradeGroupMemberRepository;
import com.py.demataccount.repository.PyTradeGroupRepository;
import com.py.dto.*;
import com.py.easytrade.entity.IndividualOrderAuditEntity;
import com.py.easytrade.repository.IndividualOrderAuditRepository;
import com.py.entity.PyTradeGroupEntity;
import com.py.entity.PyTradeGroupMemberEntity;
import com.py.tokensValidation.PyTokenValidationService;
import com.py.tradegroup.entity.PyGroupPositionEntity;
import com.py.tradegroup.repository.PyGroupPositionRepository;
import com.py.utils.AngelOneMicroserviceClient;
import com.py.utils.MotilalMicroserviceClient;
import com.py.utils.ProfitmartMicroserviceClient;          // ✅ NEW
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.stream.Collectors;
import org.json.JSONObject;

@Service
public class PyGroupOrderService {

    private static final Logger log = LoggerFactory.getLogger(PyGroupOrderService.class);

    @Autowired
    private PyTradeGroupRepository pyTradeGroupRepository;
    @Autowired
    private PyTradeGroupMemberRepository pyTradeGroupMemberRepository;
    @Autowired
    private PyBrokerAccountRepository pyBrokerAccountRepository;
    @Autowired
    private IndividualOrderAuditRepository individualOrderAuditRepository;
    @Autowired
    private ExecutorService rmsExecutor;
    @Autowired
    private PyGroupPositionRepository pyGroupPositionRepository;
    @Autowired
    private PyGroupTradeLogService pyGroupTradeLogService;

    @Autowired
    private AngelOneMicroserviceClient angelOneClient;

    @Autowired
    private MotilalMicroserviceClient motilalMicroserviceClient;

    @Autowired
    private ProfitmartMicroserviceClient profitmartMicroserviceClient;   // ✅ NEW

    @Autowired
    private com.py.trading.service.PaperTradingService paperTradingService;

    // ═══════════════════════════════════════════════════════════════════════════
    // PLACE GROUP BUY ORDER
    // ═══════════════════════════════════════════════════════════════════════════
    public ApiResponse<PyGroupOrderResponseDto> placeGroupOrder(PyGroupOrderRequestDto request) {
        try {
            // 1. Validate transaction type
            if (!request.getTransactionType().equalsIgnoreCase("BUY")
                    && !request.getTransactionType().equalsIgnoreCase("SELL")) {
                return ApiResponse.error(400, "transactionType must be BUY or SELL");
            }

            // 2. Fetch group
            PyTradeGroupEntity group = pyTradeGroupRepository
                    .findByIdAndIsActive(request.getGroupId(), true)
                    .orElseThrow(() -> new RuntimeException(
                    "Group not found or inactive: " + request.getGroupId()));

            // 3. Get active members of this group
            List<PyTradeGroupMemberEntity> activeMembers
                    = pyTradeGroupMemberRepository.findByTradeGroupAndIsLinked(group, true);

            List<Long> activeMemberBrokerIds = activeMembers.stream()
                    .map(m -> m.getBrokerAccount().getId())
                    .collect(Collectors.toList());

            // 4. Fire one CompletableFuture per (stock × broker) combination
            List<CompletableFuture<PyGroupOrderResultDto>> futures = new ArrayList<>();

            for (PyStockOrderDto stock : request.getStocks()) {
                for (PyBrokerQuantityDto brokerQty : stock.getBrokerQuantities()) {

                    CompletableFuture<PyGroupOrderResultDto> future
                            = CompletableFuture.supplyAsync(() -> {

                                PyGroupOrderResultDto result = new PyGroupOrderResultDto();
                                result.setTradingSymbol(stock.getTradingSymbol());
                                result.setSymbolToken(stock.getSymbolToken());
                                result.setExchange(stock.getExchange());
                                result.setBrokerId(brokerQty.getBrokerId());
                                result.setQuantity(brokerQty.getQuantity());
                                result.setPrice(stock.getPrice() != null ? stock.getPrice() : 0.0);
                                String brokerType = "";
                                try {
                                    // 5. Fetch broker account
                                    PyBrokerAccountEntity account = pyBrokerAccountRepository
                                            .findById(brokerQty.getBrokerId())
                                            .orElseThrow(() -> new RuntimeException(
                                            "Broker account not found: " + brokerQty.getBrokerId()));
                                    brokerType = account.getBrokerType().name();
                                    result.setClientId(account.getClientId());
                                    result.setUserName(account.getUserName());
                                    result.setBrokerType(account.getBrokerType());

                                    // 6. Check account is active
                                    if (!account.getActive()) {
                                        result.setStatus("SKIPPED");
                                        result.setRemarks("Broker account is inactive");
                                        return result;
                                    }

                                    // 7. Check broker is a member of this group
                                    if (!activeMemberBrokerIds.contains(brokerQty.getBrokerId())) {
                                        result.setStatus("SKIPPED");
                                        result.setRemarks("Broker account is not in this group");
                                        return result;
                                    }

                                    // 8. Validate quantity
                                    if (brokerQty.getQuantity() == null || brokerQty.getQuantity() <= 0) {
                                        result.setStatus("SKIPPED");
                                        result.setRemarks("Invalid quantity: " + brokerQty.getQuantity());
                                        return result;
                                    }

                                    // ── PAPER TRADING GUARD ──────────────────────────
                                    if (paperTradingService.isPaperTradingEnabled()) {
                                        log.warn("🛡️ [PAPER TRADING - SIMULATED ORDER] Intercepted group order for clientId={} symbol={} side={} broker={}",
                                                account.getClientId(), stock.getTradingSymbol(), request.getTransactionType(), account.getBrokerType());
                                        String simOrderId = paperTradingService.generateSimulatedOrderId(account.getBrokerType());
                                        result.setStatus("SUCCESS");
                                        result.setOrderId(simOrderId);
                                        result.setRemarks("[PAPER TRADING - SIMULATED ORDER]");
                                        saveAudit(account, request, stock,
                                                brokerQty.getQuantity(), "SUCCESS", simOrderId, "[PAPER TRADING - SIMULATED ORDER]");
                                        return result;
                                    }

                                    // Enforce live trading authorization gate
                                    paperTradingService.validateLiveOrderAllowed();

                                    // 9. Place order based on broker type
                                    String orderId = switch (account.getBrokerType()) {
                                        case ANGELONE ->
                                            placeAngelOneOrder(
                                            account,
                                            account.getToken().getAccessToken(),
                                            request, stock,
                                            brokerQty.getQuantity());
                                        case MOTILAL ->
                                            placeMotilalOrder(
                                            account, request, stock,
                                            brokerQty.getQuantity());
                                        case PROFITMART ->                      // ✅ NEW
                                            placeProfitmartOrder(
                                            account, request, stock,
                                            brokerQty.getQuantity());
                                        default ->
                                            throw new RuntimeException(
                                                    "Unsupported broker: " + account.getBrokerType());
                                    };

                                    result.setStatus("SUCCESS");
                                    result.setOrderId(orderId);

                                    saveAudit(account, request, stock,
                                            brokerQty.getQuantity(), "SUCCESS", orderId, null);

                                    log.info("✅ {} SUCCESS — symbol={} clientId={} broker={} qty={} orderId={}",
                                            request.getTransactionType(), stock.getTradingSymbol(), account.getClientId(),
                                            account.getBrokerType(), brokerQty.getQuantity(), orderId);

                                } catch (Exception e) {
                                    result.setStatus("FAILED");
                                    String errMsg = (e.getMessage() != null && !e.getMessage().isBlank())
                                            ? e.getMessage()
                                            : "Order execution failed";
                                    result.setRemarks(errMsg);
                                    try {
                                        PyBrokerAccountEntity account = pyBrokerAccountRepository
                                                .findById(brokerQty.getBrokerId()).orElse(null);
                                        if (account != null) {
                                            saveAudit(account, request, stock,
                                                    brokerQty.getQuantity(), "FAILED", null, errMsg);
                                        }
                                    } catch (Exception ex) {
                                        log.warn("Could not save failed audit: {}", ex.getMessage());
                                    }

                                    log.error("❌ {} FAILED — symbol={} brokerId={} error={}",
                                            request.getTransactionType(), stock.getTradingSymbol(), brokerQty.getBrokerId(), e.getMessage());
                                }

                                return result;

                            }, rmsExecutor);

                    futures.add(future);
                }
            }

            // 10. Wait for ALL (stocks × brokers) to finish
            CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();

            List<PyGroupOrderResultDto> results = futures.stream()
                    .map(CompletableFuture::join)
                    .collect(Collectors.toList());

            // 11. Save positions for BUY — SUCCESS and FAILED both
            if (request.getTransactionType().equalsIgnoreCase("BUY")) {
                for (PyGroupOrderResultDto result : results) {
                    if ("SUCCESS".equals(result.getStatus())
                            || "FAILED".equals(result.getStatus())) {
                        savePosition(request, result);
                    }
                }
            }

            // 12. Close positions for SELL
            if (request.getTransactionType().equalsIgnoreCase("SELL")) {
                for (PyGroupOrderResultDto result : results) {
                    if ("SUCCESS".equals(result.getStatus())) {
                        closePosition(request, result);
                    }
                }
            }

            // 13. ✅ Save BUY Trade Log for every result (SUCCESS + FAILED)
            if (request.getTransactionType().equalsIgnoreCase("BUY")) {
                for (PyGroupOrderResultDto result : results) {
                    if ("SUCCESS".equals(result.getStatus()) || "FAILED".equals(result.getStatus())) {
                        saveBuyTradeLog(group.getId(), group.getGroupName(), request, result);
                    }
                }
            }

            // 14. Build response
            PyGroupOrderResponseDto response = new PyGroupOrderResponseDto();
            response.setGroupId(group.getId());
            response.setGroupName(group.getGroupName());
            response.setTransactionType(request.getTransactionType().toUpperCase());
            response.setStockCount(request.getStocks().size());
            response.setTotalOrders(results.size());
            response.setSuccessCount(results.stream().filter(r -> "SUCCESS".equals(r.getStatus())).count());
            response.setFailedCount(results.stream().filter(r -> "FAILED".equals(r.getStatus())).count());
            response.setSkippedCount(results.stream().filter(r -> "SKIPPED".equals(r.getStatus())).count());
            response.setResults(results);

            log.info("Group order complete — groupId={} stocks={} total={} success={} failed={} skipped={}",
                    group.getId(), request.getStocks().size(), results.size(),
                    response.getSuccessCount(), response.getFailedCount(), response.getSkippedCount());

            return ApiResponse.success("Group order placed successfully", response);

        } catch (Exception e) {
            log.error("Group order failed: {}", e.getMessage(), e);
            return ApiResponse.error(500, "Group order failed: " + e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PLACE GROUP SELL — reads open positions automatically, no stocks needed
    // ═══════════════════════════════════════════════════════════════════════════
    public ApiResponse<PyGroupOrderResponseDto> placeGroupSell(
            Long groupId, String orderType, String productType, String variety) {
        try {
            // 1. Fetch group
            PyTradeGroupEntity group = pyTradeGroupRepository
                    .findByIdAndIsActive(groupId, true)
                    .orElseThrow(() -> new RuntimeException(
                    "Group not found or inactive: " + groupId));

            // 2. Fetch all OPEN positions for this group
            List<PyGroupPositionEntity> openPositions = pyGroupPositionRepository
                    .findByGroupIdAndStatus(groupId, PyGroupPositionEntity.Status.OPEN);

            if (openPositions.isEmpty()) {
                return ApiResponse.error(400,
                        "No open positions found for groupId=" + groupId);
            }

            return executeGroupSellPositions(group, openPositions, orderType, productType, variety);
        } catch (Exception e) {
            log.error("Group sell failed: {}", e.getMessage(), e);
            return ApiResponse.error(500, "Group sell failed: " + e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PLACE SELECTIVE GROUP SELL — exits only the specified broker accounts
    // ═══════════════════════════════════════════════════════════════════════════
    public ApiResponse<PyGroupOrderResponseDto> placeSelectiveGroupSell(
            Long groupId, List<Long> brokerAccountIds, String orderType, String productType, String variety) {
        try {
            PyTradeGroupEntity group = pyTradeGroupRepository
                    .findByIdAndIsActive(groupId, true)
                    .orElseThrow(() -> new RuntimeException(
                    "Group not found or inactive: " + groupId));

            List<PyGroupPositionEntity> allOpenPositions = pyGroupPositionRepository
                    .findByGroupIdAndStatus(groupId, PyGroupPositionEntity.Status.OPEN);

            if (allOpenPositions.isEmpty()) {
                return ApiResponse.error(400, "No open positions found for groupId=" + groupId);
            }

            List<PyGroupPositionEntity> selectivePositions;
            if (brokerAccountIds != null && !brokerAccountIds.isEmpty()) {
                Set<Long> allowedIds = new HashSet<>(brokerAccountIds);
                selectivePositions = allOpenPositions.stream()
                        .filter(pos -> allowedIds.contains(pos.getBrokerAccountId()))
                        .collect(Collectors.toList());
            } else {
                selectivePositions = allOpenPositions;
            }

            if (selectivePositions.isEmpty()) {
                return ApiResponse.error(400, "No matching open positions found for the selected brokers in groupId=" + groupId);
            }

            return executeGroupSellPositions(group, selectivePositions, orderType, productType, variety);
        } catch (Exception e) {
            log.error("Selective group sell failed: {}", e.getMessage(), e);
            return ApiResponse.error(500, "Selective group sell failed: " + e.getMessage());
        }
    }

    private ApiResponse<PyGroupOrderResponseDto> executeGroupSellPositions(
            PyTradeGroupEntity group, List<PyGroupPositionEntity> openPositions,
            String orderType, String productType, String variety) {
        try {
            Long groupId = group.getId();
            log.info("Found {} open positions to SELL for groupId={}",
                    openPositions.size(), groupId);

            // 3. Fire SELL order for each open position in PARALLEL
            List<CompletableFuture<PyGroupOrderResultDto>> futures = new ArrayList<>();

            for (PyGroupPositionEntity position : openPositions) {

                CompletableFuture<PyGroupOrderResultDto> future
                        = CompletableFuture.supplyAsync(() -> {

                            PyGroupOrderResultDto result = new PyGroupOrderResultDto();
                            result.setTradingSymbol(position.getTradingSymbol());
                            result.setSymbolToken(position.getSymbolToken());
                            result.setExchange(position.getExchange());
                            result.setBrokerId(position.getBrokerAccountId());
                            result.setQuantity(position.getBuyQuantity()); // ✅ exact qty from BUY

                            try {
                                // 4. Fetch broker account
                                PyBrokerAccountEntity account = pyBrokerAccountRepository
                                        .findById(position.getBrokerAccountId())
                                        .orElseThrow(() -> new RuntimeException(
                                        "Broker not found: " + position.getBrokerAccountId()));

                                result.setClientId(account.getClientId());
                                result.setUserName(account.getUserName());
                                result.setBrokerType(account.getBrokerType());

                                if (!account.getActive()) {
                                    result.setStatus("SKIPPED");
                                    result.setRemarks("Broker account inactive");
                                    return result;
                                }

                                // 5. Build SELL request objects
                                PyGroupOrderRequestDto sellRequest = new PyGroupOrderRequestDto();
                                sellRequest.setGroupId(groupId);
                                sellRequest.setTransactionType("SELL");
                                sellRequest.setOrderType(orderType);
                                sellRequest.setProductType(productType);
                                sellRequest.setVariety(variety != null ? variety : "NORMAL");

                                PyStockOrderDto stock = new PyStockOrderDto();
                                stock.setTradingSymbol(position.getTradingSymbol());
                                stock.setSymbolToken(position.getSymbolToken());
                                stock.setExchange(position.getExchange());
                                stock.setPrice(0.0);

                                // ── PAPER TRADING GUARD ──────────────────────────
                                if (paperTradingService.isPaperTradingEnabled()) {
                                    log.warn("🛡️ [PAPER TRADING - SIMULATED ORDER] Intercepted group SELL for clientId={} symbol={} broker={}",
                                            account.getClientId(), position.getTradingSymbol(), account.getBrokerType());
                                    String simOrderId = paperTradingService.generateSimulatedOrderId(account.getBrokerType());
                                    result.setStatus("SUCCESS");
                                    result.setOrderId(simOrderId);
                                    result.setRemarks("[PAPER TRADING - SIMULATED ORDER]");

                                    position.setSellQuantity(position.getBuyQuantity());
                                    position.setSellPrice(position.getBuyPrice() != null ? position.getBuyPrice() : 0.0);
                                    position.setSellOrderId(simOrderId);
                                    position.setSoldAt(LocalDateTime.now());
                                    position.setStatus(PyGroupPositionEntity.Status.CLOSED);
                                    position.setRemarks("[PAPER TRADING - SIMULATED ORDER]");
                                    pyGroupPositionRepository.save(position);

                                    saveAudit(account, sellRequest, stock,
                                            position.getBuyQuantity(), "SUCCESS", simOrderId, "[PAPER TRADING - SIMULATED ORDER]");
                                    return result;
                                }

                                // Enforce live trading authorization gate
                                paperTradingService.validateLiveOrderAllowed();

                                // 6. Place SELL order based on broker type
                                String orderId = switch (account.getBrokerType()) {
                                    case ANGELONE ->
                                        placeAngelOneOrder(
                                        account,
                                        account.getToken().getAccessToken(),
                                        sellRequest, stock,
                                        position.getBuyQuantity());
                                    case MOTILAL ->
                                        placeMotilalOrder(
                                        account, sellRequest, stock,
                                        position.getBuyQuantity());
                                    case PROFITMART ->                          // ✅ NEW
                                        placeProfitmartOrder(
                                        account, sellRequest, stock,
                                        position.getBuyQuantity());
                                    default ->
                                        throw new RuntimeException(
                                                "Unsupported broker: " + account.getBrokerType());
                                };

                                result.setStatus("SUCCESS");
                                result.setOrderId(orderId);

                                // 7. ✅ Close the position
                                position.setSellQuantity(position.getBuyQuantity());
                                position.setSellPrice(0.0);
                                position.setSellOrderId(orderId);
                                position.setSoldAt(LocalDateTime.now());
                                position.setStatus(PyGroupPositionEntity.Status.CLOSED);
                                position.setRemarks(null);
                                pyGroupPositionRepository.save(position);

                                // 8. Save audit
                                saveAudit(account, sellRequest, stock,
                                        position.getBuyQuantity(), "SUCCESS", orderId, null);

                                log.info("✅ SELL SUCCESS — symbol={} clientId={} broker={} qty={} orderId={}",
                                        position.getTradingSymbol(), account.getClientId(),
                                        account.getBrokerType(), position.getBuyQuantity(), orderId);

                            } catch (Exception e) {
                                result.setStatus("FAILED");
                                result.setRemarks(e.getMessage());

                                log.error("❌ SELL FAILED — symbol={} brokerId={} error={}",
                                        position.getTradingSymbol(),
                                        position.getBrokerAccountId(), e.getMessage());
                            }

                            return result;

                        }, rmsExecutor);

                futures.add(future);
            }

            // 9. Wait for all SELL orders
            CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();

            List<PyGroupOrderResultDto> results = futures.stream()
                    .map(CompletableFuture::join)
                    .collect(Collectors.toList());

            // ✅ Save SELL Trade Log — updates the existing BUY row for each broker
            for (PyGroupOrderResultDto result : results) {
                if ("SUCCESS".equals(result.getStatus()) || "FAILED".equals(result.getStatus())) {
                    saveSellTradeLog(group.getId(), result);
                }
            }

            // 10. Build response
            PyGroupOrderResponseDto response = new PyGroupOrderResponseDto();
            response.setGroupId(group.getId());
            response.setGroupName(group.getGroupName());
            response.setTransactionType("SELL");
            response.setTotalOrders(results.size());
            response.setSuccessCount(results.stream()
                    .filter(r -> "SUCCESS".equals(r.getStatus())).count());
            response.setFailedCount(results.stream()
                    .filter(r -> "FAILED".equals(r.getStatus())).count());
            response.setSkippedCount(results.stream()
                    .filter(r -> "SKIPPED".equals(r.getStatus())).count());
            response.setResults(results);

            log.info("Group SELL complete — groupId={} total={} success={} failed={} skipped={}",
                    groupId, results.size(),
                    response.getSuccessCount(),
                    response.getFailedCount(),
                    response.getSkippedCount());

            return ApiResponse.success("Group sell completed", response);

        } catch (Exception e) {
            log.error("Group sell execution failed: {}", e.getMessage(), e);
            return ApiResponse.error(500, "Group sell execution failed: " + e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RETRY FAILED BUY ORDERS
    // ═══════════════════════════════════════════════════════════════════════════
    public ApiResponse<PyGroupOrderResponseDto> retryFailedBuyOrders(Long groupId) {
        try {
            // 1. Fetch all FAILED positions for this group
            List<PyGroupPositionEntity> failedPositions = pyGroupPositionRepository
                    .findByGroupIdAndStatus(groupId, PyGroupPositionEntity.Status.FAILED);

            if (failedPositions.isEmpty()) {
                return ApiResponse.error(400,
                        "No failed positions found for groupId=" + groupId);
            }

            log.info("Retrying {} failed BUY orders for groupId={}",
                    failedPositions.size(), groupId);

            // 2. Fire retry orders in parallel
            List<CompletableFuture<PyGroupOrderResultDto>> futures = new ArrayList<>();

            for (PyGroupPositionEntity position : failedPositions) {

                CompletableFuture<PyGroupOrderResultDto> future
                        = CompletableFuture.supplyAsync(() -> {

                            PyGroupOrderResultDto result = new PyGroupOrderResultDto();
                            result.setTradingSymbol(position.getTradingSymbol());
                            result.setSymbolToken(position.getSymbolToken());
                            result.setExchange(position.getExchange());
                            result.setBrokerId(position.getBrokerAccountId());
                            result.setQuantity(position.getBuyQuantity());

                            try {
                                PyBrokerAccountEntity account = pyBrokerAccountRepository
                                        .findById(position.getBrokerAccountId())
                                        .orElseThrow(() -> new RuntimeException(
                                        "Broker not found: " + position.getBrokerAccountId()));

                                result.setClientId(account.getClientId());
                                result.setUserName(account.getUserName());
                                result.setBrokerType(account.getBrokerType());

                                if (!account.getActive()) {
                                    result.setStatus("SKIPPED");
                                    result.setRemarks("Broker account inactive");
                                    return result;
                                }

                                // Build BUY request
                                PyGroupOrderRequestDto buyRequest = new PyGroupOrderRequestDto();
                                buyRequest.setGroupId(groupId);
                                buyRequest.setTransactionType("BUY");
                                buyRequest.setOrderType(position.getOrderType());
                                buyRequest.setProductType(position.getProductType());
                                buyRequest.setVariety("NORMAL");

                                PyStockOrderDto stock = new PyStockOrderDto();
                                stock.setTradingSymbol(position.getTradingSymbol());
                                stock.setSymbolToken(position.getSymbolToken());
                                stock.setExchange(position.getExchange());
                                stock.setPrice(position.getBuyPrice());

                                // ── PAPER TRADING GUARD ──────────────────────────
                                if (paperTradingService.isPaperTradingEnabled()) {
                                    log.warn("🛡️ [PAPER TRADING - SIMULATED ORDER] Intercepted retry group order for clientId={} symbol={} broker={}",
                                            account.getClientId(), position.getTradingSymbol(), account.getBrokerType());
                                    String simOrderId = paperTradingService.generateSimulatedOrderId(account.getBrokerType());
                                    result.setStatus("SUCCESS");
                                    result.setOrderId(simOrderId);
                                    result.setRemarks("[PAPER TRADING - SIMULATED ORDER]");
                                    position.setStatus(PyGroupPositionEntity.Status.OPEN);
                                    position.setBuyOrderId(simOrderId);
                                    pyGroupPositionRepository.save(position);
                                    return result;
                                }

                                // Enforce live trading authorization gate
                                paperTradingService.validateLiveOrderAllowed();

                                // Retry order
                                String orderId = switch (account.getBrokerType()) {
                                    case ANGELONE ->
                                        placeAngelOneOrder(
                                        account,
                                        account.getToken().getAccessToken(),
                                        buyRequest, stock,
                                        position.getBuyQuantity());
                                    case MOTILAL ->
                                        placeMotilalOrder(
                                        account, buyRequest, stock,
                                        position.getBuyQuantity());
                                    case PROFITMART ->                          // ✅ NEW
                                        placeProfitmartOrder(
                                        account, buyRequest, stock,
                                        position.getBuyQuantity());
                                    default ->
                                        throw new RuntimeException(
                                                "Unsupported broker: " + account.getBrokerType());
                                };

                                // ✅ Update FAILED → OPEN on success
                                position.setStatus(PyGroupPositionEntity.Status.OPEN);
                                position.setBuyOrderId(orderId);
                                position.setRemarks(null);
                                position.setBoughtAt(LocalDateTime.now());
                                pyGroupPositionRepository.save(position);

                                result.setStatus("SUCCESS");
                                result.setOrderId(orderId);

                                log.info("✅ RETRY SUCCESS — symbol={} brokerId={} broker={} orderId={}",
                                        position.getTradingSymbol(),
                                        position.getBrokerAccountId(),
                                        account.getBrokerType(), orderId);

                            } catch (Exception e) {
                                // ✅ Still failed — update remarks
                                position.setRemarks("Retry failed: " + e.getMessage());
                                pyGroupPositionRepository.save(position);

                                result.setStatus("FAILED");
                                result.setRemarks(e.getMessage());

                                log.error("❌ RETRY FAILED — symbol={} brokerId={} error={}",
                                        position.getTradingSymbol(),
                                        position.getBrokerAccountId(), e.getMessage());
                            }

                            return result;

                        }, rmsExecutor);

                futures.add(future);
            }

            // Wait for all retries
            CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();

            List<PyGroupOrderResultDto> results = futures.stream()
                    .map(CompletableFuture::join)
                    .collect(Collectors.toList());

            PyGroupOrderResponseDto response = new PyGroupOrderResponseDto();
            response.setGroupId(groupId);
            response.setTransactionType("BUY_RETRY");
            response.setTotalOrders(results.size());
            response.setSuccessCount(results.stream()
                    .filter(r -> "SUCCESS".equals(r.getStatus())).count());
            response.setFailedCount(results.stream()
                    .filter(r -> "FAILED".equals(r.getStatus())).count());
            response.setResults(results);

            return ApiResponse.success("Retry completed", response);

        } catch (Exception e) {
            log.error("Retry failed: {}", e.getMessage(), e);
            return ApiResponse.error(500, "Retry failed: " + e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GET GROUP SUMMARY — groupId → stocks → brokers → status
    // ═══════════════════════════════════════════════════════════════════════════
    public ApiResponse<Map<String, Object>> getGroupSummary(Long groupId) {
        try {
            List<PyGroupPositionEntity> allPositions = pyGroupPositionRepository
                    .findByGroupId(groupId);

            if (allPositions.isEmpty()) {
                return ApiResponse.error(404,
                        "No positions found for groupId=" + groupId);
            }

            // Group by tradingSymbol
            Map<String, List<PyGroupPositionEntity>> bySymbol = allPositions.stream()
                    .collect(Collectors.groupingBy(PyGroupPositionEntity::getTradingSymbol));

            List<Map<String, Object>> stockSummary = new ArrayList<>();

            for (Map.Entry<String, List<PyGroupPositionEntity>> entry : bySymbol.entrySet()) {
                String symbol = entry.getKey();
                List<PyGroupPositionEntity> symbolPositions = entry.getValue();

                // Per symbol — broker wise breakdown
                List<Map<String, Object>> brokerDetails = new ArrayList<>();
                for (PyGroupPositionEntity pos : symbolPositions) {
                    Map<String, Object> brokerDetail = new LinkedHashMap<>();
                    brokerDetail.put("positionId",   pos.getId());
                    brokerDetail.put("brokerId",     pos.getBrokerAccountId());
                    brokerDetail.put("clientId",     pos.getClientId());
                    brokerDetail.put("userName",     pos.getUserName());
                    brokerDetail.put("brokerType",   pos.getBrokerType());
                    brokerDetail.put("buyQuantity",  pos.getBuyQuantity());
                    brokerDetail.put("buyPrice",     pos.getBuyPrice());
                    brokerDetail.put("buyOrderId",   pos.getBuyOrderId());
                    brokerDetail.put("sellQuantity", pos.getSellQuantity());
                    brokerDetail.put("sellPrice",    pos.getSellPrice());
                    brokerDetail.put("sellOrderId",  pos.getSellOrderId());
                    brokerDetail.put("status",       pos.getStatus());
                    brokerDetail.put("remarks",      pos.getRemarks());
                    brokerDetail.put("boughtAt",     pos.getBoughtAt());
                    brokerDetail.put("soldAt",       pos.getSoldAt());
                    brokerDetails.add(brokerDetail);
                }

                // Symbol level counts
                long openCount    = symbolPositions.stream().filter(p -> PyGroupPositionEntity.Status.OPEN.equals(p.getStatus())).count();
                long closedCount  = symbolPositions.stream().filter(p -> PyGroupPositionEntity.Status.CLOSED.equals(p.getStatus())).count();
                long failedCount  = symbolPositions.stream().filter(p -> PyGroupPositionEntity.Status.FAILED.equals(p.getStatus())).count();
                long partialCount = symbolPositions.stream().filter(p -> PyGroupPositionEntity.Status.PARTIAL.equals(p.getStatus())).count();

                Map<String, Object> symbolMap = new LinkedHashMap<>();
                symbolMap.put("tradingSymbol", symbol);
                symbolMap.put("totalBrokers",  symbolPositions.size());
                symbolMap.put("openCount",     openCount);
                symbolMap.put("closedCount",   closedCount);
                symbolMap.put("failedCount",   failedCount);
                symbolMap.put("partialCount",  partialCount);
                symbolMap.put("brokers",       brokerDetails);

                stockSummary.add(symbolMap);
            }

            // Overall group level counts
            long totalOpen    = allPositions.stream().filter(p -> PyGroupPositionEntity.Status.OPEN.equals(p.getStatus())).count();
            long totalClosed  = allPositions.stream().filter(p -> PyGroupPositionEntity.Status.CLOSED.equals(p.getStatus())).count();
            long totalFailed  = allPositions.stream().filter(p -> PyGroupPositionEntity.Status.FAILED.equals(p.getStatus())).count();
            long totalPartial = allPositions.stream().filter(p -> PyGroupPositionEntity.Status.PARTIAL.equals(p.getStatus())).count();

            Map<String, Object> summary = new LinkedHashMap<>();
            summary.put("groupId",      groupId);
            summary.put("totalStocks",  bySymbol.size());
            summary.put("totalOrders",  allPositions.size());
            summary.put("totalOpen",    totalOpen);
            summary.put("totalClosed",  totalClosed);
            summary.put("totalFailed",  totalFailed);
            summary.put("totalPartial", totalPartial);
            summary.put("stocks",       stockSummary);

            return ApiResponse.success("Group summary fetched", summary);

        } catch (Exception e) {
            log.error("Failed to fetch group summary: {}", e.getMessage(), e);
            return ApiResponse.error(500, "Failed to fetch group summary: " + e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GET OPEN POSITIONS
    // ═══════════════════════════════════════════════════════════════════════════
    public ApiResponse<List<PyGroupPositionEntity>> getOpenPositions(Long groupId) {
        try {
            List<PyGroupPositionEntity> positions = pyGroupPositionRepository
                    .findByGroupIdAndStatus(groupId, PyGroupPositionEntity.Status.OPEN);
            return ApiResponse.success("Open positions fetched", positions);
        } catch (Exception e) {
            return ApiResponse.error(500, "Failed to fetch positions: " + e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ANGEL ONE ORDER
    // ═══════════════════════════════════════════════════════════════════════════
    private String placeAngelOneOrder(PyBrokerAccountEntity account,
            String accessToken,
            PyGroupOrderRequestDto request,
            PyStockOrderDto stock,
            Integer quantity) throws Exception {

        String baseUrl = "http://" + account.getBrokerRegisteredIp();

        AngelOnePlaceOrderRequest orderRequest = new AngelOnePlaceOrderRequest();
        orderRequest.setApiKey(account.getSecret().getApiKey());
        orderRequest.setAccessToken(accessToken);
        orderRequest.setExchange(stock.getExchange());
        orderRequest.setTradingsymbol(stock.getTradingSymbol());
        orderRequest.setSymboltoken(stock.getSymbolToken());
        orderRequest.setTransactiontype(request.getTransactionType().toUpperCase());
        orderRequest.setOrdertype(request.getOrderType());
        orderRequest.setProducttype(request.getProductType());
        orderRequest.setQuantity(quantity);
        orderRequest.setPrice(stock.getPrice() != null ? stock.getPrice() : 0.0);
        orderRequest.setDuration("DAY");
        orderRequest.setSquareoff("0");
        orderRequest.setStoploss("0");
        orderRequest.setTriggerprice(0.0);
        orderRequest.setVariety(request.getVariety() != null ? request.getVariety() : "NORMAL");

        log.info("AngelOne group order | baseUrl={} symbol={} qty={} side={}",
                baseUrl, stock.getTradingSymbol(), quantity,
                request.getTransactionType());

        JSONObject response = angelOneClient.placeOrder(baseUrl, orderRequest).get();

        String orderId = response.optString("orderId");
        if (orderId == null || orderId.isEmpty()) {
            throw new RuntimeException("Null orderId from AngelOne microservice");
        }

        log.info("AngelOne group order SUCCESS | symbol={} orderId={}",
                stock.getTradingSymbol(), orderId);
        return orderId;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MOTILAL ORDER
    // ═══════════════════════════════════════════════════════════════════════════
    private String placeMotilalOrder(PyBrokerAccountEntity account,
            PyGroupOrderRequestDto request,
            PyStockOrderDto stock,
            Integer quantity) throws Exception {

        String baseUrl    = "http://" + account.getBrokerRegisteredIp();
        String authToken  = account.getToken().getRefreshToken();
        String accessToken = account.getToken().getAccessToken();

        MotilalPlaceOrderRequest orderRequest = buildMotilalPlaceOrderRequest(
                request, stock, quantity, account, authToken, accessToken);

        // ── MARKET → LIMIT via microservice LTP ──────────────────────────────
        if ("MARKET".equals(orderRequest.getOrderType())) {
            log.info("Fetching LTP for Motilal MARKET order | symbol={} exchange={}",
                    stock.getTradingSymbol(), stock.getExchange());

            JSONObject ltpResult = motilalMicroserviceClient.getLtp(
                    baseUrl,
                    account.getSecret().getApiKey(),
                    account.getSecret().getApiSecret(),
                    account.getSecret().getVenderInfo(),
                    authToken,
                    accessToken,
                    stock.getExchange(),
                    Long.parseLong(stock.getSymbolToken()));

            double ltp = ltpResult != null ? ltpResult.optDouble("ltp", 0) / 100.0 : 0;

            if (ltp <= 0) {
                throw new RuntimeException(
                        "Could not fetch live LTP for: " + stock.getTradingSymbol());
            }

            orderRequest.setOrderType("LIMIT");
            orderRequest.setPrice(ltp);
            log.info("Motilal MARKET→LIMIT | symbol={} ltp=₹{}",
                    stock.getTradingSymbol(), ltp);
        }

        log.info("Motilal group order | baseUrl={} symbol={} qty={} side={}",
                baseUrl, stock.getTradingSymbol(), quantity,
                request.getTransactionType());

        JSONObject response = motilalMicroserviceClient.placeOrder(baseUrl, orderRequest).get();

        if (response == null) {
            throw new RuntimeException("Null response from Motilal microservice");
        }

        String orderId = response.optString("uniqueorderid",
                response.optString("orderid", "UNKNOWN"));

        log.info("Motilal group order SUCCESS | symbol={} orderId={}",
                stock.getTradingSymbol(), orderId);
        return orderId;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PROFITMART ORDER
    // ═══════════════════════════════════════════════════════════════════════════
    // API ref: POST /NorenWClientAPI/PlaceOrder
    //
    // trantype : "B" = BUY, "S" = SELL
    // prctyp   : LMT / MKT / SL-LMT / SL-MKT
    // prd      : C=Delivery, M=CarryForward, H=CoverOrder, I=Intraday,
    //            B=BracketOrder, F=MTF, S=Special, P=Special2
    // ret      : DAY / EOS / IOC
    // orderId  : returned in "norenordno" field; check stat=="Ok"
    // ─────────────────────────────────────────────────────────────────────────
    private String placeProfitmartOrder(PyBrokerAccountEntity account,
            PyGroupOrderRequestDto request,
            PyStockOrderDto stock,
            Integer quantity) throws Exception {

        String baseUrl    = "http://" + account.getBrokerRegisteredIp();
        String userId     = account.getClientId();          // uid + actid
        String susertoken = account.getToken().getAccessToken(); // session token

        // ── trantype: API requires "B" or "S" ────────────────────────────────
        String tranType = request.getTransactionType().equalsIgnoreCase("BUY") ? "B" : "S";

        // ── prctyp mapping per API spec ───────────────────────────────────────
        String priceType = switch (request.getOrderType()) {
            case "LIMIT"        -> "LMT";
            case "STOPLOSS"     -> "SL-LMT";
            case "STOPLOSS_MKT" -> "SL-MKT";
            default             -> "MKT";
        };

        // ── prd mapping per API spec ──────────────────────────────────────────
        String productType = switch (request.getProductType()) {
            case "DELIVERY"     -> "C";   // CNC / Delivery
            case "INTRADAY"     -> "I";   // MIS / Intraday
            case "CARRYFORWARD" -> "M";   // CF  / Carry Forward
            case "MARGIN"       -> "M";   // Normal margin → M
            case "COVER"        -> "H";   // Cover Order
            case "BRACKET"      -> "B";   // Bracket Order
            default             -> "I";
        };

        double price        = stock.getPrice() != null ? stock.getPrice() : 0.0;
        double triggerPrice = 0.0;    // set non-zero only for SL orders if needed
        int    discloseQty  = 0;
        String retention    = "DAY";
        String remarks      = "";
        String amo          = null;   // null = don't send amo field (only "Yes" is valid)

        log.info("Profitmart group order | baseUrl={} symbol={} qty={} "
                + "tranType={} priceType={} prd={}",
                baseUrl, stock.getTradingSymbol(), quantity,
                tranType, priceType, productType);

        JSONObject response = profitmartMicroserviceClient.placeOrder(
                baseUrl, userId, susertoken,
                stock.getExchange(),
                stock.getTradingSymbol(),    // tsym — NOT symbolToken
                tranType,                   // ✅ "B" or "S"
                quantity,
                discloseQty,
                priceType,
                price,
                triggerPrice,
                productType,
                retention,
                remarks,
                amo                         // ✅ null → field omitted in request body
        ).get();

        if (response == null) {
            throw new RuntimeException("Null response from Profitmart microservice");
        }

        // ── Profitmart returns stat="Ok" and orderId in "norenordno" ─────────
        String stat    = response.optString("stat", "");
        String orderId = response.optString("norenordno", "");

        if (!"Ok".equalsIgnoreCase(stat) || orderId.isEmpty()) {
            String errMsg = response.optString("emsg", response.toString());
            throw new RuntimeException("Profitmart order rejected: " + errMsg);
        }

        log.info("Profitmart group order SUCCESS | symbol={} tranType={} orderId={}",
                stock.getTradingSymbol(), tranType, orderId);
        return orderId;
    }

    private MotilalPlaceOrderRequest buildMotilalPlaceOrderRequest(
            PyGroupOrderRequestDto request,
            PyStockOrderDto stock,
            Integer quantity,
            PyBrokerAccountEntity account,
            String authToken,
            String accessToken) {

        MotilalPlaceOrderRequest p = new MotilalPlaceOrderRequest();
        p.setApiKey(account.getSecret().getApiKey());
        p.setApiSecret(account.getSecret().getApiSecret());
        p.setVendorInfo(account.getSecret().getVenderInfo());
        p.setAuthToken(authToken);
        p.setAccessToken(accessToken);
        p.setVendorInfo(account.getClientId());
        p.setExchange(stock.getExchange());
        p.setSymbolToken(Integer.parseInt(stock.getSymbolToken()));
        p.setBuyOrSell(request.getTransactionType().toUpperCase());

        String orderType = switch (request.getOrderType()) {
            case "STOPLOSS" -> "STOPLOSS";
            case "LIMIT"    -> "LIMIT";
            default         -> "MARKET";
        };
        p.setOrderType(orderType);

        String productType = switch (request.getProductType()) {
            case "DELIVERY"     -> "DELIVERY";
            case "CARRYFORWARD" -> "NORMAL";
            case "INTRADAY"     -> "NORMAL";
            case "MARGIN"       -> "NORMAL";
            default             -> "NORMAL";
        };
        p.setProductType(productType);

        p.setOrderDuration("DAY");
        p.setPrice(stock.getPrice() != null ? stock.getPrice() : 0.0);
        p.setTriggerPrice(0.0);
        p.setQuantityInLot(quantity);
        p.setDisclosedQuantity(0);
        p.setAmoOrder("N");
        p.setGoodTillDate("");
        p.setAlgoId("");
        p.setParticipantCode("");
        return p;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MOTILAL PARAMS BUILDER
    // ═══════════════════════════════════════════════════════════════════════════
    private MotilolOrderParams buildMotilalOrderParams(PyGroupOrderRequestDto request,
            PyStockOrderDto stock,
            Integer quantity) {
        MotilolOrderParams p = new MotilolOrderParams();
        p.setExchange(stock.getExchange());
        p.setSymbolToken(Integer.valueOf(stock.getSymbolToken()));
        p.setBuyOrSell(request.getTransactionType());

        String orderType = switch (request.getOrderType()) {
            case "STOPLOSS" -> "STOPLOSS";
            case "LIMIT"    -> "LIMIT";
            default         -> "MARKET";
        };
        p.setOrderType(orderType);

        String productType = switch (request.getProductType()) {
            case "DELIVERY"     -> "DELIVERY";
            case "CARRYFORWARD" -> "NORMAL";
            case "INTRADAY"     -> "NORMAL";
            case "MARGIN"       -> "NORMAL";
            default             -> "NORMAL";
        };
        p.setProductType(productType);

        p.setOrderDuration("DAY");
        p.setPrice(stock.getPrice() != null ? stock.getPrice() : 0.0);
        p.setTriggerPrice(0.0);
        p.setQuantityInLot(quantity);
        p.setDisclosedQuantity(0);
        p.setAmoOrder("N");
        p.setGoodTillDate("");
        p.setAlgoId("");
        p.setTag("PANCHAYAGAM");
        p.setParticipantCode("");
        return p;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SAVE AUDIT
    // ═══════════════════════════════════════════════════════════════════════════
    private void saveAudit(PyBrokerAccountEntity account,
            PyGroupOrderRequestDto request,
            PyStockOrderDto stock,
            Integer quantity, String status,
            String orderId, String remarks) {
        try {
            IndividualOrderAuditEntity audit = new IndividualOrderAuditEntity();
            audit.setDematAccountId(account.getId());
            audit.setClientId(account.getClientId());
            audit.setUserName(account.getUserName());
            audit.setTradingSymbol(stock.getTradingSymbol());
            audit.setSymbolToken(stock.getSymbolToken());
            audit.setExchange(stock.getExchange());
            audit.setQuantity(quantity);
            audit.setOrderType(request.getOrderType());
            audit.setProductType(request.getProductType());
            audit.setPrice(stock.getPrice() != null ? stock.getPrice() : 0.0);
            audit.setTransactionType(request.getTransactionType().toUpperCase());
            audit.setVariety(request.getVariety() != null ? request.getVariety() : "NORMAL");
            audit.setBrokerType(account.getBrokerType());
            audit.setStatus(status);
            audit.setOrderId(orderId);
            audit.setRemarks(remarks);
            audit.setExecutedAt(LocalDateTime.now());
            individualOrderAuditRepository.save(audit);
        } catch (Exception e) {
            log.warn("Audit save failed for clientId={}: {}",
                    account.getClientId(), e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SAVE BUY TRADE LOG — creates a new row on BUY
    // ═══════════════════════════════════════════════════════════════════════════
    private void saveBuyTradeLog(Long groupId, String groupName,
            PyGroupOrderRequestDto request,
            PyGroupOrderResultDto result) {
        pyGroupTradeLogService.saveBuyLog(
                groupId, groupName,
                result.getTradingSymbol(), result.getSymbolToken(), result.getExchange(),
                result.getBrokerId(), result.getClientId(), result.getUserName(),
                result.getBrokerType() != null ? result.getBrokerType().name() : null,
                request.getProductType(),
                result.getQuantity(), result.getPrice(),
                result.getOrderId(), result.getStatus(), result.getRemarks());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SAVE SELL TRADE LOG — finds existing BUY row and updates it with SELL data
    // ═══════════════════════════════════════════════════════════════════════════
    private void saveSellTradeLog(Long groupId, PyGroupOrderResultDto result) {
        pyGroupTradeLogService.saveSellLog(
                groupId,
                result.getTradingSymbol(),
                result.getBrokerId(),
                result.getQuantity(), result.getPrice(),
                result.getOrderId(), result.getStatus(), result.getRemarks());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SAVE POSITION AFTER BUY — saves SUCCESS and FAILED both
    // ═══════════════════════════════════════════════════════════════════════════
    private void savePosition(PyGroupOrderRequestDto request,
            PyGroupOrderResultDto result) {
        try {
            PyGroupPositionEntity position = new PyGroupPositionEntity();
            position.setGroupId(request.getGroupId());
            position.setBrokerAccountId(result.getBrokerId());
            position.setClientId(result.getClientId());
            position.setUserName(result.getUserName());
            position.setBrokerType(result.getBrokerType());
            position.setTradingSymbol(result.getTradingSymbol());
            position.setSymbolToken(result.getSymbolToken());
            position.setExchange(result.getExchange());
            position.setOrderType(request.getOrderType());
            position.setProductType(request.getProductType());
            position.setBuyQuantity(result.getQuantity());
            position.setBuyPrice(result.getPrice());
            position.setBuyOrderId(result.getOrderId());   // null for FAILED
            position.setRemarks(result.getRemarks());      // null for SUCCESS, error for FAILED
            position.setBoughtAt(LocalDateTime.now());

            // ✅ Status based on result
            if ("SUCCESS".equals(result.getStatus())) {
                position.setStatus(PyGroupPositionEntity.Status.OPEN);
            } else {
                position.setStatus(PyGroupPositionEntity.Status.FAILED);
            }

            pyGroupPositionRepository.save(position);

            log.info("Position saved — groupId={} brokerId={} symbol={} status={}",
                    request.getGroupId(), result.getBrokerId(),
                    result.getTradingSymbol(), position.getStatus());

        } catch (Exception e) {
            log.error("Failed to save position for brokerId={}: {}",
                    result.getBrokerId(), e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CLOSE POSITION AFTER SELL — FIFO (oldest open first)
    // ═══════════════════════════════════════════════════════════════════════════
    private void closePosition(PyGroupOrderRequestDto request,
            PyGroupOrderResultDto result) {
        try {
            // ✅ FIFO — close oldest open position first
            Optional<PyGroupPositionEntity> positionOpt = pyGroupPositionRepository
                    .findTopByGroupIdAndBrokerAccountIdAndTradingSymbolAndStatusOrderByBoughtAtAsc(
                            request.getGroupId(),
                            result.getBrokerId(),
                            result.getTradingSymbol(),
                            PyGroupPositionEntity.Status.OPEN);

            if (positionOpt.isEmpty()) {
                log.warn("No open position found to close — groupId={} brokerId={} symbol={}",
                        request.getGroupId(), result.getBrokerId(),
                        result.getTradingSymbol());
                return;
            }

            PyGroupPositionEntity position = positionOpt.get();
            position.setSellQuantity(result.getQuantity());
            position.setSellPrice(result.getPrice());
            position.setSellOrderId(result.getOrderId());
            position.setSoldAt(LocalDateTime.now());
            position.setRemarks(null);

            if (result.getQuantity() >= position.getBuyQuantity()) {
                position.setStatus(PyGroupPositionEntity.Status.CLOSED);
            } else {
                position.setStatus(PyGroupPositionEntity.Status.PARTIAL);
            }

            pyGroupPositionRepository.save(position);

            log.info("✅ Position closed — buyOrderId={} sellOrderId={} symbol={} status={}",
                    position.getBuyOrderId(), result.getOrderId(),
                    result.getTradingSymbol(), position.getStatus());

        } catch (Exception e) {
            log.error("Failed to close position for brokerId={}: {}",
                    result.getBrokerId(), e.getMessage());
        }
    }
}