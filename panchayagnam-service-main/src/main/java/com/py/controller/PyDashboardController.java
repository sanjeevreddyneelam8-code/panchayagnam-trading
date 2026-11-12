package com.py.controller;

import com.py.common.dto.ApiResponse;
import com.py.dto.PyDashboardStatsDto;
import com.py.service.PyDashboardService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/dashboard")
@Tag(name = "Dashboard", description = "Dashboard statistics for Super Admin")
public class PyDashboardController {

    private static final Logger log = LogManager.getLogger(PyDashboardController.class);

    @Autowired
    private PyDashboardService pyDashboardService;

    @Operation(
            summary = "Get Dashboard Stats",
            description = "Fetch stats based on role. "
            + "SUPER_ADMIN → all stats. "
            + "ADMIN → his broker accounts + his requests. "
            + "USER → his broker accounts + his requests.")
    @GetMapping("/stats/{pyId}")
    public ResponseEntity<ApiResponse<PyDashboardStatsDto>> getDashboardStats(
            @PathVariable Long pyId) {
        log.info("GET /dashboard/stats | pyId={}", pyId);
        try {
            ApiResponse<PyDashboardStatsDto> response = pyDashboardService
                    .getDashboardStats(pyId);
            log.info("Dashboard stats fetched | pyId={}", pyId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Dashboard stats failed | pyId={}: {}", pyId, e.getMessage(), e);
        return ResponseEntity
            .status(HttpStatus.BAD_REQUEST)
            .body(ApiResponse.error(400, "Failed to fetch dashboard stats"));
        }
    }
}
