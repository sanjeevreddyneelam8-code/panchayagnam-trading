package com.py.tradeaudit.controller;


import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.py.tradeaudit.service.TradeAuditService;

@RestController
@RequestMapping("/api/audit")
@Tag(name = "Trade Audit", description = "Audit trail for buy/sell orders, positions, and group summaries")
public class TradeAuditController {

    private static final Logger log = LogManager.getLogger(TradeAuditController.class);

    @Autowired
    private TradeAuditService auditService;

    // — BUY AUDITS —

    @Operation(summary = "Get All Buy Audits", description = "Retrieve all buy order audit records")
    @GetMapping("/buy/all")
    public ResponseEntity<?> getAllBuyAudits() {
        log.info("GET /api/audit/buy/all");
        try {
            return ResponseEntity.ok(auditService.getAllBuyAudits().toString());
        } catch (Exception e) {
            log.error("Get all buy audits failed: {}", e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch buy audits");
        }
    }

    @Operation(summary = "Get Buy Audits by Group", description = "Retrieve buy audits for a specific trade group")
    @GetMapping("/buy/group/{groupId}")
    public ResponseEntity<?> getBuyAuditsByGroup(
            @Parameter(description = "Trade group ID", example = "1") @PathVariable Long groupId) {
        try {
            return ResponseEntity.ok(auditService.getBuyAuditsByGroup(groupId).toString());
        } catch (Exception e) {
            log.error("Get buy audits by group failed | groupId={}: {}", groupId, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch buy audits for group");
        }
    }

    @Operation(summary = "Get Buy Audits by Group & Status", description = "Retrieve buy audits filtered by group and status")
    @GetMapping("/buy/group/{groupId}/status/{status}")
    public ResponseEntity<?> getBuyAuditsByGroupAndStatus(
            @Parameter(description = "Trade group ID", example = "1") @PathVariable Long groupId,
            @Parameter(description = "Order status", example = "SUCCESS") @PathVariable String status) {
        try {
            return ResponseEntity.ok(
                auditService.getBuyAuditsByGroupAndStatus(groupId, status).toString());
        } catch (Exception e) {
            log.error("Get buy audits by group and status failed | groupId={}, status={}: {}", groupId, status, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch buy audits by status");
        }
    }

    @Operation(summary = "Get Buy Audits by Client", description = "Retrieve buy audits for a specific client ID")
    @GetMapping("/buy/client/{clientId}")
    public ResponseEntity<?> getBuyAuditsByClient(
            @Parameter(description = "Client ID", example = "D12345") @PathVariable String clientId) {
        try {
            return ResponseEntity.ok(auditService.getBuyAuditsByClient(clientId).toString());
        } catch (Exception e) {
            log.error("Get buy audits by client failed | clientId={}: {}", clientId, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch buy audits for client");
        }
    }

    @Operation(summary = "Get Buy Audits by Demat Account", description = "Retrieve buy audits for a specific demat account")
    @GetMapping("/buy/account/{dematAccountId}")
    public ResponseEntity<?> getBuyAuditsByDematAccount(
            @Parameter(description = "Demat account ID", example = "1") @PathVariable Long dematAccountId) {
        try {
            return ResponseEntity.ok(
                auditService.getBuyAuditsByDematAccount(dematAccountId).toString());
        } catch (Exception e) {
            log.error("Get buy audits by demat account failed | dematAccountId={}: {}", dematAccountId, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch buy audits for demat account");
        }
    }

    // — SELL AUDITS —

    @Operation(summary = "Get All Sell Audits", description = "Retrieve all sell order audit records")
    @GetMapping("/sell/all")
    public ResponseEntity<?> getAllSellAudits() {
        try {
            return ResponseEntity.ok(auditService.getAllSellAudits().toString());
        } catch (Exception e) {
            log.error("Get all sell audits failed: {}", e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch sell audits");
        }
    }

    @Operation(summary = "Get Sell Audits by Group", description = "Retrieve sell audits for a specific trade group")
    @GetMapping("/sell/group/{groupId}")
    public ResponseEntity<?> getSellAuditsByGroup(
            @Parameter(description = "Trade group ID", example = "1") @PathVariable Long groupId) {
        try {
            return ResponseEntity.ok(auditService.getSellAuditsByGroup(groupId).toString());
        } catch (Exception e) {
            log.error("Get sell audits by group failed | groupId={}: {}", groupId, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch sell audits for group");
        }
    }

    @Operation(summary = "Get Sell Audits by Group & Status", description = "Retrieve sell audits filtered by group and status")
    @GetMapping("/sell/group/{groupId}/status/{status}")
    public ResponseEntity<?> getSellAuditsByGroupAndStatus(
            @Parameter(description = "Trade group ID", example = "1") @PathVariable Long groupId,
            @Parameter(description = "Order status", example = "SUCCESS") @PathVariable String status) {
        try {
            return ResponseEntity.ok(
                auditService.getSellAuditsByGroupAndStatus(groupId, status).toString());
        } catch (Exception e) {
            log.error("Get sell audits by group and status failed | groupId={}, status={}: {}", groupId, status, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch sell audits by status");
        }
    }

    @Operation(summary = "Get Sell Audits by Client", description = "Retrieve sell audits for a specific client ID")
    @GetMapping("/sell/client/{clientId}")
    public ResponseEntity<?> getSellAuditsByClient(
            @Parameter(description = "Client ID", example = "D12345") @PathVariable String clientId) {
        try {
            return ResponseEntity.ok(auditService.getSellAuditsByClient(clientId).toString());
        } catch (Exception e) {
            log.error("Get sell audits by client failed | clientId={}: {}", clientId, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch sell audits for client");
        }
    }

    @Operation(summary = "Get Sell Audits by Demat Account", description = "Retrieve sell audits for a specific demat account")
    @GetMapping("/sell/account/{dematAccountId}")
    public ResponseEntity<?> getSellAuditsByDematAccount(
            @Parameter(description = "Demat account ID", example = "1") @PathVariable Long dematAccountId) {
        try {
            return ResponseEntity.ok(
                auditService.getSellAuditsByDematAccount(dematAccountId).toString());
        } catch (Exception e) {
            log.error("Get sell audits by demat account failed | dematAccountId={}: {}", dematAccountId, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch sell audits for demat account");
        }
    }

    // — POSITIONS —

    @Operation(summary = "Get Open Positions", description = "Get all OPEN positions for a trade group")
    @GetMapping("/positions/group/{groupId}/open")
    public ResponseEntity<?> getOpenPositions(
            @Parameter(description = "Trade group ID", example = "1") @PathVariable Long groupId) {
        try {
            return ResponseEntity.ok(auditService.getOpenPositionsByGroup(groupId).toString());
        } catch (Exception e) {
            log.error("Get open positions failed | groupId={}: {}", groupId, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch open positions");
        }
    }

    @Operation(summary = "Get Sold Positions", description = "Get all SOLD positions for a trade group")
    @GetMapping("/positions/group/{groupId}/sold")
    public ResponseEntity<?> getSoldPositions(
            @Parameter(description = "Trade group ID", example = "1") @PathVariable Long groupId) {
        try {
            return ResponseEntity.ok(auditService.getSoldPositionsByGroup(groupId).toString());
        } catch (Exception e) {
            log.error("Get sold positions failed | groupId={}: {}", groupId, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch sold positions");
        }
    }

    @Operation(summary = "Get All Positions by Group", description = "Get all positions (OPEN + SOLD) for a trade group")
    @GetMapping("/positions/group/{groupId}/all")
    public ResponseEntity<?> getAllPositionsByGroup(
            @Parameter(description = "Trade group ID", example = "1") @PathVariable Long groupId) {
        try {
            return ResponseEntity.ok(auditService.getAllPositionsByGroup(groupId).toString());
        } catch (Exception e) {
            log.error("Get all positions by group failed | groupId={}: {}", groupId, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch positions");
        }
    }

    @Operation(summary = "Get Positions by Demat Account", description = "Get all positions for a specific demat account")
    @GetMapping("/positions/account/{dematAccountId}")
    public ResponseEntity<?> getPositionsByDematAccount(
            @Parameter(description = "Demat account ID", example = "1") @PathVariable Long dematAccountId) {
        try {
            return ResponseEntity.ok(
                auditService.getAllPositionsByDematAccount(dematAccountId).toString());
        } catch (Exception e) {
            log.error("Get positions by demat account failed | dematAccountId={}: {}", dematAccountId, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch positions for demat account");
        }
    }

    // — COMBINED SUMMARY —

    @Operation(summary = "Get Group Summary", description = "Get full summary (buy/sell audits, positions) for a trade group")
    @GetMapping("/summary/group/{groupId}")
    public ResponseEntity<?> getGroupSummary(
            @Parameter(description = "Trade group ID", example = "1") @PathVariable Long groupId) {
        try {
            return ResponseEntity.ok(auditService.getGroupSummary(groupId).toString());
        } catch (Exception e) {
            log.error("Get group summary failed | groupId={}: {}", groupId, e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to fetch group summary");
        }
    }
}
