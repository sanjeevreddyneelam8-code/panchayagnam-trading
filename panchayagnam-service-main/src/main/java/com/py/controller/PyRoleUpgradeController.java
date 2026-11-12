package com.py.controller;

import com.py.common.dto.ApiResponse;
import com.py.dto.*;
import com.py.entity.PyRoleUpgradeRequest;
import com.py.entity.PySubscription;
import com.py.entity.PyUser;
import com.py.repo.PySubscriptionRepository;
import com.py.repo.PyUserRepository;
import com.py.service.PyUserService;
import io.swagger.v3.oas.annotations.Operation;
import jakarta.validation.Valid;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class PyRoleUpgradeController {

    private static final Logger log = LogManager.getLogger(PyRoleUpgradeController.class);

    @Autowired
    private PyUserService pyUserService;

    @Autowired
    private PySubscriptionRepository pySubscriptionRepository;

    @Autowired
    private PyUserRepository pyUserRepository;

    @Operation(summary = "Get subscription status",
            description = "Returns current subscription details for a user by type")
    @GetMapping("/subscription/status/{userId}")
    public ResponseEntity<PyApiResponseDto<PySubscriptionResponseDto>> getSubscriptionStatus(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "CLIENT") String type) {
        try {
            PyUser user = pyUserRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("User not found"));

            PySubscription.Type subType = PySubscription.Type.valueOf(type.toUpperCase());

            PySubscription sub = pySubscriptionRepository
                    .findTopByPyUserAndTypeOrderByCreatedAtDesc(user, subType)
                    .orElseThrow(() -> new RuntimeException("No subscription found"));

            boolean expired = sub.getEndDate().isBefore(LocalDateTime.now());
            if (expired && sub.getStatus() != PySubscription.Status.EXPIRED) {
                sub.setStatus(PySubscription.Status.EXPIRED);
                pySubscriptionRepository.save(sub);
            }

            long daysLeft = ChronoUnit.DAYS.between(LocalDateTime.now(), sub.getEndDate());

            PySubscriptionResponseDto dto = new PySubscriptionResponseDto();
            dto.setSubscriptionId(sub.getId());
            dto.setUserId(user.getId());
            dto.setFullName(user.getFullName());
            dto.setType(sub.getType().name());
            dto.setPlanMonths(sub.getPlanMonths());
            dto.setStartDate(sub.getStartDate());
            dto.setEndDate(sub.getEndDate());
            dto.setStatus(sub.getStatus().name());
            dto.setIsTrial(sub.getIsTrial());
            dto.setExpiresInDays(Math.max(daysLeft, 0));
            dto.setExpiredFlag(expired);

            return ResponseEntity.ok(
                    PyApiResponseDto.success("Subscription status fetched", dto));

    } catch (RuntimeException e) {
        log.error("Get subscription status failed | userId={}: {}", userId, e.getMessage(), e);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
            .body(PyApiResponseDto.failure("Failed to fetch subscription status"));
    }
    }


    @PostMapping("/user/raise-request/{pyId}")
    public ResponseEntity<PyApiResponseDto<PyRoleUpgradeResponseDto>> raiseAdminRequest(
            @PathVariable Long pyId,
            @Valid @RequestBody PyRoleUpgradeRequestDto requestDto) {
        log.info("POST /user/raise-request | pyId={}", pyId);
        try {
            PyRoleUpgradeResponseDto response = pyUserService.raiseAdminRequest(pyId, requestDto);
            log.info("Admin request raised | pyId={}, requestId={}", pyId, response.getRequestId());
            return ResponseEntity
                    .status(HttpStatus.CREATED)
                    .body(PyApiResponseDto.success("Admin request raised successfully", response));
    } catch (RuntimeException e) {
        log.error("Raise admin request failed | pyId={}: {}", pyId, e.getMessage(), e);
        return ResponseEntity
            .status(HttpStatus.BAD_REQUEST)
            .body(PyApiResponseDto.failure("Failed to raise admin request"));
    }
    }



    @Operation(summary = "Get All Role Upgrade Requests",
            description = "Super Admin views all requests with counts — pending, approved, rejected")
    @GetMapping("/super-admin/all-requests")
    public ResponseEntity<PyApiResponseDto<PyRoleUpgradeRequestSummaryDto>> getAllRequests(
            @RequestParam(required = false) String requestType) {
        try {
            PyRoleUpgradeRequestSummaryDto response = pyUserService.getAllRequests(requestType);
            return ResponseEntity.ok(
                    PyApiResponseDto.success("Requests fetched successfully", response));
    } catch (RuntimeException e) {
        log.error("Get all requests failed: {}", e.getMessage(), e);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
            .body(PyApiResponseDto.failure("Failed to fetch requests"));
    }
    }

    // ── SUPER ADMIN: Get All Pending Requests ────────────────────────────────
    @GetMapping("/super-admin/pending-requests")
    public ResponseEntity<PyApiResponseDto<List<PyRoleUpgradeResponseDto>>> getPendingRequests() {
        log.info("GET /super-admin/pending-requests");
        try {
            List<PyRoleUpgradeResponseDto> response = pyUserService.getPendingRequests();
            log.info("Fetched {} pending requests", response.size());
            return ResponseEntity
                    .status(HttpStatus.OK)
                    .body(PyApiResponseDto.success("Pending requests fetched successfully", response));
    } catch (RuntimeException e) {
        log.error("Get pending requests failed: {}", e.getMessage(), e);
        return ResponseEntity
            .status(HttpStatus.BAD_REQUEST)
            .body(PyApiResponseDto.failure("Failed to fetch pending requests"));
    }
    }
    // ── SUPER ADMIN: Get All Requests with Summary ───────────────────────────



    // ── SUPER ADMIN: Approve or Reject Request ───────────────────────────────
    // superAdminPyId will come from JWT token in future
    // For now passing as request param
    @PutMapping("/super-admin/review-request/{superAdminPyId}")
    public ResponseEntity<PyApiResponseDto<PyRoleUpgradeResponseDto>> reviewRequest(
            @PathVariable Long superAdminPyId,
            @Valid @RequestBody PyReviewRequestDto requestDto) {
        log.info("PUT /super-admin/review-request | superAdminPyId={}, requestId={}, status={}",
                superAdminPyId, requestDto.getRequestId(), requestDto.getStatus());
        try {
            PyRoleUpgradeResponseDto response = pyUserService.reviewRequest(superAdminPyId, requestDto);
            log.info("Request reviewed | requestId={}, newStatus={}", requestDto.getRequestId(), requestDto.getStatus());
            return ResponseEntity
                    .status(HttpStatus.OK)
                    .body(PyApiResponseDto.success("Request reviewed successfully", response));
        } catch (RuntimeException e) {
            log.error("Review request failed | requestId={}: {}", requestDto.getRequestId(), e.getMessage());
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(PyApiResponseDto.failure(e.getMessage()));
        }
    }

    // ── USER: Get My Requests ────────────────────────────────────────────────
    @GetMapping("/user/my-requests/{pyId}")
    public ResponseEntity<PyApiResponseDto<List<PyRoleUpgradeResponseDto>>> getMyRequests(
            @PathVariable Long pyId, @RequestParam(required = false) String requestType) {
        try {
            // If requestType passed → validate and filter, else return all
            PyRoleUpgradeRequest.RequestType type = null;
            if (requestType != null && !requestType.isBlank()) {
                try {
                    type = PyRoleUpgradeRequest.RequestType.valueOf(requestType.toUpperCase());
                } catch (IllegalArgumentException e) {
                    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                            .body(PyApiResponseDto.failure("Invalid requestType: " + requestType + ". Must be CLIENT or GROUP"));
                }
            }

            List<PyRoleUpgradeResponseDto> response = pyUserService.getMyRequests(pyId, type);
            return ResponseEntity.status(HttpStatus.OK).body(PyApiResponseDto.success("Requests fetched successfully", response));
        } catch (RuntimeException e) {
            log.error("Get my requests failed | pyId={}: {}", pyId, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(PyApiResponseDto.failure("Failed to fetch requests for user"));
        }
    }

// ── DEMOTE ADMIN TO USER ──────────────────────────────────────────────────
    @Operation(
            summary = "Demote Admin to User",
            description = "Super Admin demotes an Admin to User. "
            + "All groups of the Admin will be deactivated.")
    @PostMapping("/demote-admin")
    public ResponseEntity<ApiResponse<PyRoleChangeResponseDto>> demoteAdminToUser(
            @Valid @RequestBody PyRoleChangeRequestDto requestDto) {
        try {
            ApiResponse<PyRoleChangeResponseDto> response = pyUserService
                    .demoteAdminToUser(requestDto);
            return ResponseEntity.status(response.getStatusCode()).body(response);
    } catch (RuntimeException e) {
        log.error("Demote admin failed: {}", e.getMessage(), e);
        return ResponseEntity
            .status(HttpStatus.BAD_REQUEST)
            .body(ApiResponse.error(400, "Failed to demote admin"));
    }
    }

// ── PROMOTE USER TO ADMIN ─────────────────────────────────────────────────
    @Operation(
            summary = "Promote User to Admin",
            description = "Super Admin promotes a User to Admin. "
            + "All previous groups of the User will be restored.")
    @PostMapping("/promote-user")
    public ResponseEntity<ApiResponse<PyRoleChangeResponseDto>> promoteUserToAdmin(
            @Valid @RequestBody PyRoleChangeRequestDto requestDto) {
        try {
            ApiResponse<PyRoleChangeResponseDto> response = pyUserService
                    .promoteUserToAdmin(requestDto);
            return ResponseEntity.status(response.getStatusCode()).body(response);
    } catch (RuntimeException e) {
        log.error("Promote user failed: {}", e.getMessage(), e);
        return ResponseEntity
            .status(HttpStatus.BAD_REQUEST)
            .body(ApiResponse.error(400, "Failed to promote user"));
    }
    }
}
