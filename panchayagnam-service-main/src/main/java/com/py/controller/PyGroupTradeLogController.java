package com.py.controller;

import com.py.common.dto.ApiResponse;
import com.py.dto.PyGroupTradeLogResponseDto;
import com.py.service.PyGroupTradeLogService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Read-only APIs for Group Trade Log.
 * Logs are saved automatically when group orders are placed/sold.
 *
 * Base URL: /api/v1/group-trade-log
 */
@RestController
@RequestMapping("/api/v1/group-trade-log")
@Tag(name = "Group Trade Log",
     description = "Fetch trade execution history per group — BUY & SELL lifecycle in one record per broker+stock")
public class PyGroupTradeLogController {

    private static final Logger log = LogManager.getLogger(PyGroupTradeLogController.class);

    @Autowired
    private PyGroupTradeLogService tradeLogService;
    

    // ── 1. All logs for a group ───────────────────────────────────────────────
    @Operation(
            summary = "Get All Logs By Group",
            description = "Fetch complete trade history for a group. "
                    + "Each record shows BUY and SELL details of one broker for one stock.")
    @GetMapping("/group/{groupId}")
    public ResponseEntity<ApiResponse<List<PyGroupTradeLogResponseDto>>> getLogsByGroup(
            @Parameter(description = "Group ID", example = "1")
            @PathVariable Long groupId) {
        log.info("GET /group-trade-log/group/{}", groupId);
        try {
            ApiResponse<List<PyGroupTradeLogResponseDto>> response =
                    tradeLogService.getLogsByGroup(groupId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
                } catch (RuntimeException e) {
                        log.error("Get trade logs failed | groupId={}: {}", groupId, e.getMessage(), e);
                            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                    .body(ApiResponse.error(500, "Failed to fetch trade logs"));
                }
    }

    // ── 2. By overall status ──────────────────────────────────────────────────
    @Operation(
            summary = "Get Logs By Group and Status",
            description = "Filter by overall lifecycle status: "
                    + "BUY_SUCCESS / BUY_FAILED / SELL_SUCCESS / SELL_FAILED")
    @GetMapping("/group/{groupId}/status/{status}")
    public ResponseEntity<ApiResponse<List<PyGroupTradeLogResponseDto>>> getLogsByStatus(
            @Parameter(description = "Group ID", example = "1")
            @PathVariable Long groupId,
            @Parameter(description = "BUY_SUCCESS | BUY_FAILED | SELL_SUCCESS | SELL_FAILED",
                       example = "SELL_FAILED")
            @PathVariable String status) {
        try {
            ApiResponse<List<PyGroupTradeLogResponseDto>> response =
                    tradeLogService.getLogsByGroupAndStatus(groupId, status);
            return ResponseEntity.status(response.getStatusCode()).body(response);
                } catch (RuntimeException e) {
                        log.error("Get logs by status failed | groupId={}, status={}: {}", groupId, status, e.getMessage(), e);
                            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                    .body(ApiResponse.error(500, "Failed to fetch trade logs"));
                }
    }

    // ── 3. Brokers where BUY failed ───────────────────────────────────────────
    @Operation(
            summary = "Get BUY Failed Logs By Group",
            description = "Fetch all broker accounts that failed to BUY for this group — includes failure reason")
    @GetMapping("/group/{groupId}/buy-failed")
    public ResponseEntity<ApiResponse<List<PyGroupTradeLogResponseDto>>> getBuyFailed(
            @Parameter(description = "Group ID", example = "1")
            @PathVariable Long groupId) {
        try {
            ApiResponse<List<PyGroupTradeLogResponseDto>> response =
                    tradeLogService.getBuyFailedByGroup(groupId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
                } catch (RuntimeException e) {
                        log.error("Get buy-failed logs failed | groupId={}: {}", groupId, e.getMessage(), e);
                            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                    .body(ApiResponse.error(500, "Failed to fetch buy-failed logs"));
                }
    }

    // ── 4. Brokers where SELL failed ──────────────────────────────────────────
    @Operation(
            summary = "Get SELL Failed Logs By Group",
            description = "Fetch all broker accounts that failed to SELL for this group — includes failure reason")
    @GetMapping("/group/{groupId}/sell-failed")
    public ResponseEntity<ApiResponse<List<PyGroupTradeLogResponseDto>>> getSellFailed(
            @Parameter(description = "Group ID", example = "1")
            @PathVariable Long groupId) {
        try {
            ApiResponse<List<PyGroupTradeLogResponseDto>> response =
                    tradeLogService.getSellFailedByGroup(groupId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
                } catch (RuntimeException e) {
                        log.error("Get sell-failed logs failed | groupId={}: {}", groupId, e.getMessage(), e);
                            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                    .body(ApiResponse.error(500, "Failed to fetch sell-failed logs"));
                }
    }

    // ── 5. By group + broker account ──────────────────────────────────────────
    @Operation(
            summary = "Get Logs By Group and Broker",
            description = "Fetch all trade logs for a specific broker account within a group")
    @GetMapping("/group/{groupId}/broker/{brokerAccountId}")
    public ResponseEntity<ApiResponse<List<PyGroupTradeLogResponseDto>>> getLogsByGroupAndBroker(
            @Parameter(description = "Group ID", example = "1")
            @PathVariable Long groupId,
            @Parameter(description = "Broker Account ID", example = "10")
            @PathVariable Long brokerAccountId) {
        try {
            ApiResponse<List<PyGroupTradeLogResponseDto>> response =
                    tradeLogService.getLogsByGroupAndBroker(groupId, brokerAccountId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
                } catch (RuntimeException e) {
                        log.error("Get logs by group and broker failed | groupId={}, brokerId={}: {}", groupId, brokerAccountId, e.getMessage(), e);
                            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                    .body(ApiResponse.error(500, "Failed to fetch logs for broker"));
                }
    }

    // ── 6. By group + stock symbol ────────────────────────────────────────────
    @Operation(
            summary = "Get Logs By Group and Stock",
            description = "Fetch all broker execution logs for a specific stock within a group")
    @GetMapping("/group/{groupId}/stock/{tradingSymbol}")
    public ResponseEntity<ApiResponse<List<PyGroupTradeLogResponseDto>>> getLogsByGroupAndStock(
            @Parameter(description = "Group ID", example = "1")
            @PathVariable Long groupId,
            @Parameter(description = "Trading Symbol", example = "RELIANCE-EQ")
            @PathVariable String tradingSymbol) {
        try {
            ApiResponse<List<PyGroupTradeLogResponseDto>> response =
                    tradeLogService.getLogsByGroupAndStock(groupId, tradingSymbol);
            return ResponseEntity.status(response.getStatusCode()).body(response);
                } catch (RuntimeException e) {
                        log.error("Get logs by group and stock failed | groupId={}, tradingSymbol={}: {}", groupId, tradingSymbol, e.getMessage(), e);
                            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                    .body(ApiResponse.error(500, "Failed to fetch logs for stock"));
                }
    }

    // ── 7. All logs for a broker account (across all groups) ──────────────────
    @Operation(
            summary = "Get All Logs By Broker Account",
            description = "Fetch all trade logs for a broker account across all groups")
    @GetMapping("/broker/{brokerAccountId}")
    public ResponseEntity<ApiResponse<List<PyGroupTradeLogResponseDto>>> getLogsByBroker(
            @Parameter(description = "Broker Account ID", example = "10")
            @PathVariable Long brokerAccountId) {
        try {
            ApiResponse<List<PyGroupTradeLogResponseDto>> response =
                    tradeLogService.getLogsByBroker(brokerAccountId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
                } catch (RuntimeException e) {
                        log.error("Get logs by broker failed | brokerId={}: {}", brokerAccountId, e.getMessage(), e);
                            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                    .body(ApiResponse.error(500, "Failed to fetch logs for broker"));
                }
    }

    // ── 8. By group + date range ──────────────────────────────────────────────
    @Operation(
            summary = "Get Logs By Group and Date Range",
            description = "Fetch trade logs for a group within a date range. "
                    + "Format: yyyy-MM-dd'T'HH:mm:ss")
    @GetMapping("/group/{groupId}/date-range")
    public ResponseEntity<ApiResponse<List<PyGroupTradeLogResponseDto>>> getLogsByDateRange(
            @Parameter(description = "Group ID", example = "1")
            @PathVariable Long groupId,
            @Parameter(description = "From datetime", example = "2025-01-01T00:00:00")
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @Parameter(description = "To datetime", example = "2025-12-31T23:59:59")
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to) {
        try {
            ApiResponse<List<PyGroupTradeLogResponseDto>> response =
                    tradeLogService.getLogsByGroupAndDateRange(groupId, from, to);
            return ResponseEntity.status(response.getStatusCode()).body(response);
                } catch (RuntimeException e) {
                        log.error("Get logs by date range failed | groupId={}, from={}, to={}: {}", groupId, from, to, e.getMessage(), e);
                            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                    .body(ApiResponse.error(500, "Failed to fetch logs for date range"));
                }
    }

    // ── 9. Status summary for a group ─────────────────────────────────────────
    @Operation(
            summary = "Get Status Summary By Group",
            description = "Get counts of BUY_SUCCESS / BUY_FAILED / SELL_SUCCESS / SELL_FAILED for a group")
    @GetMapping("/group/{groupId}/summary")
    public ResponseEntity<ApiResponse<?>> getStatusSummary(
            @Parameter(description = "Group ID", example = "1")
            @PathVariable Long groupId) {
        try {
            ApiResponse<?> response = tradeLogService.getStatusSummaryByGroup(groupId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
                } catch (RuntimeException e) {
                        log.error("Get status summary failed | groupId={}: {}", groupId, e.getMessage(), e);
                            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                    .body(ApiResponse.error(500, "Failed to fetch status summary"));
                }
    }
}
