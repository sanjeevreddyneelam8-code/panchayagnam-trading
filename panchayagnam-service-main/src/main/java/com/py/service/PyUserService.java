package com.py.service;

import com.py.common.dto.ApiResponse;
import com.py.dto.PyLoginRequestDto;
import com.py.dto.PyLoginResponseDto;
import com.py.dto.PyUserRegisterRequestDto;
import com.py.dto.PyUserRegisterResponseDto;
import com.py.dto.PyResetMpinRequestDto;
import com.py.dto.PyReviewRequestDto;
import com.py.dto.PyRoleUpgradeRequestDto;
import com.py.dto.PyRoleUpgradeResponseDto;
import com.py.dto.OtpRequestDto;
import com.py.dto.*;
import com.py.entity.PyRoleUpgradeRequest;
import java.util.List;

public interface PyUserService {

    PyUserRegisterResponseDto registerUser(PyUserRegisterRequestDto requestDto);

    PyLoginResponseDto loginUser(PyLoginRequestDto requestDto);

    PyLoginResponseDto loginWithOtp(PyOtpLoginRequestDto requestDto);

    String resetMpin(PyResetMpinRequestDto requestDto);

    /**
     * Send OTP to user's phone number for registration
     *
     * @param requestDto OTP request containing phone number
     * @return Success/failure message
     */
    String sendVerificationCode(OtpRequestDto requestDto);

    /**
     * Verify OTP for user registration This is called before registration to
     * validate the OTP
     *
     * @param phoneNumber User's phone number
     * @param otp OTP to verify
     * @return true if OTP is valid, false otherwise
     */
    boolean verifyOtp(String phoneNumber, String otp);

    PyRoleUpgradeResponseDto raiseAdminRequest(Long pyId, PyRoleUpgradeRequestDto requestDto);

    List<PyRoleUpgradeResponseDto> getPendingRequests();

    PyRoleUpgradeResponseDto reviewRequest(Long superAdminPyId, PyReviewRequestDto requestDto);

    List<PyRoleUpgradeResponseDto> getMyRequests(Long pyId,PyRoleUpgradeRequest.RequestType requestType);

    List<PyUserResponseDto> getUsersByRole(String role);

    // Replace old getPendingRequests with new getAllRequests
    PyRoleUpgradeRequestSummaryDto getAllRequests(String requestType);

    ApiResponse<PyRoleChangeResponseDto> demoteAdminToUser(PyRoleChangeRequestDto requestDto);

    ApiResponse<PyRoleChangeResponseDto> promoteUserToAdmin(PyRoleChangeRequestDto requestDto);

}
