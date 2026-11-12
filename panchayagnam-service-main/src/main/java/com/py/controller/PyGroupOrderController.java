package com.py.controller;

import com.py.common.dto.ApiResponse;
import com.py.dto.PyGroupOrderRequestDto;
import com.py.dto.PyGroupOrderResponseDto;
import com.py.dto.PySelectiveGroupExitRequestDto;
import com.py.service.PyGroupOrderService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/group-order")
@Tag(name = "Group Order", description = "Place group buy/sell orders parallely")
public class PyGroupOrderController {

    private static final Logger log = LogManager.getLogger(PyGroupOrderController.class);

    @Autowired
    private PyGroupOrderService pyGroupOrderService;

    // ── PLACE GROUP BUY ORDER ─────────────────────────────────────────────────
    @Operation(
            summary = "Place Group BUY Order",
            description = "Place BUY orders for multiple stocks and multiple broker accounts "
            + "in a group parallely. Each broker can have different quantity.")
    @PostMapping("/place")
    public ResponseEntity<ApiResponse<PyGroupOrderResponseDto>> placeGroupOrder(
            @Valid @RequestBody PyGroupOrderRequestDto request) {
        log.info("POST /group-order/place | groupId={}, txnType={}, stockCount={}",
                request.getGroupId(), request.getTransactionType(),
                request.getStocks() != null ? request.getStocks().size() : 0);
        try {
            ApiResponse<PyGroupOrderResponseDto> response = pyGroupOrderService
                    .placeGroupOrder(request);
            log.info("Group order placed | groupId={}, status={}", request.getGroupId(), response.getStatusCode());
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Group order failed | groupId={}: {}", request.getGroupId(), e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Group order failed"));
        }
    }

    // ── PLACE GROUP SELL ORDER ────────────────────────────────────────────────
    @Operation(
            summary = "Place Group SELL Order",
            description = "Automatically fetches all OPEN positions for the group "
            + "and places SELL orders for each broker with exact bought quantity. "
            + "No need to pass stocks — system reads from position table.")
    @PostMapping({"/sell", "/group-exit/{groupId}", "/exit/{groupId}"})
    public ResponseEntity<ApiResponse<PyGroupOrderResponseDto>> placeGroupSell(
            @PathVariable(value = "groupId", required = false) Long pathGroupId,
            @RequestParam(value = "groupId", required = false) Long queryGroupId,
            @RequestParam String orderType,
            @RequestParam String productType,
            @RequestParam(required = false, defaultValue = "NORMAL") String variety,
            @RequestParam(required = false, defaultValue = "0") Integer triggerPrice) {

        Long effectiveGroupId = (pathGroupId != null) ? pathGroupId : queryGroupId;
        if (effectiveGroupId == null) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "groupId is required either as path variable or query parameter"));
        }

        log.info("POST /group-order/sell (or /group-exit) | groupId={}, orderType={}, productType={}",
                effectiveGroupId, orderType, productType);
        try {
            ApiResponse<PyGroupOrderResponseDto> response = pyGroupOrderService
                    .placeGroupSell(effectiveGroupId, orderType, productType, variety);
            log.info("Group sell completed | groupId={}", effectiveGroupId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Group sell failed | groupId={}: {}", effectiveGroupId, e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Group sell failed: " + e.getMessage()));
        }
    }

    // ── SELECTIVE GROUP EXIT ──────────────────────────────────────────────────
    @Operation(
            summary = "Selective Group Exit",
            description = "Exits open positions only for the specified broker accounts in the group.")
    @PostMapping({"/group-exit/{groupId}/selective", "/exit/{groupId}/selective"})
    public ResponseEntity<ApiResponse<PyGroupOrderResponseDto>> placeSelectiveGroupSell(
            @PathVariable Long groupId,
            @RequestBody PySelectiveGroupExitRequestDto request) {

        log.info("POST /group-order/group-exit/{}/selective | brokers={}",
                groupId, request != null ? request.getBrokerAccountIds() : null);

        if (request == null) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Request body is required"));
        }

        try {
            ApiResponse<PyGroupOrderResponseDto> response = pyGroupOrderService.placeSelectiveGroupSell(
                    groupId,
                    request.getBrokerAccountIds(),
                    request.getOrderType() != null ? request.getOrderType() : "MARKET",
                    request.getProductType() != null ? request.getProductType() : "DELIVERY",
                    request.getVariety() != null ? request.getVariety() : "NORMAL");

            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Selective group exit failed | groupId={}: {}", groupId, e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Selective exit failed: " + e.getMessage()));
        }
    }

    // ── RETRY FAILED BUY ORDERS ───────────────────────────────────────────────
    @Operation(
            summary = "Retry Failed BUY Orders",
            description = "Retries all FAILED BUY positions for a group. "
            + "On success updates status from FAILED to OPEN.")
    @PostMapping("/retry-failed")
    public ResponseEntity<ApiResponse<PyGroupOrderResponseDto>> retryFailedOrders(
            @RequestParam Long groupId) {
        log.info("POST /group-order/retry-failed | groupId={}", groupId);
        try {
            ApiResponse<PyGroupOrderResponseDto> response = pyGroupOrderService
                    .retryFailedBuyOrders(groupId);
            log.info("Retry failed orders completed | groupId={}", groupId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Retry failed orders error | groupId={}: {}", groupId, e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Failed to retry orders"));
        }
    }

    // ── GET GROUP SUMMARY ─────────────────────────────────────────────────────
    @Operation(
            summary = "Get Group Summary",
            description = "Returns all positions for a group grouped by stock symbol. "
            + "Shows each broker's buy/sell status, orderIds, quantity, price and remarks. "
            + "Use this to display what was bought, which broker, what is the current status.")
    @GetMapping("/summary/{groupId}")
    public ResponseEntity<ApiResponse<?>> getGroupSummary(
            @PathVariable Long groupId) {
        log.info("GET /group-order/summary | groupId={}", groupId);
        try {
            ApiResponse<?> response = pyGroupOrderService.getGroupSummary(groupId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Get group summary failed | groupId={}: {}", groupId, e.getMessage());
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Failed to fetch group summary"));
        }
    }

    // ── GET OPEN POSITIONS ────────────────────────────────────────────────────
    @Operation(
            summary = "Get Open Positions",
            description = "Get all OPEN positions for a group — to know what stocks are available to sell.")
    @GetMapping({"/positions/{groupId}", "/group-positions/{groupId}"})
    public ResponseEntity<ApiResponse<?>> getOpenPositions(
            @PathVariable Long groupId) {
        log.info("GET /group-order/positions/{}", groupId);
        try {
            ApiResponse<?> response = pyGroupOrderService.getOpenPositions(groupId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Failed to fetch open positions"));
        }
    }

    // ── GET BATCH POSITIONS ───────────────────────────────────────────────────
    @Operation(
            summary = "Get Batch Positions",
            description = "Get positions for a specific batch or group.")
    @GetMapping({"/positions/batch/{groupId}", "/group-positions/batch/{groupId}"})
    public ResponseEntity<ApiResponse<?>> getBatchPositions(
            @PathVariable Long groupId,
            @RequestParam(required = false) String batchId) {
        log.info("GET /group-order/positions/batch/{} | batchId={}", groupId, batchId);
        try {
            ApiResponse<?> response = pyGroupOrderService.getOpenPositions(groupId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Failed to fetch batch positions"));
        }
    }
}
