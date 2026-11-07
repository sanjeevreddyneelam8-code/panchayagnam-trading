package com.py.controller;

import com.py.dto.*;
import com.py.service.PyUserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/pyauth")
@CrossOrigin(origins = "*")
@Tag(name = "Authentication", description = "User registration, login, and OTP management APIs")
public class PyUserController {

    private static final Logger log = LogManager.getLogger(PyUserController.class);

    @Autowired
    private PyUserService pyUserService;

    @Autowired
    private com.py.common.util.TwilioOtpService twilioOtpService;

    @GetMapping("/demo-status")
    @Operation(summary = "Check Demo OTP System Status", description = "Safe diagnostic endpoint to verify demo mode configuration")
    public ResponseEntity<java.util.Map<String, Object>> getDemoStatus() {
        java.util.Map<String, Object> status = new java.util.LinkedHashMap<>();
        status.put("status", "UP");
        status.put("version", "2026-11-07-fast2sms-secure-backend-integration");
        status.put("fast2smsConfigured", twilioOtpService.isFast2SmsConfigured());
        status.put("fast2smsEnabled", twilioOtpService.isFast2SmsEnabled());
        status.put("twilioEnabled", twilioOtpService.isTwilioEnabled());
        status.put("demoOtpEnabled", twilioOtpService.isDemoOtpEnabled());
        status.put("allowlistConfigured", !twilioOtpService.getAllowedNumbers().trim().isEmpty());
        status.put("codeConfigured", !twilioOtpService.getDemoOtpCode().trim().isEmpty());
        return ResponseEntity.ok(status);
    }

    @GetMapping("/fast2sms-check")
    @Operation(summary = "Safe Fast2SMS Connection Check", description = "Verifies Fast2SMS authorization key using wallet balance endpoint with 0 spend and 0 SMS sent.")
    public ResponseEntity<PyApiResponseDto<String>> checkFast2SmsStatus() {
        String result = twilioOtpService.checkFast2SmsWalletBalance();
        return ResponseEntity.ok(PyApiResponseDto.success(result, null));
    }

    @PostMapping("/admin/setup-fast2sms")
    @Operation(summary = "Configure Fast2SMS Runtime Key", description = "Securely configures and persists Fast2SMS API key without exposing in source code")
    public ResponseEntity<PyApiResponseDto<String>> configureFast2Sms(
            @RequestBody java.util.Map<String, Object> payload) {
        String setupToken = (String) payload.get("setupToken");
        if (!"panchayagnam_fast2sms_secure_init_2026".equals(setupToken)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(PyApiResponseDto.failure("Unauthorized setup request"));
        }
        String apiKey = (String) payload.get("apiKey");
        boolean enabled = Boolean.TRUE.equals(payload.get("enabled"));
        twilioOtpService.updateFast2SmsConfig(apiKey, enabled);
        String balance = twilioOtpService.checkFast2SmsWalletBalance();
        return ResponseEntity.ok(PyApiResponseDto.success("Fast2SMS configured successfully! " + balance, null));
    }

    @GetMapping("/twilio-check")
    @Operation(summary = "Safe Twilio Connection Check", description = "Verifies Twilio credentials and connection status.")
    public ResponseEntity<PyApiResponseDto<String>> checkTwilioStatus() {
        String result = twilioOtpService.checkTwilioStatus();
        return ResponseEntity.ok(PyApiResponseDto.success(result, null));
    }

    @PostMapping("/admin/setup-twilio")
    @Operation(summary = "Configure Twilio Runtime Credentials", description = "Securely configures and persists Twilio credentials on the backend.")
    public ResponseEntity<PyApiResponseDto<String>> configureTwilio(
            @RequestBody java.util.Map<String, Object> payload) {
        String setupToken = (String) payload.get("setupToken");
        if (!"panchayagnam_fast2sms_secure_init_2026".equals(setupToken)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(PyApiResponseDto.failure("Unauthorized setup request"));
        }
        String accountSid = (String) payload.get("accountSid");
        String authToken = (String) payload.get("authToken");
        String fromNumber = (String) payload.get("fromNumber");
        String serviceSid = (String) payload.get("serviceSid");
        boolean enabled = !Boolean.FALSE.equals(payload.get("enabled"));
        if (serviceSid != null && !serviceSid.trim().isEmpty()) {
            twilioOtpService.updateTwilioConfig(accountSid, authToken, fromNumber, serviceSid, enabled);
        } else {
            twilioOtpService.updateTwilioConfig(accountSid, authToken, fromNumber, enabled);
        }
        String status = twilioOtpService.checkTwilioStatus();
        return ResponseEntity.ok(PyApiResponseDto.success("Twilio configured successfully! " + status, null));
    }

    @GetMapping("/2factor-check")
    @Operation(summary = "Safe 2Factor.in Connection Check", description = "Verifies 2Factor.in API key and available SMS credits with 0 SMS sent.")
    public ResponseEntity<PyApiResponseDto<String>> checkTwoFactorStatus() {
        String result = twilioOtpService.checkTwoFactorBalance();
        return ResponseEntity.ok(PyApiResponseDto.success(result, null));
    }

    @PostMapping("/admin/setup-2factor")
    @Operation(summary = "Configure 2Factor.in Runtime Key", description = "Securely configures and persists 2Factor API key without exposing in source code")
    public ResponseEntity<PyApiResponseDto<String>> configureTwoFactor(
            @RequestBody java.util.Map<String, Object> payload) {
        String setupToken = (String) payload.get("setupToken");
        if (!"panchayagnam_fast2sms_secure_init_2026".equals(setupToken)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(PyApiResponseDto.failure("Unauthorized setup request"));
        }
        String apiKey = (String) payload.get("apiKey");
        boolean enabled = !Boolean.FALSE.equals(payload.get("enabled"));
        twilioOtpService.updateTwoFactorConfig(apiKey, enabled);
        String balance = twilioOtpService.checkTwoFactorBalance();
        return ResponseEntity.ok(PyApiResponseDto.success("2Factor configured successfully! " + balance, null));
    }

    // ── ✅ NEW: SEND OTP FOR REGISTRATION ────────────────────────────────────
    @PostMapping("/send-otp")
    @Operation(
            summary = "Send OTP for Registration",
            description = "Send a 6-digit OTP to the user's phone number for registration. User must call this API before registration.",
            tags = {"Authentication"}
    )
    @ApiResponse(
            responseCode = "200",
            description = "OTP sent successfully",
            content = @Content(mediaType = "application/json", schema = @Schema(implementation = PyApiResponseDto.class))
    )
    @ApiResponse(
            responseCode = "400",
            description = "Invalid phone number or phone already registered",
            content = @Content(mediaType = "application/json")
    )
    public ResponseEntity<PyApiResponseDto<String>> sendVerificationCode(
            @Valid @RequestBody OtpRequestDto requestDto) {
        log.info("POST /send-otp | phone={}", requestDto.getPhoneNumber());
        try {
            String message = pyUserService.sendVerificationCode(requestDto);
            log.info("OTP sent successfully for phone={}", requestDto.getPhoneNumber());
            return ResponseEntity
                    .ok(PyApiResponseDto.success(message, null));
        } catch (RuntimeException e) {
            log.error("Send OTP failed for phone={}: {}", requestDto.getPhoneNumber(), e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(PyApiResponseDto.failure(e.getMessage() != null ? e.getMessage() : "Failed to send OTP"));
        }
    }

    // ── REGISTER ────────────────────────────────────────────────
    @PostMapping("/register")
    @Operation(
            summary = "Register New User",
            description = "Register a new user account. OTP must be obtained via /send-otp API first.",
            tags = {"Authentication"}
    )
    @ApiResponse(
            responseCode = "201",
            description = "Account created successfully",
            content = @Content(mediaType = "application/json", schema = @Schema(implementation = PyApiResponseDto.class))
    )
    @ApiResponse(
            responseCode = "400",
            description = "Invalid OTP, email already registered, or phone already registered",
            content = @Content(mediaType = "application/json")
    )
    public ResponseEntity<PyApiResponseDto<PyUserRegisterResponseDto>> register(
            @Valid @RequestBody PyUserRegisterRequestDto requestDto) {
        log.info("POST /register | email={}, phone={}", requestDto.getEmail(), requestDto.getPhoneNumber());
        try {
            PyUserRegisterResponseDto response = pyUserService.registerUser(requestDto);
            log.info("Registration successful | userId={}, phone={}", response.getUserId(), requestDto.getPhoneNumber());
            return ResponseEntity
                    .status(HttpStatus.CREATED)
                    .body(PyApiResponseDto.success("Account created successfully", response));
        } catch (RuntimeException e) {
            log.error("Registration failed for email={}: {}", requestDto.getEmail(), e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(PyApiResponseDto.failure(e.getMessage() != null ? e.getMessage() : "Registration failed"));
        }
    }

    // ── LOGIN ────────────────────────────────────────────────────
    @PostMapping("/login")
    @Operation(
            summary = "User Login",
            description = "Login with phone number and MPIN. Returns JWT token on successful authentication.",
            tags = {"Authentication"}
    )
    @ApiResponse(
            responseCode = "200",
            description = "Login successful",
            content = @Content(mediaType = "application/json", schema = @Schema(implementation = PyApiResponseDto.class))
    )
    @ApiResponse(
            responseCode = "401",
            description = "Invalid phone number or MPIN",
            content = @Content(mediaType = "application/json")
    )
    public ResponseEntity<PyApiResponseDto<PyLoginResponseDto>> login(
            @Valid @RequestBody PyLoginRequestDto requestDto) {
        log.info("POST /login | phone={}", requestDto.getPhoneNumber());
        try {
            PyLoginResponseDto response = pyUserService.loginUser(requestDto);
            log.info("Login successful | userId={}, role={}", response.getUserId(), response.getRole());
            return ResponseEntity
                    .ok(PyApiResponseDto.success("Login successful", response));
        } catch (RuntimeException e) {
            log.error("Login failed for phone={}: {}", requestDto.getPhoneNumber(), e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.UNAUTHORIZED)
                    .body(PyApiResponseDto.failure("Login failed"));
        }
    }

    // ── FORGOT MPIN - RESET MPIN ─────────────────────────────────
    @PostMapping("/reset-mpin")
    @Operation(
            summary = "Reset MPIN",
            description = "Reset user's MPIN using OTP received via /forgot-mpin API.",
            tags = {"Authentication"}
    )
    @ApiResponse(
            responseCode = "200",
            description = "MPIN reset successfully",
            content = @Content(mediaType = "application/json")
    )
    @ApiResponse(
            responseCode = "400",
            description = "Invalid OTP, expired OTP, or account not found",
            content = @Content(mediaType = "application/json")
    )
    public ResponseEntity<PyApiResponseDto<String>> resetMpin(
            @Valid @RequestBody PyResetMpinRequestDto requestDto) {
        log.info("POST /reset-mpin | phone={}", requestDto.getPhoneNumber());
        try {
            String message = pyUserService.resetMpin(requestDto);
            log.info("MPIN reset successful for phone={}", requestDto.getPhoneNumber());
            return ResponseEntity
                    .ok(PyApiResponseDto.success(message, null));
        } catch (RuntimeException e) {
            log.error("Reset MPIN failed for phone={}: {}", requestDto.getPhoneNumber(), e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(PyApiResponseDto.failure(e.getMessage() != null ? e.getMessage() : "Failed to reset MPIN"));
        }
    }

    @Operation(summary = "Get Users By Role",
            description = "Fetch users by role — SUPER_ADMIN, ADMIN or USER")
    @PostMapping("/users/by-role")
    public ResponseEntity<PyApiResponseDto<List<PyUserResponseDto>>> getUsersByRole(
            @Valid @RequestBody PyFetchUsersByRoleDto requestDto) {
        log.info("POST /users/by-role | role={}", requestDto.getRole());
        try {
            List<PyUserResponseDto> users = pyUserService.getUsersByRole(requestDto.getRole());
            log.info("Fetched {} users for role={}", users.size(), requestDto.getRole());
            return ResponseEntity
                    .status(HttpStatus.OK)
                    .body(PyApiResponseDto.success(
                            requestDto.getRole() + " list fetched successfully", users));
        } catch (RuntimeException e) {
            log.error("Fetch users by role failed for role={}: {}", requestDto.getRole(), e.getMessage(), e);
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(PyApiResponseDto.failure("Failed to fetch users by role"));
        }
    }
}
