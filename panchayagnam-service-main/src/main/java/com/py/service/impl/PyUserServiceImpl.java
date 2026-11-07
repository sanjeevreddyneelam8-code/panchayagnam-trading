package com.py.service.impl;

import com.py.common.dto.ApiResponse;
import com.py.dto.*;
import com.py.entity.PyRoleUpgradeRequest;
import com.py.entity.PyUser;
import com.py.repo.PyRoleUpgradeRequestRepository;
import com.py.repo.PyUserRepository;
import com.py.service.PyUserService;
import org.apache.commons.lang3.StringUtils;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import com.py.common.util.PyJwtUtil;
import com.py.common.util.TwilioOtpService;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.demataccount.repository.PyTradeGroupRepository;
import com.py.entity.PySubscription;
import com.py.entity.PySubscription.Type;
import com.py.repo.PySubscriptionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class PyUserServiceImpl implements PyUserService {

    private static final Logger logger = LogManager.getLogger(PyUserServiceImpl.class);
    private static final int OTP_EXPIRY_MINUTES = 5;

    @Autowired
    private PyUserRepository pyUserRepository;

    @Autowired
    private BCryptPasswordEncoder passwordEncoder;

    @Autowired
    private PyRoleUpgradeRequestRepository pyRoleUpgradeRequestRepository;

    @Autowired
    private PyJwtUtil pyJwtUtil;

    @Autowired
    private TwilioOtpService twilioOtpService;

    @Autowired
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @Autowired
    private PyTradeGroupRepository pyTradeGroupRepository;

    @Autowired
    private PySubscriptionRepository pySubscriptionRepository;

    // ── REGISTER ────────────────────────────────────────────────
    @Override
    public PyUserRegisterResponseDto registerUser(PyUserRegisterRequestDto requestDto) {
        logger.info("Register user | email={}, phone={}", requestDto.getEmail(), requestDto.getPhoneNumber());
        if (pyUserRepository.existsByEmail(requestDto.getEmail())) {
            logger.warn("Registration failed — email already registered: {}", requestDto.getEmail());
            throw new RuntimeException("Email already registered");
        }
        if (pyUserRepository.existsByPhoneNumber(requestDto.getPhoneNumber())) {
            logger.warn("Registration failed — phone already registered: {}", requestDto.getPhoneNumber());
            throw new RuntimeException("Phone number already registered");
        }

        // ✅ NEW: OTP verification using Twilio (twilio logic kept inside
        // TwilioOtpService)
        if (!verifyOtp(requestDto.getPhoneNumber(), requestDto.getOtp())) {
            throw new RuntimeException("Invalid or expired OTP. Please try again");
        }

        PyUser user = new PyUser();
        user.setFullName(requestDto.getFullName());
        user.setEmail(requestDto.getEmail());
        user.setPhoneNumber(requestDto.getPhoneNumber());
        user.setMpin(passwordEncoder.encode(requestDto.getMpin()));
        user.setRole(PyUser.Role.USER);
        user.setIsActive(true);
        user.setIsPhoneVerified(true); // ✅ Set to true after successful OTP verification

        PyUser savedUser = pyUserRepository.save(user);
        logger.info("User registered successfully | userId={}, phone={}", savedUser.getId(),
                savedUser.getPhoneNumber());

        // Create CLIENT trial subscription
        PySubscription trial = new PySubscription();
        trial.setPyUser(savedUser);
        trial.setType(PySubscription.Type.CLIENT);
        trial.setIsTrial(true);
        trial.setStatus(PySubscription.Status.TRIAL);
        trial.setStartDate(LocalDateTime.now());
        trial.setEndDate(LocalDateTime.now().plusMonths(1));
        trial.setNoOfClients(4);
        pySubscriptionRepository.save(trial);
        logger.info("Trial subscription created | userId={}", savedUser.getId());

        PyUserRegisterResponseDto responseDto = new PyUserRegisterResponseDto();
        responseDto.setUserId(savedUser.getId());
        responseDto.setFullName(savedUser.getFullName());
        responseDto.setEmail(savedUser.getEmail());
        responseDto.setPhoneNumber(savedUser.getPhoneNumber());
        responseDto.setRole(savedUser.getRole().name());
        responseDto.setMessage("Account created successfully");
        return responseDto;
    }

    // ── LOGIN ────────────────────────────────────────────────────
    @Override
    public PyLoginResponseDto loginUser(PyLoginRequestDto requestDto) {
        logger.info("Login attempt | phone={}", requestDto.getPhoneNumber());
        PyUser user = pyUserRepository.findByPhoneNumber(requestDto.getPhoneNumber())
                .orElseThrow(() -> {
                    logger.warn("Login failed — user not found | phone={}", requestDto.getPhoneNumber());
                    return new RuntimeException("User not found with this phone number");
                });

        if (!user.getIsActive()) {
            logger.warn("Login failed — account deactivated | userId={}", user.getId());
            throw new RuntimeException("Your account is deactivated. Please contact support");
        }
        if (!passwordEncoder.matches(requestDto.getMpin(), user.getMpin())) {
            logger.warn("Login failed — invalid MPIN | userId={}", user.getId());
            throw new RuntimeException("Invalid MPIN. Please try again");
        }

        String token = pyJwtUtil.generateToken(
                user.getId(),
                user.getPhoneNumber(),
                user.getRole().name());

        PyLoginResponseDto responseDto = new PyLoginResponseDto();
        responseDto.setUserId(user.getId());
        responseDto.setFullName(user.getFullName());
        responseDto.setEmail(user.getEmail());
        responseDto.setPhoneNumber(user.getPhoneNumber());
        responseDto.setRole(user.getRole().name());
        responseDto.setToken(token);

        String type;

        if(user.getRole().name().equals(PyUser.Role.USER.name())){
            type = Type.CLIENT.name();
        }else if (user.getRole().name().equals(PyUser.Role.SUPER_ADMIN.name())){
            type = Type.ADMIN.name();
        }else{
            type = user.getRole().name();
        }

        // Attach subscription info
        pySubscriptionRepository
                .findTopByPyUserAndTypeOrderByCreatedAtDesc(user, Type.valueOf(type))
                .ifPresent(sub -> {
                    long daysLeft = ChronoUnit.DAYS.between(LocalDateTime.now(), sub.getEndDate());
                    boolean expired = sub.getEndDate().isBefore(LocalDateTime.now());

                    // Auto update status if expired
                    if (expired && sub.getStatus() != PySubscription.Status.EXPIRED) {
                        sub.setStatus(PySubscription.Status.EXPIRED);
                        pySubscriptionRepository.save(sub);
                    }

                    responseDto.setExpiresInDays(Math.max(daysLeft, 0));
                    responseDto.setExpiredFlag(expired);
                    responseDto.setNoOfClients(sub.getNoOfClients());
                });
        logger.info("Login successful | userId={}, role={}", user.getId(), user.getRole());
        return responseDto;
    }

    // ── ✅ NEW: SEND OTP FOR REGISTRATION ────────────────────────────────────
    @Override
    public String sendVerificationCode(OtpRequestDto requestDto) {
        // Check if phone number is already registered for Registration requests
        if (StringUtils.isNotEmpty(requestDto.getCodeReqFor()) && requestDto.getCodeReqFor().equals("Registration")
                && pyUserRepository.existsByPhoneNumber(requestDto.getPhoneNumber())) {
            throw new RuntimeException("Phone number already registered");
        }

        // Security check: Block demo OTP reset on administrative accounts
        if (StringUtils.isNotEmpty(requestDto.getCodeReqFor()) && !requestDto.getCodeReqFor().equals("Registration")) {
            if (!twilioOtpService.isTwilioEnabled() && twilioOtpService.isDemoOtpEnabled()) {
                pyUserRepository.findByPhoneNumber(requestDto.getPhoneNumber()).ifPresent(u -> {
                    if (u.getRole() == PyUser.Role.SUPER_ADMIN || u.getRole() == PyUser.Role.ADMIN) {
                        logger.warn("Security Alert: Blocked demo OTP request on privileged account: {}", maskPhoneNumber(requestDto.getPhoneNumber()));
                        throw new RuntimeException("Demo OTP cannot be used for administrative accounts.");
                    }
                });
            }
        }

        try {
            // Send OTP using TwilioOtpService (Twilio-specific logic resides inside service)
            // Use custom-message sender so SMS body can be branded/customized
            boolean otpSent = twilioOtpService.sendOtpV2(requestDto.getPhoneNumber(), requestDto.getCodeReqFor());

            if (otpSent) {
                logger.info("OTP sent successfully for registration to phone: "
                        + maskPhoneNumber(requestDto.getPhoneNumber()));
                if (twilioOtpService.isFast2SmsEnabled() || twilioOtpService.isTwilioEnabled()) {
                    return "OTP sent successfully to your mobile number. Please check your SMS.";
                } else if (twilioOtpService.isFast2SmsConfigured()) {
                    return "OTP generated in Safe Dry-Run mode. Real SMS is paused to protect your credits.";
                } else if (twilioOtpService.isDemoOtpEnabled()) {
                    return "Demo verification initiated. Please enter your configured demo code.";
                } else {
                    return "OTP generated successfully. Verification ready.";
                }
            } else {
                logger.error("Failed to send OTP for phone: " + maskPhoneNumber(requestDto.getPhoneNumber()));
                throw new RuntimeException("Failed to send OTP. Please try again later.");
            }
        } catch (IllegalArgumentException | IllegalStateException e) {
            logger.warn("Validation/configuration issue sending OTP: {}", e.getMessage());
            throw new RuntimeException(e.getMessage());
        } catch (RuntimeException e) {
            logger.error("Error sending OTP for registration: {}", e.getMessage());
            throw e;
        } catch (Exception e) {
            logger.error("Unexpected error sending OTP for registration", e);
            throw new RuntimeException("Failed to send OTP: " + e.getMessage());
        }
    }

    // ── ✅ NEW: VERIFY OTP FOR REGISTRATION ──────────────────────────────────
    @Override
    public boolean verifyOtp(String phoneNumber, String otp) {
        try {
            // Verify OTP using the custom-message verification store
            boolean isValidOtp = twilioOtpService.verifyOtpV2(phoneNumber, otp);

            logger.info("OTP verification {} for Phone: {}", maskPhoneNumber(phoneNumber),
                    isValidOtp ? " is Successful" : " Failed");
            return isValidOtp;
        } catch (Exception e) {
            logger.error("Error verifying OTP for registration", e);
            return false;
        }
    }

    // ── FORGOT MPIN - RESET MPIN ─────────────────────────────────
    @Override
    @Transactional
    public String resetMpin(PyResetMpinRequestDto requestDto) {
        logger.info("Reset MPIN | phone={}", requestDto.getPhoneNumber());
        PyUser user = pyUserRepository.findByPhoneNumber(requestDto.getPhoneNumber())
                .orElseThrow(() -> new RuntimeException("No account found with this phone number"));

        // Security check: Block demo OTP reset on administrative accounts
        if (!twilioOtpService.isTwilioEnabled() && twilioOtpService.isDemoOtpEnabled()) {
            if (user.getRole() == PyUser.Role.SUPER_ADMIN || user.getRole() == PyUser.Role.ADMIN) {
                logger.warn("Security Alert: Blocked demo OTP reset attempt on privileged account: {}", maskPhoneNumber(requestDto.getPhoneNumber()));
                throw new RuntimeException("Demo OTP cannot be used to reset administrative accounts.");
            }
        }

        // ✅ NEW: OTP verification using Twilio (twilio logic kept inside
        // TwilioOtpService)
        if (!verifyOtp(requestDto.getPhoneNumber(), requestDto.getOtp())) {
            throw new RuntimeException("Invalid or expired OTP. Please try again");
        }

        if (requestDto.getNewMpin() == null || !requestDto.getNewMpin().matches("\\d{4}")) {
            throw new RuntimeException("MPIN must be exactly 4 digits");
        }

        user.setMpin(passwordEncoder.encode(requestDto.getNewMpin()));
        pyUserRepository.save(user);
        logger.info("MPIN reset successful | userId={}", user.getId());
        return "MPIN reset successfully. Please login with your new MPIN";
    }

    private static String maskPhoneNumber(String phoneNumber) {
        if (phoneNumber == null || phoneNumber.length() < 4) {
            return "****";
        }
        return "****" + phoneNumber.substring(phoneNumber.length() - 4);
    }

    @Override
    @Transactional
    public PyRoleUpgradeResponseDto raiseAdminRequest(Long pyId, PyRoleUpgradeRequestDto requestDto) {
        logger.info("Raise request | pyId={}, requestType={}, planMonths={}",
                pyId, requestDto.getRequestType(), requestDto.getPlanMonths());

        // 1. Find user
        PyUser user = pyUserRepository.findById(pyId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // 2. Parse requestType — default ADMIN if not provided
        PyRoleUpgradeRequest.RequestType requestType = PyRoleUpgradeRequest.RequestType.ADMIN;
        if (requestDto.getRequestType() != null && !requestDto.getRequestType().isBlank()) {
            try {
                requestType = PyRoleUpgradeRequest.RequestType.valueOf(
                        requestDto.getRequestType().toUpperCase());
            } catch (IllegalArgumentException e) {
                throw new RuntimeException("Invalid requestType. Must be ADMIN, CLIENT or GROUP");
            }
        }

        // 3. Validate planMonths — any positive number allowed
        if (requestDto.getPlanMonths() == null || requestDto.getPlanMonths() <= 0) {
            throw new RuntimeException("Plan months must be a positive number");
        }

        if (requestDto.getAmount() == null || requestDto.getAmount() <= 0) {
            throw new RuntimeException("Amount must be a positive number");
        }

        if (requestDto.getNoOfClients() == null || requestDto.getNoOfClients() <= 0) {
            throw new RuntimeException("No of clients must be a positive number");
        }

        // 4. Check if user already has a pending request of same type
        boolean hasPendingRequest = pyRoleUpgradeRequestRepository
                .existsByPyUserAndStatusAndRequestType(
                        user, PyRoleUpgradeRequest.Status.PENDING, requestType);
        if (hasPendingRequest) {
            throw new RuntimeException("You already have a pending "
                    + requestType.name() + " request. Please wait for review");
        }

        // 5. For ADMIN type — check if user is already ADMIN or SUPER_ADMIN
        if (requestType == PyRoleUpgradeRequest.RequestType.ADMIN) {
            if (user.getRole() != PyUser.Role.USER) {
                throw new RuntimeException("You are already an " + user.getRole().name());
            }
        }

        // 6. Create new request
        PyRoleUpgradeRequest entity = new PyRoleUpgradeRequest();
        entity.setPyUser(user);
        entity.setRequestType(requestType);
        entity.setPlanMonths(requestDto.getPlanMonths());
        entity.setAmount(requestDto.getAmount());
        entity.setNoOfClients(requestDto.getNoOfClients());
        entity.setRequestedRole(
                requestType == PyRoleUpgradeRequest.RequestType.CLIENT ? "USER" : "ADMIN");
        entity.setStatus(PyRoleUpgradeRequest.Status.PENDING);
        entity.setReason(requestDto.getReason());

        PyRoleUpgradeRequest savedRequest = pyRoleUpgradeRequestRepository.save(entity);
        logger.info("Request saved | requestId={}, pyId={}, requestType={}, planMonths={}",
                savedRequest.getId(), pyId, requestType, requestDto.getPlanMonths());

        return mapToResponseDto(savedRequest);
    }

    // ── GET ALL PENDING REQUESTS ─────────────────────────────────────────────
    @Override
    public List<PyRoleUpgradeResponseDto> getPendingRequests() {

        List<PyRoleUpgradeRequest> pendingRequests = pyRoleUpgradeRequestRepository
                .findByStatus(PyRoleUpgradeRequest.Status.PENDING);

        return pendingRequests.stream()
                .map(this::mapToResponseDto)
                .collect(Collectors.toList());
    }

    // ── REVIEW REQUEST (APPROVE / REJECT) ────────────────────────────────────
    @Override
    @Transactional
    public PyRoleUpgradeResponseDto reviewRequest(Long superAdminPyId, PyReviewRequestDto requestDto) {
        logger.info("Review request | superAdminPyId={}, requestId={}, status={}",
                superAdminPyId, requestDto.getRequestId(), requestDto.getStatus());

        // 1. Find Super Admin
        PyUser superAdmin = pyUserRepository.findById(superAdminPyId)
                .orElseThrow(() -> new RuntimeException("Super Admin not found"));

        // 2. Check if reviewer is actually SUPER ADMIN
        if (superAdmin.getRole() != PyUser.Role.SUPER_ADMIN) {
            throw new RuntimeException("Only Super Admin can review requests");
        }

        // 3. Find the upgrade request
        PyRoleUpgradeRequest upgradeRequest = pyRoleUpgradeRequestRepository
                .findById(requestDto.getRequestId())
                .orElseThrow(() -> new RuntimeException("Request not found"));

        // 4. Check if request is still pending
        if (upgradeRequest.getStatus() != PyRoleUpgradeRequest.Status.PENDING) {
            throw new RuntimeException("This request has already been " + upgradeRequest.getStatus().name());
        }

        // 5. Validate status input
        if (!requestDto.getStatus().equalsIgnoreCase("APPROVED")
                && !requestDto.getStatus().equalsIgnoreCase("REJECTED")) {
            throw new RuntimeException("Status must be APPROVED or REJECTED");
        }

        // 6. If REJECTED reason is mandatory
        if (requestDto.getStatus().equalsIgnoreCase("REJECTED")
                && (requestDto.getReason() == null || requestDto.getReason().isBlank())) {
            throw new RuntimeException("Reason is required when rejecting a request");
        }

        // 7. Update request status
        // In existing reviewRequest() — replace the APPROVED block with:
        if (requestDto.getStatus().equalsIgnoreCase("APPROVED")) {
            upgradeRequest.setStatus(PyRoleUpgradeRequest.Status.APPROVED);

            PyUser user = upgradeRequest.getPyUser();

            // Save to PySubscription table
            PySubscription subscription = new PySubscription();
            subscription.setPyUser(user);
            subscription.setType(PySubscription.Type.valueOf(
                    upgradeRequest.getRequestType().name())); // CLIENT, GROUP or ADMIN
            subscription.setPlanMonths(upgradeRequest.getPlanMonths());
            subscription.setAmount(upgradeRequest.getAmount());

            subscription.setNoOfClients(upgradeRequest.getNoOfClients());

            subscription.setStartDate(LocalDateTime.now());
            subscription.setEndDate(LocalDateTime.now()
                    .plusMonths(upgradeRequest.getPlanMonths()));
            subscription.setStatus(PySubscription.Status.ACTIVE);
            subscription.setIsTrial(false);
            pySubscriptionRepository.save(subscription);

            // Upgrade role for ADMIN or GROUP type
            if (upgradeRequest.getRequestType() == PyRoleUpgradeRequest.RequestType.ADMIN
                    || upgradeRequest.getRequestType() == PyRoleUpgradeRequest.RequestType.GROUP) {
                user.setRole(PyUser.Role.ADMIN);
                pyUserRepository.save(user);
            }

        } else {
            upgradeRequest.setStatus(PyRoleUpgradeRequest.Status.REJECTED);
            upgradeRequest.setReason(requestDto.getReason());
        }
        // 9. Update reviewed by and reviewed at
        upgradeRequest.setReviewedBy(superAdmin);
        upgradeRequest.setReviewedAt(LocalDateTime.now());

        PyRoleUpgradeRequest updatedRequest = pyRoleUpgradeRequestRepository.save(upgradeRequest);

        return mapToResponseDto(updatedRequest);
    }

    // ── HELPER: Map Entity to Response DTO ──────────────────────────────────
    private PyRoleUpgradeResponseDto mapToResponseDto(PyRoleUpgradeRequest request) {

        PyRoleUpgradeResponseDto dto = new PyRoleUpgradeResponseDto();
        dto.setRequestId(request.getId());
        dto.setPyId(request.getPyUser().getId());
        dto.setAmount(request.getAmount());
        dto.setNoOfClients(request.getNoOfClients());
        dto.setFullName(request.getPyUser().getFullName());
        dto.setPhoneNumber(request.getPyUser().getPhoneNumber());
        dto.setEmail(request.getPyUser().getEmail());
        dto.setRequestedRole(request.getRequestedRole());
        dto.setStatus(request.getStatus().name());
        dto.setReason(request.getReason());
        dto.setCreatedAt(request.getCreatedAt());

        if (request.getReviewedBy() != null) {
            dto.setReviewedById(request.getReviewedBy().getId());
            dto.setReviewedByName(request.getReviewedBy().getFullName());
            dto.setReviewedAt(request.getReviewedAt());
        }
        dto.setPlanMonths(request.getPlanMonths());
        dto.setRequestType(request.getRequestType() != null
                ? request.getRequestType().name()
                : null);
        return dto;
    }
    // ── GET MY REQUESTS ──────────────────────────────────────────────────────

    @Override
    public List<PyRoleUpgradeResponseDto> getMyRequests(Long pyId, PyRoleUpgradeRequest.RequestType requestType) {
        PyUser user = pyUserRepository.findById(pyId).orElseThrow(() -> new RuntimeException("User not found: " + pyId));

        List<PyRoleUpgradeRequest> requests;

        if (requestType != null) {
            // Filter by CLIENT or GROUP
            requests = pyRoleUpgradeRequestRepository.findByPyUserAndRequestTypeOrderByCreatedAtDesc(user, requestType);
        } else {
            // No filter — return all requests for this user
            requests = pyRoleUpgradeRequestRepository.findTopByPyUserOrderByCreatedAtDesc(user);
        }

        return requests.stream()
                .map(this::mapToResponseDto)
                .collect(Collectors.toList());
    }

    @Override
    public List<PyUserResponseDto> getUsersByRole(String role) {
        PyUser.Role userRole;
        try {
            userRole = PyUser.Role.valueOf(role.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new RuntimeException("Invalid role. Must be SUPER_ADMIN, ADMIN or USER");
        }

        List<PyUser> users = pyUserRepository.findByRoleAndIsActive(userRole, true);

        return users.stream()
                .map(user -> {
                    PyUserResponseDto dto = mapToUserResponseDto(user);
                    dto.setAccountsCount(pyBrokerAccountRepository.countByPyUser(user));
                    dto.setActiveAccounts(pyBrokerAccountRepository.countByPyUserAndActiveTrue(user));
                    return dto;
                })
                .collect(Collectors.toList());
    }

    private PyUserResponseDto mapToUserResponseDto(PyUser user) {
        PyUserResponseDto dto = new PyUserResponseDto();
        dto.setPyId(user.getId());
        dto.setFullName(user.getFullName());
        dto.setEmail(user.getEmail());
        dto.setPhoneNumber(user.getPhoneNumber());
        dto.setRole(user.getRole().name());
        dto.setIsActive(user.getIsActive());
        dto.setCreatedAt(user.getCreatedAt());
        return dto;
    }
    // ── GET ALL REQUESTS WITH SUMMARY ────────────────────────────────────────

    @Override
    public PyRoleUpgradeRequestSummaryDto getAllRequests(String requestType) {

        // Parse requestType filter if provided
        PyRoleUpgradeRequest.RequestType type = null;
        if (requestType != null && !requestType.isBlank()) {
            try {
                type = PyRoleUpgradeRequest.RequestType.valueOf(requestType.toUpperCase());
            } catch (IllegalArgumentException e) {
                throw new RuntimeException("Invalid requestType. Must be ADMIN or CLIENT");
            }
        }

        List<PyRoleUpgradeRequest> pendingList;
        List<PyRoleUpgradeRequest> approvedList;
        List<PyRoleUpgradeRequest> rejectedList;

        if (type != null) {
            // Filter by requestType
            pendingList = pyRoleUpgradeRequestRepository
                    .findByStatusAndRequestType(PyRoleUpgradeRequest.Status.PENDING, type);
            approvedList = pyRoleUpgradeRequestRepository
                    .findByStatusAndRequestType(PyRoleUpgradeRequest.Status.APPROVED, type);
            rejectedList = pyRoleUpgradeRequestRepository
                    .findByStatusAndRequestType(PyRoleUpgradeRequest.Status.REJECTED, type);
        } else {
            // No filter — fetch all
            pendingList = pyRoleUpgradeRequestRepository
                    .findByStatus(PyRoleUpgradeRequest.Status.PENDING);
            approvedList = pyRoleUpgradeRequestRepository
                    .findByStatus(PyRoleUpgradeRequest.Status.APPROVED);
            rejectedList = pyRoleUpgradeRequestRepository
                    .findByStatus(PyRoleUpgradeRequest.Status.REJECTED);
        }

        PyRoleUpgradeRequestSummaryDto summary = new PyRoleUpgradeRequestSummaryDto();
        summary.setPendingCount(pendingList.size());
        summary.setApprovedCount(approvedList.size());
        summary.setRejectedCount(rejectedList.size());
        summary.setTotalCount(pendingList.size() + approvedList.size() + rejectedList.size());
        summary.setPending(pendingList.stream().map(this::mapToResponseDto).collect(Collectors.toList()));
        summary.setApproved(approvedList.stream().map(this::mapToResponseDto).collect(Collectors.toList()));
        summary.setRejected(rejectedList.stream().map(this::mapToResponseDto).collect(Collectors.toList()));

        return summary;
    }

    // ── DEMOTE ADMIN TO USER ──────────────────────────────────────────────────
    @Override
    @Transactional(noRollbackFor = { RuntimeException.class, Exception.class })
    public ApiResponse<PyRoleChangeResponseDto> demoteAdminToUser(
            PyRoleChangeRequestDto requestDto) {
        try {
            // 1. Validate Super Admin
            PyUser superAdmin = pyUserRepository.findById(requestDto.getSuperAdminPyId())
                    .orElseThrow(() -> new RuntimeException("Super Admin not found with pyId: "
                                    + requestDto.getSuperAdminPyId()));
            if (superAdmin.getRole() != PyUser.Role.SUPER_ADMIN) {
                return ApiResponse.error(403, "Only SUPER_ADMIN can demote admins");
            }

            // 2. Fetch target admin
            PyUser targetUser = pyUserRepository.findById(requestDto.getTargetPyId())
                    .orElseThrow(() -> new RuntimeException("User not found with pyId: " + requestDto.getTargetPyId()));

            // 3. Check target is ADMIN
            if (targetUser.getRole() != PyUser.Role.ADMIN) {
                return ApiResponse.error(400,targetUser.getFullName() + " is not an ADMIN");
            }

            // 4. Count groups before demoting
            long groupCount = pyTradeGroupRepository.countByCreatedBy(targetUser);

            // 5. Soft delete all groups — flushAutomatically + clearAutomatically
            // prevents persistence context conflict with subsequent saves
            pyTradeGroupRepository.deactivateAllGroupsByUser(targetUser);

            pyBrokerAccountRepository.deactivateAllGroupsByUser(targetUser);

            // 6. Change role to USER
            targetUser.setRole(PyUser.Role.USER);
            pyUserRepository.save(targetUser);

            // 7. Save role upgrade audit as REVOKED
            PyRoleUpgradeRequest request = new PyRoleUpgradeRequest();
            request.setPyUser(targetUser);
            request.setRequestedRole("ADMIN");
            request.setStatus(PyRoleUpgradeRequest.Status.REVOKED);
            request.setReason("Subscription Ended");
            pyRoleUpgradeRequestRepository.save(request);

            logger.info("Admin demoted to User — pyId={} name={} groupsDeactivated={}",
                    targetUser.getId(), targetUser.getFullName(), groupCount);

            // 8. Build response
            PyRoleChangeResponseDto response = new PyRoleChangeResponseDto();
            response.setPyId(targetUser.getId());
            response.setFullName(targetUser.getFullName());
            response.setPreviousRole("ADMIN");
            response.setNewRole("USER");
            response.setGroupsAffected(groupCount);
            response.setMessage(targetUser.getFullName()
                    + " has been demoted to USER. " + groupCount + " group(s) have been deactivated.");

            return ApiResponse.success("Admin demoted successfully", response);

        } catch (RuntimeException e) {
            logger.error("Demote admin failed: {}", e.getMessage(), e);
            return ApiResponse.error(500, "Demote failed: " + e.getMessage());
        }
    }
    // ── PROMOTE USER TO ADMIN ─────────────────────────────────────────────────

    @Override
    @Transactional
    public ApiResponse<PyRoleChangeResponseDto> promoteUserToAdmin(
            PyRoleChangeRequestDto requestDto) {
        try {
            // 1. Validate Super Admin
            PyUser superAdmin = pyUserRepository.findById(requestDto.getSuperAdminPyId())
                    .orElseThrow(() -> new RuntimeException(
                            "Super Admin not found with pyId: "
                                    + requestDto.getSuperAdminPyId()));

            if (superAdmin.getRole() != PyUser.Role.SUPER_ADMIN) {
                return ApiResponse.error(403,
                        "Only SUPER_ADMIN can promote users");
            }

            // 2. Fetch target user
            PyUser targetUser = pyUserRepository.findById(requestDto.getTargetPyId())
                    .orElseThrow(() -> new RuntimeException(
                            "User not found with pyId: "
                                    + requestDto.getTargetPyId()));

            // 3. Check target is USER
            if (targetUser.getRole() != PyUser.Role.USER) {
                return ApiResponse.error(400,
                        targetUser.getFullName() + " is not a USER");
            }

            // 4. Change role to ADMIN
            targetUser.setRole(PyUser.Role.ADMIN);
            pyUserRepository.save(targetUser);

            // 5. Restore all previous groups of this user
            pyTradeGroupRepository.restoreAllGroupsByUser(targetUser);

            // 6. Count restored groups
            long groupCount = pyTradeGroupRepository.countByCreatedBy(targetUser);

            logger.info("User promoted to Admin — pyId={} name={} groupsRestored={}",
                    targetUser.getId(), targetUser.getFullName(), groupCount);

            // 7. Build response
            PyRoleChangeResponseDto response = new PyRoleChangeResponseDto();
            response.setPyId(targetUser.getId());
            response.setFullName(targetUser.getFullName());
            response.setPreviousRole("USER");
            response.setNewRole("ADMIN");
            response.setGroupsAffected(groupCount);
            response.setMessage(targetUser.getFullName()
                    + " has been promoted to ADMIN. "
                    + groupCount + " previous group(s) have been restored.");

            return ApiResponse.success("User promoted successfully", response);

        } catch (RuntimeException e) {
            logger.error("Promote user failed: {}", e.getMessage(), e);
            return ApiResponse.error(500, "Promote failed: " + e.getMessage());
        }
    }
}
