package com.py.demataccount.service.impl;

import com.py.brokers.angel.exception.SmartAPIException;
import com.py.common.dto.ApiResponse;
import com.py.brokers.angel.dto.User;
import com.py.common.enums.BrokerType;
import com.py.demataccount.dto.DematAccountAddRequest;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.ipconfig.entity.PyBrokerIpConfigEntity;
import com.py.demataccount.entity.PyBrokerSecret;
import com.py.demataccount.entity.PyBrokerToken;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.demataccount.repository.PyTradeGroupMemberRepository;
import com.py.entity.PyTradeGroupMemberEntity;
import com.py.trading.entity.PaperPositionEntity;
import com.py.trading.repository.PaperAccountBalanceRepository;
import com.py.trading.repository.PaperPositionRepository;
import com.py.ipconfig.repository.PyBrokerIpConfigRepository;
import com.py.ipconfig.service.PyBrokerIpConfigService;
import com.py.demataccount.utils.BrokerProfileLoader;
import com.py.demataccount.utils.BrokerTokenSecretManager;
import com.py.entity.PyUser;
import org.apache.commons.lang3.StringUtils;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
public class BrokerAccountOperationService {

    private static final Logger log = LoggerFactory.getLogger(BrokerAccountOperationService.class);

    @Autowired
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @Autowired
    private PyBrokerIpConfigRepository pyBrokerIpConfigRepository;

    @Autowired
    private BrokerLoginService brokerLoginService;

    @Autowired
    private BrokerTokenSecretManager tokenSecretManager;

    @Autowired
    private BrokerProfileLoader profileLoader;

    @Autowired
    private PyBrokerIpConfigService accountValidator;

    @Autowired(required = false)
    private PyTradeGroupMemberRepository pyTradeGroupMemberRepository;

    @Autowired(required = false)
    private PaperAccountBalanceRepository paperAccountBalanceRepository;

    @Autowired(required = false)
    private PaperPositionRepository paperPositionRepository;

    // ── ADD ───────────────────────────────────────────────────────────────────
    public ApiResponse<?> addAccount(DematAccountAddRequest request, PyUser pyUser)
            throws SmartAPIException, IOException {
        log.info("Adding broker account | clientId={}, broker={}",
                request.getClientId(), request.getBrokerType());

        // ── Duplicate check ───────────────────────────────────────────────────
        Optional<PyBrokerAccountEntity> existing
                = pyBrokerAccountRepository.findByClientId(request.getClientId());
        if (existing.isPresent()) {
            return ApiResponse.error(409,
                    "Broker account already exists for clientId: " + request.getClientId()
                    + ". Please use UPDATE to modify credentials.");
        }

        // ── IP validation ─────────────────────────────────────────────────────
        ApiResponse<PyBrokerIpConfigEntity> ipValidation
                = accountValidator.validateIpForAccount(request.getIp(), request.getBrokerType());
        if (!"SUCCESS".equals(ipValidation.getStatus())) {
            return ipValidation;
        }

        // ── Login BEFORE any DB write — invalid credentials are caught here ───
        JSONObject loginData = null;
        String initialLoginError = null;
        try {
            if (!request.getBrokerType().equals(BrokerType.PROFITMART)) {
                loginData = brokerLoginService.login(request);
            }
        } catch (RuntimeException e) {
            log.warn("Initial broker login could not establish session for clientId={}: {}. Saving account as DISCONNECTED.",
                    request.getClientId(), e.getMessage());
            initialLoginError = e.getMessage();
        }

        // ── Persist new account ───────────────────────────────────────────────
        return persistNewAccount(request, pyUser, loginData, ipValidation.getData(), initialLoginError);
    }

    // ── UPDATE ────────────────────────────────────────────────────────────────
    public ApiResponse<?> updateAccount(DematAccountAddRequest request)
            throws SmartAPIException, IOException {
        log.info("Updating broker account | clientId={}", request.getClientId());

        Optional<PyBrokerAccountEntity> accountOpt
                = pyBrokerAccountRepository.findByClientId(request.getClientId());
        if (accountOpt.isEmpty()) {
            return ApiResponse.error(404,
                    "Broker account not found for clientId: " + request.getClientId());
        }

        PyBrokerAccountEntity account = accountOpt.get();
        // ── IP validation when IP is being changed ────────────────────────────
        if (!account.getActive() && request.isActive() && StringUtils.isNotEmpty(request.getIp())) {
            ApiResponse<PyBrokerIpConfigEntity> ipValidation = accountValidator.validateIpForAccount(request.getIp(), request.getBrokerType());
            if (!"SUCCESS".equals(ipValidation.getStatus())) {
                return ipValidation;
            }
            PyBrokerIpConfigEntity ipConfig = ipValidation.getData();
            account.setBrokerRegisteredIp(ipConfig.getIpAddress() + ":" + (ipConfig.getPortNo() != null ? ipConfig.getPortNo() : 8082));
        } else if (!request.isActive()) {
            account.setBrokerRegisteredIp(null);
            account.setActive(false);
            pyBrokerAccountRepository.save(account);
            return ApiResponse.success("Account deactivated successfully", account);
        }
        // ── Login BEFORE any further DB write ─────────────────────────────────
        JSONObject loginData = null;
        try {
            if (!request.getBrokerType().equals(BrokerType.PROFITMART)) {
                loginData = brokerLoginService.login(request);
            }
        } catch (RuntimeException e) {
            log.error("Broker login failed on update for clientId={}: {}",
                    request.getClientId(), e.getMessage());
            account.setLastLoginStatus("FAILED");
            account.setLastLoginError(e.getMessage());
            account.setLastLoginAttempt(LocalDateTime.now());
            pyBrokerAccountRepository.save(account);
            return ApiResponse.error(401,
                    "Login failed for " + request.getBrokerType()
                    + " [" + request.getClientId() + "]: " + e.getMessage());
        }

        // ── Persist only after login is confirmed valid ────────────────────────
        return persistUpdate(account, request, loginData);
    }

    // ── DEACTIVATE ────────────────────────────────────────────────────────────
    @Transactional
    public ApiResponse<?> deActivateAccount(String clientId) {
        log.info("Deactivating broker account | clientId={}", clientId);

        Optional<PyBrokerAccountEntity> accountOpt
                = pyBrokerAccountRepository.findByClientId(clientId);
        if (accountOpt.isEmpty()) {
            return ApiResponse.error(404,
                    "Broker account not found for clientId: " + clientId);
        }

        PyBrokerAccountEntity account = accountOpt.get();
        account.setActive(false);
        account.setBrokerRegisteredIp(null);
        pyBrokerAccountRepository.save(account);

        log.info("Broker account deactivated | clientId={}", clientId);
        return ApiResponse.success("Account deactivated successfully", null);
    }

    // ── DELETE / REMOVE ACCOUNT ──────────────────────────────────────────────
    @Transactional
    public ApiResponse<?> deleteAccount(String clientId, Long pyUserId) {
        log.info("Deleting broker account | clientId={}, pyUserId={}", clientId, pyUserId);

        Optional<PyBrokerAccountEntity> accountOpt
                = pyBrokerAccountRepository.findByClientId(clientId);
        if (accountOpt.isEmpty()) {
            return ApiResponse.error(404,
                    "Broker account not found for clientId: " + clientId);
        }

        PyBrokerAccountEntity account = accountOpt.get();
        if (pyUserId != null && account.getPyUser() != null && !account.getPyUser().getId().equals(pyUserId)) {
            log.warn("Security rejection: pyUserId={} attempted to delete account {} owned by pyUserId={}",
                    pyUserId, clientId, account.getPyUser().getId());
            return ApiResponse.error(403, "Unauthorized: You do not own this broker account");
        }

        // 1. Clean up trade group memberships if any
        if (pyTradeGroupMemberRepository != null) {
            List<PyTradeGroupMemberEntity> groupMembers = pyTradeGroupMemberRepository.findByBrokerAccount(account);
            if (groupMembers != null && !groupMembers.isEmpty()) {
                pyTradeGroupMemberRepository.deleteAll(groupMembers);
                log.info("Removed {} trade group membership(s) for clientId={}", groupMembers.size(), clientId);
            }
        }

        // 2. Clean up paper positions if any
        if (paperPositionRepository != null) {
            List<PaperPositionEntity> positions = paperPositionRepository.findByDematAccountId(account.getId());
            if (positions != null && !positions.isEmpty()) {
                paperPositionRepository.deleteAll(positions);
                log.info("Removed {} paper position(s) for clientId={}", positions.size(), clientId);
            }
        }

        // 3. Clean up paper balance if any
        if (paperAccountBalanceRepository != null && account.getPyUser() != null) {
            paperAccountBalanceRepository.findByPyUserIdAndDematAccountId(account.getPyUser().getId(), account.getId())
                    .ifPresent(b -> {
                        paperAccountBalanceRepository.delete(b);
                        log.info("Removed paper balance for clientId={}", clientId);
                    });
        }

        // 4. Delete the account entity — cascades and removes PyBrokerSecret and PyBrokerToken
        pyBrokerAccountRepository.delete(account);
        log.info("Broker account successfully deleted | clientId={}", clientId);

        return ApiResponse.success("Broker account deleted successfully", null);
    }

    // ── PERSIST NEW ────────────────────────────────────────────────────────────
    @Transactional
    private ApiResponse<?> persistNewAccount(DematAccountAddRequest request,
            PyUser pyUser, JSONObject loginData, PyBrokerIpConfigEntity ipConfig, String initialLoginError)
            throws SmartAPIException, IOException {
        try {
            PyBrokerAccountEntity account = new PyBrokerAccountEntity();
            account.setBrokerRegisteredIp(
                    ipConfig.getIpAddress() + ":" + ipConfig.getPortNo());
            account.setPyUser(pyUser);
            account.setClientId(request.getClientId());
            account.setBrokerType(request.getBrokerType());
            account.setActive(true);

            // Require an official non-empty access token to mark status as SUCCESS / Connected
            boolean hasToken = hasValidAccessToken(loginData, request.getBrokerType());
            if (hasToken) {
                account.setLastLoginStatus("SUCCESS");
                account.setLastLoginError(null);
            } else {
                account.setLastLoginStatus(initialLoginError != null ? "FAILED" : "DISCONNECTED");
                account.setLastLoginError(initialLoginError != null ? initialLoginError : "Credentials saved. Connect account to establish active " + request.getBrokerType() + " session.");
            }
            account.setLastLoginAttempt(LocalDateTime.now());

            PyBrokerSecret secret = tokenSecretManager.createSecret(request);
            secret.setBrokerAccount(account);
            account.setSecret(secret);

            PyBrokerToken token = tokenSecretManager.createToken(loginData, request.getBrokerType());
            token.setBrokerAccount(account);
            account.setToken(token);

            User user = profileLoader.buildUserProfile(
                    request.getBrokerType(), request, loginData, secret);
            account.setUserName(profileLoader.getEffectiveUserName(request, user));
            account.setIsOwn(request.isOwn());

            pyBrokerAccountRepository.save(account);

            log.info("New broker account saved | clientId={}, broker={}",
                    request.getClientId(), request.getBrokerType());
            if (hasToken) {
                return ApiResponse.success("Broker account added and authenticated successfully", user);
            } else {
                return ApiResponse.success("Broker account credentials saved. Please click 'Connect' on the dashboard to authenticate with " + request.getBrokerType() + ".", user);
            }

        } catch (Exception e) {
            log.error("Failed to persist broker account | clientId={}: {}",
                    request.getClientId(), e.getMessage(), e);
            throw e;
        }
    }

    // ── PERSIST UPDATE (called only after login succeeds) ─────────────────────
    @Transactional
    private ApiResponse<?> persistUpdate(PyBrokerAccountEntity account,
            DematAccountAddRequest request, JSONObject loginData)
            throws SmartAPIException, IOException {
        try {
            log.info("Persisting update | clientId={}", request.getClientId());

            PyBrokerSecret secret = account.getSecret();
            tokenSecretManager.updateSecret(secret, request);

            PyBrokerToken token = account.getToken();
            tokenSecretManager.updateToken(token, loginData, request.getBrokerType());

            account.setBrokerType(request.getBrokerType());
            account.setClientId(request.getClientId());
            account.setActive(request.isActive());

            // Check if updated credentials or existing session has a valid official token
            boolean hasToken = hasValidAccessToken(loginData, request.getBrokerType())
                    || (account.getToken() != null && StringUtils.isNotEmpty(account.getToken().getAccessToken()));
            if (hasToken) {
                account.setLastLoginStatus("SUCCESS");
                account.setLastLoginError(null);
            } else {
                account.setLastLoginStatus("DISCONNECTED");
                account.setLastLoginError("Credentials updated. Connect account to establish active " + request.getBrokerType() + " session.");
            }
            account.setLastLoginAttempt(LocalDateTime.now());
            account.setIsOwn(request.isOwn());
            // Build user profile for response
            User user = profileLoader.buildUserProfile(request.getBrokerType(), request, loginData, secret);
            // Update username if provided

            if (StringUtils.isNotEmpty(request.getNickName())) {
                account.setUserName(request.getNickName());
            } else {
                account.setUserName(user.userName);
            }
            pyBrokerAccountRepository.save(account);

            log.info("Broker account updated | clientId={}", request.getClientId());
            if (request.getBrokerType().equals(BrokerType.PROFITMART)) {
                return ApiResponse.success("Broker account details updated successfully,Please Connect Account", user);
            }
            return ApiResponse.success("Broker account updated successfully", user);

        } catch (RuntimeException e) {
            log.error("Failed to persist update | clientId={}: {}",
                    request.getClientId(), e.getMessage(), e);
            throw e;
        }
    }

    private boolean hasValidAccessToken(JSONObject loginData, BrokerType brokerType) {
        if (loginData == null) {
            return false;
        }
        return switch (brokerType) {
            case ANGELONE -> loginData.optString("jwtToken", "").trim().length() > 0;
            case MOTILAL -> loginData.optString("AccessToken", "").trim().length() > 0;
            case DHAN, ZERODHA, UPSTOX, GOODWILL -> loginData.optString("accessToken", "").trim().length() > 0;
            case PROFITMART -> loginData.optString("susertoken", loginData.optString("access_token", "")).trim().length() > 0;
            case GROWW -> false;
        };
    }
}
