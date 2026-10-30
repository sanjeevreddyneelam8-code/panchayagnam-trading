package com.py.controller;

import com.py.brokers.angel.dto.Order;
import com.py.brokers.motilal.entity.MotilalTokenRefreshAuditEntity;
import com.py.brokers.motilal.repository.MotilalTokenRefreshAuditRepository;
import com.py.tokenrefresh.entity.TokenRefreshAuditEntity;
import com.py.common.enums.AccountActionType;
import com.py.common.enums.BrokerType;
import com.py.brokers.angel.exception.SmartAPIException;
import com.py.brokers.angel.dto.CancelOrderRequest;
import com.py.brokers.angel.dto.ModifyOrderRequest;
import com.py.common.dto.ApiResponse;
import com.py.controller.utils.ControllerResponseBuilder;
import com.py.demataccount.dto.DematAccountAddRequest;
import com.py.demataccount.dto.DematAccountFetchResponse;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.tokenrefresh.repository.TokenRefreshAuditRepository;
import com.py.demataccount.service.LiveHoldingsWebSocketManager;
import com.py.demataccount.service.PyBrokerAccountService;
import com.py.dto.ConvertPositionRequest;
import com.py.dto.PyBrokerAccountSummaryDto;
import com.py.easytrade.dto.IndividualOrderRequest;
import com.py.trading.service.OrderIdempotencyService;
import com.py.trading.service.PaperTradingEngine;
import com.py.trading.entity.PaperAccountBalanceEntity;
import com.py.trading.entity.PaperPositionEntity;
import com.py.trading.exception.IdempotencyConflictException;
import com.py.entity.PyUser;
import com.py.repo.PyUserRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import java.util.Optional;
import java.io.IOException;
import java.util.List;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.Map;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

@RestController
@RequestMapping("/pyBrokerApi")
@CrossOrigin(origins = "*")
@Tag(name = "PyBroker", description = "Unified broker operations — AngelOne & Motilal Oswal")
public class PyBrokerController {

    private static final Logger log = LogManager.getLogger(PyBrokerController.class);

    @Autowired
    private PyBrokerAccountService pyBrokerAccountService;

    @Autowired
    private TokenRefreshAuditRepository tokenRefreshAuditRepository;

    @Autowired
    private MotilalTokenRefreshAuditRepository motilalTokenRefreshAuditRepository;

    @Autowired
    private LiveHoldingsWebSocketManager liveHoldingsWebSocketManager;

    @Autowired
    private ControllerResponseBuilder responseBuilder;

    @Autowired
    private OrderIdempotencyService orderIdempotencyService;

    @Autowired
    private PaperTradingEngine paperTradingEngine;

    @Autowired
    private PyUserRepository pyUserRepository;

    @Autowired
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    // =========================================================================
    // ✅ ACCOUNT OPERATIONS — unified for both brokers
    //    brokerType is inside DematAccountAddRequest
    // =========================================================================
    @Operation(summary = "Broker Account Operations",
            description = "Add / Update / Delete a demat account. "
            + "Set brokerType = ANGELONE or MOTILAL in the request body.")
    @PostMapping("/brokerAccOperations")
    public ResponseEntity<?> dematAccountOperations(
            @RequestBody DematAccountAddRequest request,
            @RequestParam AccountActionType actionType) {
        log.info("dematAccountOperations | actionType={}, BrokerType={}, PyUserId={}",
                actionType, request != null ? request.getBrokerType() : null, request != null ? request.getPyUserId() : null);
        try {
            if (request == null || request.getPyUserId() <= 0) {
                return responseBuilder.buildError(400, "User ID is required");
            }
            validatePyUserAccess(request.getPyUserId());
            if ((actionType == AccountActionType.UPDATE || actionType == AccountActionType.DELETE) && request.getClientId() != null) {
                pyBrokerAccountRepository.findByClientId(request.getClientId()).ifPresent(acc -> {
                    if (acc.getPyUser() != null) {
                        validatePyUserAccess(acc.getPyUser().getId());
                    }
                });
            }
            ApiResponse<?> response = pyBrokerAccountService.dematAccountOperations(request, actionType);
            return responseBuilder.buildResponse(response);

        } catch (SecurityException se) {
            log.warn("Security rejection in dematAccountOperations: {}", se.getMessage());
            return responseBuilder.buildError(403, se.getMessage());
        } catch (SmartAPIException | IOException e) {
            log.error("Broker API error: {}", e.getMessage(), e);
            return responseBuilder.buildError(502, "Broker API error");
        } catch (Exception e) {
            log.error("Internal error in broker account operation: {}", e.getMessage(), e);
            return responseBuilder.buildError(500, "Internal server error");
        }
    }

    // =========================================================================
    // ✅ FETCH ACCOUNTS
    // =========================================================================
    @Operation(summary = "Fetch Broker Accounts without Balance",
            description = "Fetches user Broker accounts without balance")
    @PostMapping("/accounts")
    public ResponseEntity<ApiResponse<List<DematAccountFetchResponse>>> fetchAccountsByPyId(
            @Parameter(description = "Fetch All Accounts by PY_ID", example = "1")
            @RequestParam Long pyId) {
        try {
            validatePyUserAccess(pyId);
            ApiResponse<List<DematAccountFetchResponse>> response = pyBrokerAccountService.fetchAccountsByPyId(pyId, false);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (SecurityException se) {
            log.warn("Security rejection in /accounts | pyId={}: {}", pyId, se.getMessage());
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(403, se.getMessage()));
        }
    }

     @Operation(summary = "Fetch Broker Account with Balance",
            description = "Fetches Broker account with balance")
    @PostMapping("/account")
    public ResponseEntity<ApiResponse<List<DematAccountFetchResponse>>> fetchAccountByPyBrokerId(
            @Parameter(description = "Fetch account by Py_Broker_Id", example = "1")
            @RequestParam Long pyBrokerId) {
        try {
            validateAccountOwnership(pyBrokerId);
            ApiResponse<List<DematAccountFetchResponse>> response = pyBrokerAccountService.fetchAccountsByPyBrokerId(pyBrokerId, true);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (SecurityException se) {
            log.warn("Security rejection in /account | pyBrokerId={}: {}", pyBrokerId, se.getMessage());
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(403, se.getMessage()));
        } catch (IllegalArgumentException iae) {
            log.warn("Account not found in /account | pyBrokerId={}: {}", pyBrokerId, iae.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.error(404, iae.getMessage()));
        }
    }
    

    // =========================================================================
    // ✅ TOKEN AUDIT — brokerType param routes to AngelOne or Motilal
    // =========================================================================
    @Operation(summary = "Get Token Refresh Audit Log",
            description = "Retrieve the audit log. "
            + "brokerType = ANGELONE (default) or MOTILAL")
    @GetMapping("/tokens/audit")
    public ResponseEntity<?> getAuditLog(
            @Parameter(description = "Broker type", example = "ANGELONE")
            @RequestParam(required = false, defaultValue = "ANGELONE") BrokerType brokerType) {

        if (brokerType == BrokerType.MOTILAL) {
            List<MotilalTokenRefreshAuditEntity> audits = motilalTokenRefreshAuditRepository
                    .findAll(Sort.by(Sort.Direction.DESC, "attemptedAt"));
            JSONArray auditJson = responseBuilder.buildMotilalAuditJson(audits);
            return ResponseEntity.ok(auditJson.toString());
        }

        List<TokenRefreshAuditEntity> audits = tokenRefreshAuditRepository
                .findAll(Sort.by(Sort.Direction.DESC, "attemptedAt"));
        JSONArray auditJson = responseBuilder.buildAngelOneAuditJson(audits);
        return ResponseEntity.ok(auditJson.toString());
    }

    // =========================================================================
    // ✅ ORDER OPERATIONS — unchanged (AngelOne only for now)
    // =========================================================================
    @Operation(summary = "Place Individual Buy",
            description = "Place a buy order directly via broker API or simulated paper trading with idempotency protection")
    @PostMapping("/order/buy")
    public ResponseEntity<?> placeIndividualBuy(
            @RequestBody IndividualOrderRequest request,
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyHeader) {
        log.info("POST /order/buy | accId={}, symbol={}", request.getAccId(), request.getTradingSymbol());

        String keyToUse = (request.getIdempotencyKey() != null && !request.getIdempotencyKey().isBlank())
                ? request.getIdempotencyKey()
                : idempotencyHeader;
        if (keyToUse != null) {
            request.setIdempotencyKey(keyToUse.trim());
        }

        try {
            if (request == null || request.getAccId() == null) {
                return responseBuilder.buildError(400, "Account ID and order details are required");
            }
            validateAccountOwnership(request.getAccId());
            Long pyUserId = resolveAuthenticatedUserId();
            OrderIdempotencyService.IdempotentResult result = orderIdempotencyService.execute(
                    pyUserId, request.getAccId(), request.getIdempotencyKey(), request, "BUY",
                    () -> {
                        Order order = pyBrokerAccountService.placeIndividualOrder(request, "BUY");
                        return responseBuilder.buildOrderOperationResponse(order.orderId, order.uniqueOrderId);
                    }
            );
            return ResponseEntity.status(result.getStatusCode()).body(result.getPayload().toString());

        } catch (IdempotencyConflictException ice) {
            log.warn("Idempotency conflict | accId={}: {}", request.getAccId(), ice.getMessage());
            return responseBuilder.buildError(ice.getStatusCode(), ice.getMessage());
        } catch (SecurityException se) {
            log.warn("Security rejection | accId={}: {}", request.getAccId(), se.getMessage());
            return responseBuilder.buildError(403, se.getMessage());
        } catch (IllegalArgumentException | IllegalStateException e) {
            log.warn("Order validation/balance rejected | accId={}: {}", request.getAccId(), e.getMessage());
            return responseBuilder.buildError(400, e.getMessage());
        } catch (Exception e) {
            log.error("BUY order failed | accId={}: {}", request.getAccId(), e.getMessage(), e);
            return responseBuilder.buildError(400, e.getMessage() != null ? e.getMessage() : "Buy order failed");
        }
    }

    @Operation(summary = "Place Individual Sell",
            description = "Place a sell order directly via broker API or simulated paper trading with idempotency protection")
    @PostMapping("/order/sell")
    public ResponseEntity<?> placeIndividualSell(
            @RequestBody IndividualOrderRequest request,
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyHeader) {
        log.info("POST /order/sell | accId={}, symbol={}", request.getAccId(), request.getTradingSymbol());

        String keyToUse = (request.getIdempotencyKey() != null && !request.getIdempotencyKey().isBlank())
                ? request.getIdempotencyKey()
                : idempotencyHeader;
        if (keyToUse != null) {
            request.setIdempotencyKey(keyToUse.trim());
        }

        try {
            if (request == null || request.getAccId() == null) {
                return responseBuilder.buildError(400, "Account ID and order details are required");
            }
            validateAccountOwnership(request.getAccId());
            Long pyUserId = resolveAuthenticatedUserId();
            OrderIdempotencyService.IdempotentResult result = orderIdempotencyService.execute(
                    pyUserId, request.getAccId(), request.getIdempotencyKey(), request, "SELL",
                    () -> {
                        Order order = pyBrokerAccountService.placeIndividualOrder(request, "SELL");
                        return responseBuilder.buildOrderOperationResponse(order.orderId, order.uniqueOrderId);
                    }
            );
            return ResponseEntity.status(result.getStatusCode()).body(result.getPayload().toString());

        } catch (IdempotencyConflictException ice) {
            log.warn("Idempotency conflict | accId={}: {}", request.getAccId(), ice.getMessage());
            return responseBuilder.buildError(ice.getStatusCode(), ice.getMessage());
        } catch (SecurityException se) {
            log.warn("Security rejection | accId={}: {}", request.getAccId(), se.getMessage());
            return responseBuilder.buildError(403, se.getMessage());
        } catch (IllegalArgumentException | IllegalStateException e) {
            log.warn("Order validation/holding rejected | accId={}: {}", request.getAccId(), e.getMessage());
            return responseBuilder.buildError(400, e.getMessage());
        } catch (Exception e) {
            log.error("SELL order failed | accId={}: {}", request.getAccId(), e.getMessage(), e);
            return responseBuilder.buildError(400, e.getMessage() != null ? e.getMessage() : "Sell order failed");
        }
    }

    @Operation(summary = "Get Paper Trading Balance", description = "Fetch virtual cash balance for paper trading account")
    @GetMapping("/paper/balance")
    public ResponseEntity<?> getPaperBalance(@RequestParam Long accId) {
        try {
            validateAccountOwnership(accId);
            Long pyUserId = resolveAuthenticatedUserId();
            if (pyUserId == null || pyUserId <= 0) {
                PyBrokerAccountEntity account = pyBrokerAccountRepository.findById(accId).orElse(null);
                if (account != null && account.getPyUser() != null) {
                    pyUserId = account.getPyUser().getId();
                }
            }
            PaperAccountBalanceEntity balance = paperTradingEngine.getOrCreateBalance(pyUserId, accId);
            return ResponseEntity.ok(balance);
        } catch (SecurityException se) {
            log.warn("Security rejection in /paper/balance | accId={}: {}", accId, se.getMessage());
            return responseBuilder.buildError(403, se.getMessage());
        } catch (IllegalArgumentException iae) {
            log.warn("Invalid account in /paper/balance | accId={}: {}", accId, iae.getMessage());
            return responseBuilder.buildError(404, iae.getMessage());
        } catch (Exception e) {
            log.error("Failed to fetch paper balance | accId={}: {}", accId, e.getMessage(), e);
            return responseBuilder.buildError(500, "Failed to fetch paper balance");
        }
    }

    @Operation(summary = "Get Paper Trading Positions", description = "Fetch virtual positions for paper trading account")
    @GetMapping("/paper/positions")
    public ResponseEntity<?> getPaperPositions(@RequestParam Long accId) {
        try {
            validateAccountOwnership(accId);
            List<PaperPositionEntity> positions = paperTradingEngine.getPositions(accId);
            return ResponseEntity.ok(positions);
        } catch (SecurityException se) {
            log.warn("Security rejection in /paper/positions | accId={}: {}", accId, se.getMessage());
            return responseBuilder.buildError(403, se.getMessage());
        } catch (IllegalArgumentException iae) {
            log.warn("Invalid account in /paper/positions | accId={}: {}", accId, iae.getMessage());
            return responseBuilder.buildError(404, iae.getMessage());
        } catch (Exception e) {
            log.error("Failed to fetch paper positions | accId={}: {}", accId, e.getMessage(), e);
            return responseBuilder.buildError(500, "Failed to fetch paper positions");
        }
    }

    private void validateAccountOwnership(Long accId) {
        if (accId == null) {
            throw new IllegalArgumentException("Account ID cannot be null");
        }
        PyBrokerAccountEntity account = pyBrokerAccountRepository.findById(accId)
                .orElseThrow(() -> new IllegalArgumentException("Demat account not found: " + accId));

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || "anonymousUser".equalsIgnoreCase(auth.getName())) {
            return;
        }

        Long authenticatedUserId = resolveAuthenticatedUserId();
        if (authenticatedUserId != null && authenticatedUserId > 0) {
            Optional<PyUser> userOpt = pyUserRepository.findById(authenticatedUserId);
            if (userOpt.isPresent() && userOpt.get().getRole() == PyUser.Role.SUPER_ADMIN) {
                return;
            }
            if (account.getPyUser() != null && !account.getPyUser().getId().equals(authenticatedUserId)) {
                log.warn("Security rejection: authenticated user {} attempted to access demat account {} owned by pyUser {}",
                        authenticatedUserId, accId, account.getPyUser().getId());
                throw new SecurityException("Unauthorized: Account " + accId + " does not belong to authenticated user");
            }
        }
    }

    private void validatePyUserAccess(Long pyUserId) {
        if (pyUserId == null) {
            throw new IllegalArgumentException("User ID cannot be null");
        }
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || "anonymousUser".equalsIgnoreCase(auth.getName())) {
            return;
        }

        Long authenticatedUserId = resolveAuthenticatedUserId();
        if (authenticatedUserId != null && authenticatedUserId > 0) {
            Optional<PyUser> userOpt = pyUserRepository.findById(authenticatedUserId);
            if (userOpt.isPresent() && userOpt.get().getRole() == PyUser.Role.SUPER_ADMIN) {
                return;
            }
            if (!pyUserId.equals(authenticatedUserId)) {
                log.warn("Security rejection: authenticated user {} attempted to access resources for pyUser {}",
                        authenticatedUserId, pyUserId);
                throw new SecurityException("Unauthorized: Cannot access or modify accounts for another user");
            }
        }
    }

    private Long resolveAuthenticatedUserId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equalsIgnoreCase(auth.getName())) {
            String principal = auth.getName();
            Optional<PyUser> userOpt = pyUserRepository.findByPhoneNumber(principal);
            if (userOpt.isPresent()) {
                return userOpt.get().getId();
            }
            try {
                return Long.parseLong(principal);
            } catch (NumberFormatException ignored) {}
        }
        return 0L;
    }

    @Operation(summary = "Get Order History",
            description = "Fetch all orders for the day for a demat account")
    @GetMapping("/order/history")
    public ResponseEntity<?> getOrderHistory(
            @Parameter(description = "Demat account ID", example = "1")
            @RequestParam Long accId) {
        log.info("GET /order/history | accId={}", accId);
        try {
            validateAccountOwnership(accId);
            JSONObject response = pyBrokerAccountService.getOrderHistory(accId);
            return ResponseEntity.ok(response.toString());
        } catch (SecurityException se) {
            log.warn("Security rejection in /order/history | accId={}: {}", accId, se.getMessage());
            return responseBuilder.buildError(403, se.getMessage());
        } catch (IllegalArgumentException iae) {
            log.warn("Invalid account in /order/history | accId={}: {}", accId, iae.getMessage());
            return responseBuilder.buildError(404, iae.getMessage());
        } catch (Exception e) {
            log.error("Fetch order history failed | accId={}: {}", accId, e.getMessage(), e);
            return responseBuilder.buildError(400, "Failed to fetch order history");
        }
    }

    @Operation(summary = "Start Live Holdings Feed",
            description = "Fetches holdings from broker and starts live WS feed")
    @PostMapping("/order/live-holdings/start")
    public ResponseEntity<?> startLiveHoldings(@RequestParam Long accId) {
        log.info("POST /order/live-holdings/start | accId={}", accId);
        try {
            liveHoldingsWebSocketManager.startLiveFeed(accId);
            return ResponseEntity.ok(
                    ApiResponse.success("Live feed started for accId: " + accId));
        } catch (Exception e) {
            log.error("Start live holdings failed | accId={}: {}", accId, e.getMessage(), e);
            return responseBuilder.buildError(400, "Failed to start live holdings feed");
        }
    }

    @Operation(summary = "Stop Live Holdings Feed",
            description = "Stop live WS feed for an account")
    @PostMapping("/order/live-holdings/stop")
    public ResponseEntity<?> stopLiveHoldings(@RequestParam Long accId) {
        log.info("POST /order/live-holdings/stop | accId={}", accId);
        try {
            liveHoldingsWebSocketManager.stopLiveFeed(accId);
            return ResponseEntity.ok(
                    ApiResponse.success("Live feed stopped for accId: " + accId));
        } catch (Exception e) {
            log.error("Stop live holdings failed | accId={}: {}", accId, e.getMessage(), e);
            return responseBuilder.buildError(400, "Failed to stop live holdings feed");
        }
    }

    @Operation(
            summary = "Get Broker Accounts Grouped By Broker Name",
            description = "Fetch broker accounts grouped by broker name. "
            + "SUPER_ADMIN → all accounts. "
            + "ADMIN/USER → only their accounts.")
    @GetMapping("/broker-accounts/grouped/{pyId}")
    public ResponseEntity<ApiResponse<Map<String, List<PyBrokerAccountSummaryDto>>>> getBrokerAccountsGrouped(
            @PathVariable Long pyId) {
        try {
            validatePyUserAccess(pyId);
            ApiResponse<Map<String, List<PyBrokerAccountSummaryDto>>> response
                    = pyBrokerAccountService.getBrokerAccountsGrouped(pyId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (SecurityException se) {
            log.warn("Security rejection in /broker-accounts/grouped/{}: {}", pyId, se.getMessage());
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(403, se.getMessage()));
        } catch (RuntimeException e) {
            log.error("Runtime exception in getBrokerAccountsGrouped: {}", e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Bad request"));
        }
    }

    @Operation(
            summary = "Get Positions",
            description = "Fetch open positions for a broker account. Supports AngelOne, Motilal, Dhan.")
    @GetMapping("/order/positions")
    public ResponseEntity<?> getPositions(
            @Parameter(description = "Broker account ID", example = "1")
            @RequestParam Long accId) {
        log.info("GET /order/positions | accId={}", accId);
        try {
            validateAccountOwnership(accId);
            JSONObject response = pyBrokerAccountService.getPositions(accId);
            return ResponseEntity.ok(response.toString());
        } catch (SecurityException se) {
            log.warn("Security rejection in /order/positions | accId={}: {}", accId, se.getMessage());
            return responseBuilder.buildError(403, se.getMessage());
        } catch (IllegalArgumentException iae) {
            log.warn("Invalid account in /order/positions | accId={}: {}", accId, iae.getMessage());
            return responseBuilder.buildError(404, iae.getMessage());
        } catch (Exception e) {
            log.error("Fetch positions failed | accId={}: {}", accId, e.getMessage(), e);
            return responseBuilder.buildError(400, "Failed to fetch positions: " + e.getMessage());
        }
    }

    @PostMapping("/modifyOrder")
    public ResponseEntity<ApiResponse<Order>> modifyOrder(
            @RequestBody ModifyOrderRequest request) {
        try {
            if (request == null || request.getAccId() == null) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(ApiResponse.error(400, "Account ID and order details are required"));
            }
            validateAccountOwnership(request.getAccId());
            Order order = pyBrokerAccountService.modifyIndividualOrder(request);
            return ResponseEntity.ok(ApiResponse.success("Order modified successfully", order));
        } catch (SecurityException se) {
            log.warn("Security rejection in /modifyOrder: {}", se.getMessage());
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(403, se.getMessage()));
        } catch (IllegalArgumentException | IllegalStateException e) {
            log.warn("Validation failure in /modifyOrder: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, e.getMessage()));
        } catch (Exception e) {
            log.error("Modify order failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error(500, "Modify order failed: " + e.getMessage()));
        }
    }

    @PostMapping("/cancelOrder")
    public ResponseEntity<ApiResponse<Order>> cancelOrder(
            @RequestBody CancelOrderRequest request) {
        try {
            if (request == null || request.getAccId() == null) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(ApiResponse.error(400, "Account ID and order details are required"));
            }
            validateAccountOwnership(request.getAccId());
            Order order = pyBrokerAccountService.cancelIndividualOrder(request);
            return ResponseEntity.ok(ApiResponse.success("Order cancelled successfully", order));
        } catch (SecurityException se) {
            log.warn("Security rejection in /cancelOrder: {}", se.getMessage());
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(403, se.getMessage()));
        } catch (IllegalArgumentException | IllegalStateException e) {
            log.warn("Validation failure in /cancelOrder: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, e.getMessage()));
        } catch (Exception e) {
            log.error("Cancel order failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error(500, "Cancel order failed: " + e.getMessage()));
        }
    }

    @Operation(summary = "Get LTP", description = "Get LTP by broker account ID")
    @GetMapping("/market/ltp")
    public ResponseEntity<?> getLTP(
            @RequestParam Long brokerId,
            @RequestParam String exchange,
            @RequestParam String tradingSymbol,
            @RequestParam String symbolToken) {
        log.info("GET /market/ltp | brokerId={} exchange={} symbol={} token={}",
                brokerId, exchange, tradingSymbol, symbolToken);
        try {
            JSONObject response = pyBrokerAccountService.getLTP(
                    brokerId, exchange, tradingSymbol, symbolToken);
            return response != null
                    ? ResponseEntity.ok(response.toMap())
                    : ResponseEntity.badRequest().body("Failed to get LTP");
        } catch (Exception e) {
            log.error("LTP failed | brokerId={}: {}", brokerId, e.getMessage(), e);
            return ResponseEntity.badRequest().body(ApiResponse.error(400, "Failed to get LTP"));
        }
    }

    @Operation(summary = "Convert Position",
            description = "Convert a position's margin product type e.g. DELIVERY → INTRADAY")
    @PostMapping("/order/convertPosition")
    public ResponseEntity<?> convertPosition(
            @RequestBody ConvertPositionRequest request) {
        if (request == null || request.getAccId() == null) {
            return ResponseEntity.badRequest().body("Account ID is required to convert position");
        }
        log.info("POST /order/convertPosition | accId={} symbol={} {} -> {}",
                request.getAccId(), request.getTradingsymbol(),
                request.getOldproducttype(), request.getNewproducttype());
        try {
            validateAccountOwnership(request.getAccId());
            JSONObject response = pyBrokerAccountService.convertPosition(request.getAccId(), request);
            return ResponseEntity.ok(response.toMap());
        } catch (SecurityException se) {
            log.warn("Security rejection in /order/convertPosition: {}", se.getMessage());
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(403, se.getMessage()));
        } catch (IllegalArgumentException | IllegalStateException | UnsupportedOperationException e) {
            log.warn("Validation failure in /order/convertPosition: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, e.getMessage()));
        } catch (Exception e) {
            log.error("Convert position failed | accId={}: {}", request.getAccId(), e.getMessage(), e);
            return ResponseEntity.badRequest()
                    .body("Convert position failed: " + e.getMessage());
        }
    }
}
