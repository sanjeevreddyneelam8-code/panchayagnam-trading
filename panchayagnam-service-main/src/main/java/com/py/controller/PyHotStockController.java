package com.py.controller;

import com.py.common.dto.ApiResponse;
import com.py.common.enums.HotStockCategory;
import com.py.dto.PyHotStockGroupedResponseDto;
import com.py.dto.PyHotStockRequestDto;
import com.py.dto.PyHotStockResponseDto;
import com.py.service.PyHotStockService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.time.LocalDate;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;

@RestController
@RequestMapping("/api/v1/hot-stocks")
@Tag(name = "Hot Stocks", description = "Hot Stock recommendations — Add, Update, Delete, Fetch")
public class PyHotStockController {

    private static final Logger log = LogManager.getLogger(PyHotStockController.class);

    @Autowired
    private PyHotStockService pyHotStockService;

    // ── ADD / UPDATE / DELETE ────────────────────────────────────────────────
    @Operation(
            summary = "Hot Stock Operations",
            description = "Handle all hot stock operations in single API. "
            + "actionType: ADD, UPDATE, DELETE. "
            + "Only ADMIN and SUPER_ADMIN can ADD, UPDATE, DELETE.")
    @PostMapping("/operations")
    public ResponseEntity<ApiResponse<?>> hotStockOperations(
            @Valid @RequestBody PyHotStockRequestDto requestDto) {
        log.info("POST /hot-stocks/operations | action={}, symbol={}, pyId={}",
                requestDto.getActionType(), requestDto.getSymbol(), requestDto.getPyId());
        try {
            ApiResponse<?> response = pyHotStockService
                    .hotStockOperations(requestDto);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Hot stock operation failed | action={}: {}", requestDto.getActionType(), e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Hot stock operation failed"));
        }
    }

    // ── GET ALL STOCKS GROUPED BY CATEGORY ───────────────────────────────────
    @Operation(
            summary = "Get All Hot Stocks Grouped",
            description = "Fetch all active hot stocks grouped by category "
            + "— INTRADAY, SHORT_TERM, MID_TERM, LONG_TERM with counts. "
            + "Visible to all roles.")
    @GetMapping("/all")
    public ResponseEntity<ApiResponse<PyHotStockGroupedResponseDto>> getAllStocksGrouped() {
        try {
            ApiResponse<PyHotStockGroupedResponseDto> response = pyHotStockService
                    .getAllStocksGrouped();
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Get all stocks grouped failed: {}", e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error(500, "Failed to fetch hot stocks"));
        }
    }

    // ── GET STOCKS BY CATEGORY ───────────────────────────────────────────────
    @Operation(
            summary = "Get Hot Stocks By Category",
            description = "Fetch active hot stocks by specific category. "
            + "category: INTRADAY, SHORT_TERM, MID_TERM, LONG_TERM. "
            + "Visible to all roles.")
    @GetMapping("/category/{category}")
    public ResponseEntity<ApiResponse<List<PyHotStockResponseDto>>> getStocksByCategory(
            @PathVariable HotStockCategory category) {
        try {
            ApiResponse<List<PyHotStockResponseDto>> response = pyHotStockService
                    .getStocksByCategory(category);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Get stocks by category failed | category={}: {}", category, e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Failed to fetch hot stocks by category"));
        }
    }

    // ── GET STOCKS BY USER ───────────────────────────────────────────────────
    @Operation(
            summary = "Get Hot Stocks By User",
            description = "Fetch all active stocks recommended by a specific user.")
    @GetMapping("/by-user/{pyId}")
    public ResponseEntity<ApiResponse<List<PyHotStockResponseDto>>> getStocksByUser(
            @PathVariable Long pyId) {
        try {
            ApiResponse<List<PyHotStockResponseDto>> response = pyHotStockService
                    .getStocksByUser(pyId);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Get stocks by user failed | pyId={}: {}", pyId, e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Failed to fetch hot stocks for user"));
        }
    }

    @Operation(
            summary = "Get Hot Stocks By Date",
            description = "Fetch all hot stocks (active + inactive) for a specific date "
            + "grouped by category. Date format: yyyy-MM-dd. Visible to all roles.")
    @GetMapping("/date/{date}")
    public ResponseEntity<ApiResponse<PyHotStockGroupedResponseDto>> getStocksByDate(
            @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        try {
            ApiResponse<PyHotStockGroupedResponseDto> response = pyHotStockService
                    .getStocksByDate(date);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Get stocks by date failed | date={}: {}", date, e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Failed to fetch hot stocks for date"));
        }
    }

// ── GET STOCKS BY DATE AND CATEGORY ──────────────────────────────────────
    @Operation(
            summary = "Get Hot Stocks By Date and Category",
            description = "Fetch hot stocks for a specific date and category with automatic fallback to latest available. Date format: yyyy-MM-dd. Visible to all roles.")
    @GetMapping("/date/{date}/category/{category}")
    public ResponseEntity<ApiResponse<List<PyHotStockResponseDto>>> getStocksByDateAndCategory(
            @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @PathVariable HotStockCategory category) {
        try {
            ApiResponse<List<PyHotStockResponseDto>> response = pyHotStockService
                    .getStocksByDateAndCategory(date, category);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Get stocks by date and category failed | date={}, category={}: {}", date, category, e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Failed to fetch hot stocks for date and category"));
        }
    }

    // ── GET LATEST STOCKS BY CATEGORY ─────────────────────────────────────────
    @Operation(
            summary = "Get Latest Active Hot Stocks By Category",
            description = "Fetch latest available active hot stocks for a category regardless of date. Visible to all roles.")
    @GetMapping("/latest/category/{category}")
    public ResponseEntity<ApiResponse<List<PyHotStockResponseDto>>> getLatestStocksByCategory(
            @PathVariable HotStockCategory category) {
        try {
            ApiResponse<List<PyHotStockResponseDto>> response = pyHotStockService
                    .getLatestStocksByCategory(category);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Get latest stocks by category failed | category={}: {}", category, e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Failed to fetch latest hot stocks for category"));
        }
    }
}
