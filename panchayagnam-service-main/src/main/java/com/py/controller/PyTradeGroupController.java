package com.py.controller;

import com.py.common.dto.ApiResponse;
import com.py.dto.PyTradeGroupRequestDto;
import com.py.dto.PyTradeGroupResponseDto;
import com.py.service.PyTradeGroupService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/trade-group")
@Tag(name = "Trade Group", description = "Trade Group operations — Create, Update, Delete, Add/Remove Members")
public class PyTradeGroupController {

    private static final Logger log = LogManager.getLogger(PyTradeGroupController.class);

    @Autowired
    private PyTradeGroupService pyTradeGroupService;

    // ── ALL GROUP OPERATIONS ─────────────────────────────────────────────────
    @Operation(
            summary = "Trade Group Operations",
            description = "Handle all group operations in single API. "
            + "actionType: CREATE, UPDATE, DELETE, ADD_MEMBERS, REMOVE_MEMBER")
    @PostMapping("/operations")
    public ResponseEntity<ApiResponse<?>> groupOperations(
            @Valid @RequestBody PyTradeGroupRequestDto requestDto) {
        log.info("POST /trade-group/operations | action={}, groupId={}, pyId={}",
                requestDto.getActionType(), requestDto.getGroupId(), requestDto.getPyId());
        try {
            ApiResponse<?> response = pyTradeGroupService
                    .groupOperations(requestDto);
            log.info("Trade group operation completed | action={}", requestDto.getActionType());
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Trade group operation failed | action={}: {}", requestDto.getActionType(), e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Trade group operation failed"));
        }
    }

    // ── GET GROUP BY ID ──────────────────────────────────────────────────────
    @Operation(
            summary = "Get Group By ID",
            description = "Fetch group details with all members by group ID")
    @GetMapping("/{groupId}")
    public ResponseEntity<ApiResponse<PyTradeGroupResponseDto>> getGroupById(
            @PathVariable Long groupId) {
        log.info("GET /trade-group/{}", groupId);
        try {
            ApiResponse<PyTradeGroupResponseDto> response = pyTradeGroupService
                    .getGroupById(groupId, true);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Get group by id failed | groupId={}: {}", groupId, e.getMessage());
            return ResponseEntity
                    .status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error(404, "Group not found"));
        }
    }

    // ── GET ALL GROUPS BY USER ───────────────────────────────────────────────
    @Operation(
            summary = "Get All Groups By User",
            description = "Fetch all active groups created by a specific user")
    @GetMapping("/all/{pyId}")
    public ResponseEntity<ApiResponse<List<PyTradeGroupResponseDto>>> getAllGroupsByUser(
            @PathVariable Long pyId) {
        log.info("GET /trade-group/all/{}", pyId);
        try {
            ApiResponse<List<PyTradeGroupResponseDto>> response = pyTradeGroupService
                    .getAllGroupsByUser(pyId, false);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (RuntimeException e) {
            log.error("Get all groups by user failed | pyId={}: {}", pyId, e.getMessage());
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "Failed to fetch groups for user"));
        }
    }
}
