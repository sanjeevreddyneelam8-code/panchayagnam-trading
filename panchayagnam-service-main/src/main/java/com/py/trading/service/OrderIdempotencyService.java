package com.py.trading.service;

import com.py.easytrade.dto.IndividualOrderRequest;
import com.py.trading.entity.OrderRequestIdempotencyEntity;
import com.py.trading.exception.IdempotencyConflictException;
import com.py.trading.repository.OrderRequestIdempotencyRepository;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;

@Service
public class OrderIdempotencyService {

    private static final Logger log = LoggerFactory.getLogger(OrderIdempotencyService.class);
    private static final Duration IN_PROGRESS_TIMEOUT = Duration.ofSeconds(60);

    private final OrderRequestIdempotencyRepository idempotencyRepository;

    public OrderIdempotencyService(OrderRequestIdempotencyRepository idempotencyRepository) {
        this.idempotencyRepository = idempotencyRepository;
    }

    public static class IdempotentResult {
        private final int statusCode;
        private final JSONObject payload;
        private final boolean replayed;

        public IdempotentResult(int statusCode, JSONObject payload, boolean replayed) {
            this.statusCode = statusCode;
            this.payload = payload;
            this.replayed = replayed;
        }

        public int getStatusCode() {
            return statusCode;
        }

        public JSONObject getPayload() {
            return payload;
        }

        public boolean isReplayed() {
            return replayed;
        }
    }

    /**
     * Executes order logic with durable database idempotency protection.
     * Prevents duplicate orders across concurrent threads or retries after network timeouts.
     */
    public IdempotentResult execute(Long pyUserId, Long dematAccountId, String rawKey,
                                   IndividualOrderRequest request, String transactionType,
                                   Supplier<JSONObject> executionAction) {

        String idempotencyKey = (rawKey != null && !rawKey.trim().isEmpty())
                ? rawKey.trim()
                : "LEGACY-" + UUID.randomUUID();

        String requestHash = computeRequestHash(request, transactionType);

        // 1. Check if record already exists
        Optional<OrderRequestIdempotencyEntity> existingOpt =
                idempotencyRepository.findByPyUserIdAndDematAccountIdAndIdempotencyKey(pyUserId, dematAccountId, idempotencyKey);

        if (existingOpt.isPresent()) {
            return handleExistingRecord(existingOpt.get(), idempotencyKey, requestHash);
        }

        // 2. Reserve in-progress state
        OrderRequestIdempotencyEntity record;
        try {
            record = createInProgressRecord(pyUserId, dematAccountId, idempotencyKey, requestHash);
        } catch (DataIntegrityViolationException dive) {
            // Concurrent duplicate insertion occurred
            log.info("Concurrent idempotency lock caught for key={}", idempotencyKey);
            OrderRequestIdempotencyEntity duplicate = idempotencyRepository
                    .findByPyUserIdAndDematAccountIdAndIdempotencyKey(pyUserId, dematAccountId, idempotencyKey)
                    .orElseThrow(() -> dive);
            return handleExistingRecord(duplicate, idempotencyKey, requestHash);
        }

        // 3. Execute order action
        try {
            JSONObject responseJson = executionAction.get();
            finalizeRecord(record.getId(), "COMPLETED", 200, responseJson.toString(), responseJson.optString("orderId"), null);
            return new IdempotentResult(200, responseJson, false);

        } catch (Exception e) {
            log.error("Order execution failed under idempotency key={}: {}", idempotencyKey, e.getMessage());
            finalizeRecord(record.getId(), "FAILED", 400, null, null, e.getMessage());
            throw e;
        }
    }

    private IdempotentResult handleExistingRecord(OrderRequestIdempotencyEntity record,
                                                 String idempotencyKey, String requestHash) {

        if ("COMPLETED".equals(record.getStatus())) {
            // Verify request hash matches
            if (!record.getRequestHash().equals(requestHash)) {
                log.warn("Idempotency conflict: key={} reused with different payload", idempotencyKey);
                throw new IdempotencyConflictException(409,
                        "Idempotency key '" + idempotencyKey + "' was already used for a different order request.");
            }

            // Return cached response
            log.info("Returning replayed order response for idempotency key={}", idempotencyKey);
            JSONObject cachedPayload = new JSONObject(record.getResponsePayload());
            return new IdempotentResult(record.getHttpStatusCode() != null ? record.getHttpStatusCode() : 200, cachedPayload, true);
        }

        if ("IN_PROGRESS".equals(record.getStatus())) {
            Duration age = Duration.between(record.getCreatedAt(), LocalDateTime.now());
            if (age.compareTo(IN_PROGRESS_TIMEOUT) < 0) {
                log.warn("Concurrent duplicate request rejected for in-progress key={}", idempotencyKey);
                throw new IdempotencyConflictException(409,
                        "Order with idempotency key '" + idempotencyKey + "' is currently being processed. Please retry shortly.");
            } else {
                log.warn("Stale in-progress idempotency key={} detected (age={}s); marking as FAILED", idempotencyKey, age.getSeconds());
                record.setStatus("FAILED");
                record.setErrorMessage("Timed out in-progress");
                idempotencyRepository.save(record);
                throw new IdempotencyConflictException(409,
                        "Previous attempt for idempotency key '" + idempotencyKey + "' timed out. Please retry with a new key.");
            }
        }

        // Status is FAILED
        log.warn("Previous attempt for idempotency key={} failed: {}", idempotencyKey, record.getErrorMessage());
        throw new IdempotencyConflictException(409,
                "Previous attempt for idempotency key '" + idempotencyKey + "' failed: " + record.getErrorMessage());
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public OrderRequestIdempotencyEntity createInProgressRecord(Long pyUserId, Long dematAccountId,
                                                                String idempotencyKey, String requestHash) {
        OrderRequestIdempotencyEntity entity = new OrderRequestIdempotencyEntity(pyUserId, dematAccountId, idempotencyKey, requestHash);
        return idempotencyRepository.saveAndFlush(entity);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void finalizeRecord(Long recordId, String status, int httpStatus,
                               String responsePayload, String orderId, String errorMessage) {
        idempotencyRepository.findById(recordId).ifPresent(record -> {
            record.setStatus(status);
            record.setHttpStatusCode(httpStatus);
            record.setResponsePayload(responsePayload);
            record.setOrderId(orderId);
            record.setErrorMessage(errorMessage);
            idempotencyRepository.save(record);
        });
    }

    /**
     * Computes SHA-256 hash of normalized order parameters.
     */
    public String computeRequestHash(IndividualOrderRequest request, String transactionType) {
        String symbol = (request.getTradingSymbol() != null) ? request.getTradingSymbol().trim().toUpperCase() : "";
        String exchange = (request.getExchange() != null) ? request.getExchange().trim().toUpperCase() : "NSE";
        String side = (transactionType != null) ? transactionType.trim().toUpperCase() : "";
        int quantity = (request.getQuantity() != null) ? request.getQuantity() : 0;
        String orderType = (request.getOrderType() != null) ? request.getOrderType().trim().toUpperCase() : "";
        double price = (request.getPrice() != null) ? request.getPrice() : 0.0;
        String productType = (request.getProductType() != null) ? request.getProductType().trim().toUpperCase() : "";
        if ("NRML".equals(productType)) {
            productType = "CARRYFORWARD";
        }

        String normalized = String.format("%s:%s:%s:%d:%s:%.4f:%s",
                symbol, exchange, side, quantity, orderType, price, productType);

        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(normalized.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 algorithm not available", e);
        }
    }
}
