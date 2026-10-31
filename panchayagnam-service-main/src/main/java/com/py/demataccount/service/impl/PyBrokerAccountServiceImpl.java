package com.py.demataccount.service.impl;

import com.py.brokers.angel.exception.DeActivatedAccountException;
import com.py.common.dto.ApiResponse;
import com.py.common.enums.AccountActionType;
import com.py.common.enums.BrokerType;
import com.py.common.util.PyCommonUtil;
import com.py.common.util.TotpUtil;
import com.py.brokers.angel.client.Routes;
import com.py.brokers.angel.client.SmartConnect;
import com.py.brokers.angel.dto.AngelOneCancelOrderRequest;
import com.py.brokers.angel.dto.AngelOneConvertPositionRequest;
import com.py.brokers.angel.dto.AngelOneModifyOrderRequest;
import com.py.brokers.angel.dto.AngelOnePlaceOrderRequest;
import com.py.brokers.angel.dto.Order;
import com.py.brokers.angel.dto.OrderParams;
import com.py.brokers.angel.dto.User;
import com.py.brokers.angel.exception.SmartAPIException;
import com.py.brokers.angel.http.ApiRequestHandler;
import com.py.brokers.angel.dto.CancelOrderRequest;
import com.py.brokers.angel.dto.ModifyOrderRequest;
import com.py.brokers.dhan.DhanAccountService;
import com.py.brokers.dhan.dto.DhanCancelOrderRequest;
import com.py.brokers.dhan.dto.DhanModifyOrderRequest;
import com.py.brokers.dhan.dto.DhanOrderParams;
import com.py.brokers.dhan.dto.DhanPlaceOrderRequest;
import com.py.brokers.motilal.MotilalAccountService;
import com.py.brokers.motilal.dto.MotilalCancelOrderRequest;
import com.py.brokers.motilal.dto.MotilalConvertPositionRequest;
import com.py.brokers.motilal.dto.MotilalModifyOrderRequest;
import com.py.brokers.motilal.dto.MotilalPlaceOrderRequest;
import com.py.brokers.motilal.dto.MotilolOrderParams;
import com.py.brokers.upstox.service.UpstoxAuthService;
import com.py.common.dto.BrokerRmsDto;
import com.py.demataccount.dto.DematAccountAddRequest;
import com.py.demataccount.dto.DematAccountFetchResponse;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.ipconfig.entity.PyBrokerIpConfigEntity;
import com.py.demataccount.entity.PyBrokerSecret;
import com.py.demataccount.entity.PyBrokerToken;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.ipconfig.repository.PyBrokerIpConfigRepository;
import com.py.demataccount.service.PyBrokerAccountService;
import com.py.ipconfig.service.PyBrokerIpConfigService;
import com.py.dto.PyBrokerAccountSummaryDto;
import com.py.easytrade.dto.IndividualOrderRequest;
import com.py.easytrade.entity.IndividualOrderAuditEntity;
import com.py.easytrade.repository.IndividualOrderAuditRepository;
import com.py.entity.PyUser;
import com.py.repo.PyUserRepository;
import com.py.service.GrowwPriceService;
import com.py.tokensValidation.PyTokenValidationService;

import com.py.utils.AngelOneMicroserviceClient;
import com.py.utils.DhanMicroserviceClient;
import com.py.utils.MotilalMicroserviceClient;
import com.py.utils.ProfitmartMicroserviceClient;
import com.py.utils.ZerodhaMicroserviceClient;
import com.py.utils.UpstoxMicroserviceClient;
import com.py.utils.GoodwillMicroserviceClient;

import org.apache.commons.codec.digest.DigestUtils;
import org.apache.commons.lang3.StringUtils;
import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;

import static com.py.common.util.PyCommonUtil.getBaseUrl;
import com.py.dto.ConvertPositionRequest;
import static java.lang.Double.parseDouble;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.stream.Collectors;
import org.springframework.transaction.annotation.Propagation;

@Service
public class PyBrokerAccountServiceImpl implements PyBrokerAccountService {

    private static final Logger log = LoggerFactory.getLogger(PyBrokerAccountServiceImpl.class);

    private final Routes routes = new Routes();

    @Autowired
    private PyUserRepository pyUserRepository;

    @Autowired
    private DhanMicroserviceClient dhanClient;

    @Autowired
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @Autowired
    private TotpUtil totpUtil;

    @Autowired
    private MotilalAccountService motilalAccountService;

    @Autowired
    private ApiRequestHandler apiRequestHandler;

    @Autowired
    private ExecutorService rmsExecutor;

    @Autowired
    private IndividualOrderAuditRepository individualOrderAuditRepository;

    @Autowired
    private DhanAccountService dhanAccountService;

    @Autowired
    private PyTokenValidationService pyTokenValidationService;

    @Autowired
    private UpstoxAuthService upstoxAuthService;

    @Autowired
    private AngelOneMicroserviceClient angelOneClient;

    @Autowired
    private MotilalMicroserviceClient motilalClient;

    @Autowired
    private ProfitmartMicroserviceClient profitmartClient;

    @Autowired
    private ZerodhaMicroserviceClient zerodhaClient;

    @Autowired
    private UpstoxMicroserviceClient upstoxClient;

    @Autowired
    private GoodwillMicroserviceClient goodwillClient;

    @Autowired
    private PyBrokerIpConfigRepository pyBrokerIpConfigRepository;

    @Autowired
    private GrowwPriceService growwPriceService;

    @Autowired
    private BrokerAccountOperationService brokerAccountOperationService;

    @Autowired
    private PyBrokerIpConfigService pyBrokerIpConfigService;

    @Autowired
    private PyCommonUtil pyCommonUtil;

    @Autowired
    private com.py.trading.service.PaperTradingService paperTradingService;

    @Autowired
    private com.py.trading.service.PaperTradingEngine paperTradingEngine;

    @Autowired(required = false)
    private com.py.trading.repository.PaperAccountBalanceRepository paperBalanceRepository;

    // ── ADD / UPDATE / DELETE ────────────────────────────────────────────────
    @Override
    public ApiResponse<?> dematAccountOperations(DematAccountAddRequest request, AccountActionType actionType) throws SmartAPIException, IOException {
        try {
            if (actionType == AccountActionType.DELETE) {
                if (request == null || StringUtils.isBlank(request.getClientId())) {
                    return ApiResponse.error(400, "Client ID is required for deleting an account");
                }
            } else {
                ApiResponse<?> validationResult = pyCommonUtil.validateAccountRequest(request);
                if (!"SUCCESS".equals(validationResult.getStatus())) {
                    return validationResult;
                }
            }
            PyUser pyUser = pyUserRepository.findById(request.getPyUserId())
                    .orElseThrow(() -> new RuntimeException("User not found with pyId: " + request.getPyUserId()));

            return switch (actionType) {
                case ADD    -> brokerAccountOperationService.addAccount(request, pyUser);
                case UPDATE -> brokerAccountOperationService.updateAccount(request);
                case DELETE -> brokerAccountOperationService.deleteAccount(request.getClientId(), pyUser.getId());
                default     -> ApiResponse.error(400, "Invalid action type: " + actionType);
            };

        } catch (RuntimeException e) {
            log.error("Broker account operation failed for clientId={}: {}",
                    request.getClientId(), e.getMessage(), e);
            return ApiResponse.error(502, "Error: " + e.getMessage());
        }
    }

    // ── FETCH ALL ────────────────────────────────────────────────────────────
    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public ApiResponse<List<DematAccountFetchResponse>> fetchAllBrokerAccounts(boolean amountRequired) {
        try {
            List<PyBrokerAccountEntity> accounts = pyBrokerAccountRepository.findAllWithUser();
            List<DematAccountFetchResponse> result = fetchAccountsParallel(accounts, amountRequired);
            return ApiResponse.success("Fetched all broker accounts", result);
        } catch (Exception e) {
            log.error("Failed to fetch accounts: {}", e.getMessage(), e);
            return ApiResponse.error(500, "Failed to fetch accounts: " + e.getMessage());
        }
    }

    // ── FETCH BY PY_ID ───────────────────────────────────────────────────────
    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public ApiResponse<List<DematAccountFetchResponse>> fetchAccountsByPyId(
            Long pyId, boolean amountRequired) {
        try {
            Optional<PyUser> userOpt = pyUserRepository.findById(pyId);
            if (userOpt.isEmpty()) {
                return ApiResponse.error(404, "User not found: " + pyId);
            }
            if (userOpt.get().getRole().equals(PyUser.Role.SUPER_ADMIN)) {
                return fetchAllBrokerAccounts(amountRequired);
            }
            List<PyBrokerAccountEntity> accounts = pyBrokerAccountRepository.findByPyUserIdOrderByIsOwnDesc(pyId);
            List<DematAccountFetchResponse> result = accounts.stream()
                    .map(account -> mapToFetchResponse(account, amountRequired))
                    .collect(Collectors.toList());
            return ApiResponse.success("Fetched accounts for pyId: " + pyId, result);
        } catch (Exception e) {
            log.error("Failed to fetch accounts for pyId={}: {}", pyId, e.getMessage());
            return ApiResponse.error(500, "Failed to fetch accounts: " + e.getMessage());
        }
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public ApiResponse<List<DematAccountFetchResponse>> fetchAccountsByPyBrokerId(
            Long id, boolean amountRequired) {
        try {
            Optional<PyBrokerAccountEntity> userOpt = pyBrokerAccountRepository.findById(id);
            if (userOpt.isEmpty()) {
                return ApiResponse.error(404, "Broker Account not found: " + id);
            }
            DematAccountFetchResponse result = mapToFetchResponse(userOpt.get(), amountRequired);
            return ApiResponse.success("Fetched account for pyId: " + id, List.of(result));
        } catch (Exception e) {
            log.error("Failed to fetch account for pyBrokerId={}: {}", id, e.getMessage());
            return ApiResponse.error(500, "Failed to fetch account: " + e.getMessage());
        }
    }

    // ── PARALLEL FETCH ───────────────────────────────────────────────────────
    private List<DematAccountFetchResponse> fetchAccountsParallel(
            List<PyBrokerAccountEntity> accounts, boolean amountRequired) {

        List<CompletableFuture<DematAccountFetchResponse>> futures = accounts.stream()
                .map(account -> CompletableFuture.supplyAsync(
                        () -> mapToFetchResponse(account, amountRequired), rmsExecutor))
                .toList();

        CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();

        return futures.stream().map(CompletableFuture::join).toList();
    }

    // ── MAP ENTITY TO RESPONSE ───────────────────────────────────────────────
    private DematAccountFetchResponse mapToFetchResponse(
            PyBrokerAccountEntity account, boolean amountRequired) {

        DematAccountFetchResponse dto = new DematAccountFetchResponse();
        dto.setId(account.getId());
        dto.setClientId(account.getClientId());
        dto.setUserName(account.getUserName());
        dto.setBrokerType(account.getBrokerType());
        dto.setActive(account.getActive());
        dto.setCreatedDate(account.getCreatedAt());
        dto.setAssignedTo(account.getPyUser().getFullName());
        dto.setIsOwnAccount(account.getIsOwn());
        dto.setLastLoginStatus(account.getLastLoginStatus());
        dto.setLastLoginError(account.getLastLoginError());
        dto.setLastLoginAttempt(account.getLastLoginAttempt());
        dto.setIp((account.getBrokerRegisteredIp() != null
                && !account.getBrokerRegisteredIp().isEmpty())
                ? account.getBrokerRegisteredIp().split(":")[0] : "");

        if (account.getSecret() != null) {
            String rawApiKey = account.getSecret().getApiKey();
            if (rawApiKey != null && rawApiKey.length() > 4) {
                dto.setApiKey("****" + rawApiKey.substring(rawApiKey.length() - 4));
            } else if (rawApiKey != null && !rawApiKey.isEmpty()) {
                dto.setApiKey("****");
            } else {
                dto.setApiKey(null);
            }

            String rawMobile = account.getSecret().getMobileNo();
            if (rawMobile != null && rawMobile.length() > 4) {
                dto.setMobileNumber("******" + rawMobile.substring(rawMobile.length() - 4));
            } else {
                dto.setMobileNumber(rawMobile);
            }

            // Sensitive broker secrets are NEVER leaked in API responses
            dto.setMpin(null);
            dto.setTotpKey(null);
            dto.setPassword(null);
            dto.setDob(null);
            dto.setApiSecretKey(null);

            // Boolean indicators informing the UI whether credentials are configured
            dto.setHasPassword(StringUtils.isNotBlank(account.getSecret().getPassword()));
            dto.setHasMpin(StringUtils.isNotBlank(account.getSecret().getPassword()));
            dto.setHasTotpKey(StringUtils.isNotBlank(account.getSecret().getTotpSecret()));
            dto.setHasApiKey(StringUtils.isNotBlank(account.getSecret().getApiKey()));
            dto.setHasApiSecretKey(StringUtils.isNotBlank(account.getSecret().getApiSecret()));
        }

        if (amountRequired && StringUtils.isNotEmpty(account.getBrokerRegisteredIp())) {
            try {
                JSONObject rmsData = getRMS(account);
                BrokerRmsDto rms = mapToRmsDto(account.getBrokerType(), rmsData);
                dto.setRms(rms);
                dto.setAvailableCash(rms.getAvailableCash());
            } catch (Exception e) {
                log.warn("RMS failed for clientId={}: {}", account.getClientId(), e.getMessage());
                dto.setAvailableCash(0.0);
            }
        }

        return dto;
    }

    // ── RMS ──────────────────────────────────────────────────────────────────
    public JSONObject getRMS(PyBrokerAccountEntity account) {
        if (paperTradingService != null && paperTradingService.isPaperTradingEnabled()) {
            double balance = 1000000.0;
            try {
                if (paperBalanceRepository != null && account.getPyUser() != null) {
                    balance = paperBalanceRepository.findByPyUserIdAndDematAccountId(account.getPyUser().getId(), account.getId())
                            .map(b -> b.getVirtualCashBalance() != null ? b.getVirtualCashBalance() : 1000000.0)
                            .orElse(1000000.0);
                }
            } catch (Exception ex) {
                log.warn("Could not fetch paper balance from repo for account {}, defaulting to 1000000", account.getId());
            }
            JSONObject paperRms = new JSONObject();
            paperRms.put("availableCash", balance);
            paperRms.put("net", balance);
            paperRms.put("collateral", 0.0);
            paperRms.put("m2mUnrealized", 0.0);
            paperRms.put("m2mRealized", 0.0);
            return paperRms;
        }

        try {
            return switch (account.getBrokerType()) {
                case ANGELONE   -> getAngelOneRMS(account);
                case MOTILAL    -> getMotilalRMS(account);
                case DHAN       -> getDhanRMS(account);
                case PROFITMART -> getProfitmartRMS(account);
                case UPSTOX     -> getUpstoxRMS(account);
                case ZERODHA    -> getZerodhaRMS(account);
                case GOODWILL   -> getGoodwillRMS(account);
                default         -> new JSONObject();
            };
        } catch (Exception e) {
            log.error("RMS fetch failed for clientId={}: {}",
                    account.getClientId(), e.getMessage(), e);
            return new JSONObject();
        }
    }

    private JSONObject getUpstoxRMS(PyBrokerAccountEntity account) {
        try {
            String accessToken = pyTokenValidationService.getValidAccessToken(account.getId());
            if (accessToken == null) {
                log.error("Upstox RMS skipped — token unavailable for clientId={}", account.getClientId());
                return new JSONObject();
            }
            JSONObject result = upstoxClient.getFunds(
                    getBaseUrl(account),
                    account.getClientId(),
                    accessToken).get();
            return result != null ? result : new JSONObject();
        } catch (Exception e) {
            log.error("Upstox RMS failed for clientId={}: {}", account.getClientId(), e.getMessage());
            return new JSONObject();
        }
    }

    private JSONObject getZerodhaRMS(PyBrokerAccountEntity account) {
        try {
            String accessToken = pyTokenValidationService.getValidAccessToken(account.getId());
            if (accessToken == null) {
                log.error("Zerodha RMS skipped — token unavailable for clientId={}", account.getClientId());
                return new JSONObject();
            }
            String apiKey = account.getSecret() != null ? account.getSecret().getApiKey() : "";
            JSONObject result = zerodhaClient.getRms(
                    getBaseUrl(account),
                    account.getClientId(),
                    apiKey,
                    accessToken).get();
            return result != null ? result : new JSONObject();
        } catch (Exception e) {
            log.error("Zerodha RMS failed for clientId={}: {}", account.getClientId(), e.getMessage());
            return new JSONObject();
        }
    }

    private JSONObject getGoodwillRMS(PyBrokerAccountEntity account) {
        try {
            String accessToken = pyTokenValidationService.getValidAccessToken(account.getId());
            if (accessToken == null) {
                log.error("Goodwill RMS skipped — token unavailable for clientId={}", account.getClientId());
                return new JSONObject();
            }
            JSONObject result = goodwillClient.getLimits(
                    getBaseUrl(account),
                    account.getClientId(),
                    accessToken).get();
            return result != null ? result : new JSONObject();
        } catch (Exception e) {
            log.error("Goodwill RMS failed for clientId={}: {}", account.getClientId(), e.getMessage());
            return new JSONObject();
        }
    }

    private JSONObject getAngelOneRMS(PyBrokerAccountEntity account) {
        try {
            String accessToken = pyTokenValidationService.getValidAccessToken(account.getId());
            if (accessToken == null) {
                log.error("AngelOne RMS skipped — token unavailable for clientId={}", account.getClientId());
                return new JSONObject();
            }
            return angelOneClient.getRMS(getBaseUrl(account),
                    account.getSecret().getApiKey(), accessToken).get();
        } catch (Exception e) {
            log.error("AngelOne RMS failed for clientId={}: {}", account.getClientId(), e.getMessage());
            return new JSONObject();
        }
    }

    private JSONObject getMotilalRMS(PyBrokerAccountEntity account) {
        try {
            String accessToken = pyTokenValidationService.getValidAccessToken(account.getId());
            if (accessToken == null) {
                log.error("Motilal RMS skipped — token unavailable for clientId={}", account.getClientId());
                return new JSONObject();
            }
            JSONObject json = motilalClient.getRMS(
                    getBaseUrl(account),
                    account.getSecret().getApiKey(),
                    account.getSecret().getApiSecret(),
                    account.getSecret().getVenderInfo(),
                    account.getToken().getRefreshToken(),
                    accessToken).get();

            if (json == null || !json.optString("status", "").equalsIgnoreCase("SUCCESS")) {
                log.warn("Motilal RMS failed for clientId={}", account.getClientId());
                return new JSONObject();
            }
            return json;
        } catch (Exception e) {
            log.error("Motilal RMS failed for clientId={}: {}", account.getClientId(), e.getMessage());
            return new JSONObject();
        }
    }

    private JSONObject getDhanRMS(PyBrokerAccountEntity account) {
        try {
            String accessToken = pyTokenValidationService.getValidAccessToken(account.getId());
            if (accessToken == null) {
                log.error("Dhan RMS skipped — token unavailable for clientId={}", account.getClientId());
                return new JSONObject();
            }
            JSONObject result = dhanClient.getRMS(
                    getBaseUrl(account),
                    account.getClientId(),
                    accessToken).get();
            return result != null ? result : new JSONObject();
        } catch (Exception e) {
            log.error("Dhan RMS failed for clientId={}: {}", account.getClientId(), e.getMessage());
            return new JSONObject();
        }
    }

    private JSONObject getProfitmartRMS(PyBrokerAccountEntity account) {
        try {
            String accessToken = pyTokenValidationService.getValidAccessToken(account.getId());
            if (accessToken == null) {
                log.error("Profitmart RMS skipped — token unavailable for clientId={}", account.getClientId());
                return new JSONObject();
            }
            JSONObject result = profitmartClient.getLimits(
                    getBaseUrl(account),
                    account.getClientId(),
                    accessToken).get();
            return result != null ? result : new JSONObject();
        } catch (Exception e) {
            log.error("Profitmart RMS failed for clientId={}: {}", account.getClientId(), e.getMessage());
            return new JSONObject();
        }
    }

    // ── LOGIN ────────────────────────────────────────────────────────────────
    private JSONObject loginAndGetTokens(DematAccountAddRequest request)
            throws IOException, SmartAPIException {
        return switch (request.getBrokerType()) {
            case ANGELONE   -> loginAngelOne(request);
            case MOTILAL    -> loginMotilal(request);
            case DHAN       -> loginDhan(request);
            case UPSTOX     -> loginUpstox(request);
            case ZERODHA    -> loginZerodha(request);
            case GOODWILL   -> loginGoodwill(request);
            case PROFITMART -> new JSONObject();
            default         -> throw new IllegalArgumentException(
                    "Unsupported broker: " + request.getBrokerType());
        };
    }

    private JSONObject loginZerodha(DematAccountAddRequest request) {
        PyBrokerIpConfigEntity ipConfig = pyBrokerIpConfigRepository
                .findByIpAddress(request.getIp().split(":")[0])
                .orElseThrow(() -> new RuntimeException("IP not found in DB: " + request.getIp()));
        String baseUrl = "http://" + ipConfig.getIpAddress() + ":" + ipConfig.getPortNo();
        log.info("Zerodha login via microservice | baseUrl={} clientId={}", baseUrl, request.getClientId());
        return zerodhaClient.login(baseUrl, request.getClientId(), request.getApiKey(), request.getApiSecretKey(), request.getTwoFa());
    }

    private JSONObject loginGoodwill(DematAccountAddRequest request) {
        PyBrokerIpConfigEntity ipConfig = pyBrokerIpConfigRepository
                .findByIpAddress(request.getIp().split(":")[0])
                .orElseThrow(() -> new RuntimeException("IP not found in DB: " + request.getIp()));
        String baseUrl = "http://" + ipConfig.getIpAddress() + ":" + ipConfig.getPortNo();
        log.info("Goodwill login via microservice | baseUrl={} clientId={}", baseUrl, request.getClientId());
        return goodwillClient.login(baseUrl, request.getClientId(), request.getApiKey(), request.getApiSecretKey(), request.getMpin());
    }

    private JSONObject loginUpstox(DematAccountAddRequest request) {
        log.info("Upstox login attempt for clientId={}", request.getClientId());
        String accessToken = upstoxAuthService.getUpstoxtoken(
                request.getApiKey(),
                request.getApiSecretKey(),
                request.getRedirectUri());
        if (accessToken == null || accessToken.startsWith("FAILED")) {
            throw new RuntimeException("Upstox login failed for clientId="
                    + request.getClientId() + ": " + accessToken);
        }
        log.info("Upstox login SUCCESS for clientId={}", request.getClientId());
        JSONObject json = new JSONObject();
        json.put("accessToken", accessToken);
        return json;
    }

    private JSONObject loginDhan(DematAccountAddRequest request) {
        PyBrokerIpConfigEntity ipConfig = pyBrokerIpConfigRepository
                .findByIpAddress(request.getIp().split(":")[0])
                .orElseThrow(() -> new RuntimeException("IP not found in DB: " + request.getIp()));
        String baseUrl = "http://" + ipConfig.getIpAddress() + ":" + ipConfig.getPortNo();
        log.info("Dhan login via microservice | baseUrl={} clientId={}", baseUrl, request.getClientId());
        String totp = totpUtil.generate(request.getTotpReferenceKey());
        JSONObject json = dhanClient.login(baseUrl, request.getClientId(), request.getMpin(), totp);
        log.info("Dhan login SUCCESS for clientId={}", request.getClientId());
        return json;
    }

    private JSONObject loginMotilal(DematAccountAddRequest request) {
        PyBrokerIpConfigEntity ipConfig = pyBrokerIpConfigRepository
                .findByIpAddress(request.getIp().split(":")[0])
                .orElseThrow(() -> new RuntimeException("IP not found in DB: " + request.getIp()));
        String baseUrl = "http://" + ipConfig.getIpAddress() + ":" + ipConfig.getPortNo();
        log.info("Motilal login via microservice | baseUrl={} clientId={}", baseUrl, request.getClientId());
        String totp = totpUtil.generate(request.getTotpReferenceKey());
        String hashedPassword = DigestUtils.sha256Hex(request.getMpin() + request.getApiKey());
        JSONObject loginJson = motilalClient.login(
                baseUrl,
                request.getClientId(),
                hashedPassword,
                request.getTwoFa(),
                totp,
                request.getApiKey(),
                request.getApiSecretKey(),
                request.getVendorInfo());
        JSONObject tokenJson = motilalClient.getAccessToken(
                baseUrl,
                loginJson.getString("AuthToken"),
                request.getApiKey(),
                request.getApiSecretKey(),
                request.getVendorInfo());
        loginJson.put("AccessToken", tokenJson.get("accesstoken"));
        log.info("Motilal login SUCCESS for clientId={}", request.getClientId());
        return loginJson;
    }

    private JSONObject loginAngelOne(DematAccountAddRequest request)
            throws IOException, SmartAPIException {
        PyBrokerIpConfigEntity ipConfig = pyBrokerIpConfigRepository
                .findByIpAddress(request.getIp().split(":")[0])
                .orElseThrow(() -> new RuntimeException("IP not found in DB: " + request.getIp()));
        String baseUrl = "http://" + ipConfig.getIpAddress() + ":" + ipConfig.getPortNo();
        log.info("AngelOne login via microservice | baseUrl={} clientId={}", baseUrl, request.getClientId());
        String totp = totpUtil.generate(request.getTotpReferenceKey());
        JSONObject data = angelOneClient.login(
                baseUrl,
                request.getClientId(),
                request.getMpin(),
                totp,
                request.getApiKey());
        if (data == null) {
            throw new RuntimeException("AngelOne login failed: null response from microservice");
        }
        log.info("AngelOne login SUCCESS for clientId={}", request.getClientId());
        return data;
    }

    // ── PROFILE FETCH ────────────────────────────────────────────────────────
    private User fetchUserProfile(DematAccountAddRequest request,
            JSONObject loginData, PyBrokerSecret secret)
            throws IOException, SmartAPIException {
        return switch (request.getBrokerType()) {
            case ANGELONE -> fetchAngelOneProfile(request.getApiKey(), loginData.getString("jwtToken"));
            case MOTILAL  -> fetchMotilalProfile(secret, loginData);
            default       -> throw new IllegalArgumentException(
                    "Unsupported broker: " + request.getBrokerType());
        };
    }

    private User fetchAngelOneProfile(String apiKey, String jwtToken)
            throws IOException, SmartAPIException {
        return new User().parseResponse(
                apiRequestHandler.getRequest(apiKey, routes.get("api.user.profile"), jwtToken));
    }

    private User fetchMotilalProfile(PyBrokerSecret secret, JSONObject loginData) {
        User user = new User();
        try {
            JSONObject json = motilalAccountService.getProfile(secret, loginData);
            if (json == null || !json.optString("status", "").equalsIgnoreCase("SUCCESS")) {
                throw new RuntimeException("Motilal profile fetch failed: "
                        + (json != null ? json.optString("message", "Unknown error") : "null response"));
            }
            JSONObject data = json.getJSONObject("data");
            user.setUserId(data.optString("clientcode", ""));
            user.setUserName(data.optString("name", ""));
            user.setBrokerName("MOTILAL");
            if (data.has("exchanges")) {
                JSONArray arr = data.getJSONArray("exchanges");
                String[] exchanges = new String[arr.length()];
                for (int i = 0; i < arr.length(); i++) exchanges[i] = arr.getString(i);
                user.setExchanges(exchanges);
            }
            if (data.has("products")) {
                JSONArray arr = data.getJSONArray("products");
                String[] products = new String[arr.length()];
                for (int i = 0; i < arr.length(); i++) products[i] = arr.getString(i);
                user.setProducts(products);
            }
            user.setMobileNo("");
            user.setEmail("");
            log.info("Motilal profile fetched for clientId={}", user.getUserId());
        } catch (Exception e) {
            log.error("Failed to parse Motilal profile: {}", e.getMessage(), e);
            throw new RuntimeException("Motilal profile parse failed: " + e.getMessage());
        }
        return user;
    }

    // ── TOKEN EXPIRY ─────────────────────────────────────────────────────────
    private LocalDateTime getTokenExpiry(BrokerType brokerType) {
        LocalDateTime now = LocalDateTime.now();
        return switch (brokerType) {
            case ANGELONE   -> LocalDate.now().plusDays(1).atStartOfDay();
            case MOTILAL    -> {
                LocalDateTime todaySixAm = LocalDate.now().atTime(6, 0);
                yield now.isBefore(todaySixAm) ? todaySixAm : todaySixAm.plusDays(1);
            }
            case DHAN       -> now.plusHours(24);
            case UPSTOX     -> LocalDate.now().plusDays(1).atStartOfDay();
            case PROFITMART -> LocalDate.now().plusDays(1).atStartOfDay();
            default         -> now.plusHours(24);
        };
    }

    // ── GET LATEST TOKEN ─────────────────────────────────────────────────────
    @Override
    public Map<String, String> getLatestAccessToken(long pyUserId) {
        Map<String, String> map = new HashMap<>();
        List<PyBrokerAccountEntity> accounts = pyBrokerAccountRepository.findByPyUserId(pyUserId);
        map.put("apiKey",      accounts.get(0).getSecret().getApiKey());
        map.put("accessToken", accounts.get(0).getToken().getAccessToken());
        return map;
    }

    @Override
    public String getApiKey() {
        return null;
    }

    // ── PLACE INDIVIDUAL ORDER ───────────────────────────────────────────────
    @Override
    public Order placeIndividualOrder(IndividualOrderRequest request, String transactionType) {

        PyBrokerAccountEntity dematAccount = pyBrokerAccountRepository
                .findById(request.getAccId())
                .orElseThrow(() -> new RuntimeException(
                        "Demat account not found: " + request.getAccId()));

        IndividualOrderAuditEntity audit = new IndividualOrderAuditEntity();
        audit.setDematAccountId(dematAccount.getId());
        audit.setClientId(dematAccount.getClientId());
        audit.setUserName(dematAccount.getUserName());
        audit.setTradingSymbol(request.getTradingSymbol());
        audit.setExchange(request.getExchange());
        audit.setQuantity(request.getQuantity());
        audit.setOrderType(request.getOrderType());
        audit.setProductType(request.getProductType());
        audit.setPrice(request.getPrice());
        audit.setTransactionType(transactionType);
        audit.setVariety(request.getVariety() != null ? request.getVariety() : "NORMAL");
        audit.setExecutedAt(LocalDateTime.now());
        audit.setBrokerType(dematAccount.getBrokerType());
        audit.setSymbolToken(request.getSymbolToken());

        // ── PAPER TRADING ENGINE ─────────────────────────────────────────
        if (paperTradingService.isPaperTradingEnabled()) {
            log.info("🛡️ Routing order to PaperTradingEngine | clientId={} symbol={} side={}",
                    dematAccount.getClientId(), request.getTradingSymbol(), transactionType);
            return paperTradingEngine.executePaperOrder(dematAccount, request, transactionType);
        }

        // ── LIVE TRADING SAFEGUARD ───────────────────────────────────────
        paperTradingService.validateLiveOrderAllowed();

        try {
            PyBrokerSecret secret = dematAccount.getSecret();
            if (secret == null) {
                audit.setStatus("FAILED");
                audit.setRemarks("No API credentials found");
                individualOrderAuditRepository.save(audit);
                throw new RuntimeException("No API credentials found for: " + dematAccount.getClientId());
            }

            String accessToken = pyTokenValidationService.getValidAccessToken(dematAccount.getId());
            if (accessToken == null) {
                audit.setStatus("FAILED");
                audit.setRemarks("Token unavailable — account deactivated due to login failure");
                individualOrderAuditRepository.save(audit);
                throw new RuntimeException("Token unavailable for clientId: "
                        + dematAccount.getClientId() + " — account has been deactivated");
            }

            audit.setSymbolToken(request.getSymbolToken());

            log.info("Placing {} order — clientId={} symbol={} token={}",
                    transactionType, dematAccount.getClientId(),
                    request.getTradingSymbol(), request.getSymbolToken());

            Order order = new Order();

            // ── ANGELONE ─────────────────────────────────────────────────────
            if (dematAccount.getBrokerType().equals(BrokerType.ANGELONE)) {
                AngelOnePlaceOrderRequest orderRequest = new AngelOnePlaceOrderRequest();
                orderRequest.setApiKey(secret.getApiKey());
                orderRequest.setAccessToken(accessToken);
                orderRequest.setVariety(audit.getVariety());
                orderRequest.setExchange(request.getExchange());
                orderRequest.setTradingsymbol(request.getTradingSymbol());
                orderRequest.setSymboltoken(request.getSymbolToken());
                orderRequest.setOrdertype(request.getOrderType());
                orderRequest.setProducttype(request.getProductType());
                orderRequest.setQuantity(request.getQuantity());
                orderRequest.setPrice(request.getPrice());
                orderRequest.setDuration("DAY");
                orderRequest.setTransactiontype(transactionType);
                orderRequest.setSquareoff("0");
                orderRequest.setStoploss("0");
                orderRequest.setTriggerprice(0.0);

                JSONObject response = angelOneClient.placeOrder(getBaseUrl(dematAccount), orderRequest).get();
                order.orderId      = response.optString("orderId");
                order.uniqueOrderId = response.optString("orderId");

                if (order.orderId == null || order.orderId.isEmpty()) {
                    audit.setStatus("FAILED");
                    audit.setRemarks("Null response from broker");
                    individualOrderAuditRepository.save(audit);
                    throw new RuntimeException("Order failed — null response from broker");
                }
            }

            // ── DHAN ──────────────────────────────────────────────────────────
            if (dematAccount.getBrokerType().equals(BrokerType.DHAN)) {
                DhanPlaceOrderRequest placeRequest = new DhanPlaceOrderRequest();
                placeRequest.setClientId(dematAccount.getClientId());
                placeRequest.setAccessToken(accessToken);
                placeRequest.setDhanClientId(dematAccount.getClientId());
                placeRequest.setCorrelationId("PANCHAYAGAM_" + System.currentTimeMillis());
                placeRequest.setTransactionType(transactionType);
                placeRequest.setExchangeSegment(toDhanExchange(request.getExchange()));
                placeRequest.setProductType(toDhanProductType(request.getProductType()));
                placeRequest.setOrderType(toDhanOrderType(request.getOrderType()));
                placeRequest.setValidity("DAY");
                placeRequest.setSecurityId(request.getSymbolToken());
                placeRequest.setQuantity(request.getQuantity());
                placeRequest.setDisclosedQuantity(0);
                placeRequest.setPrice(request.getPrice());
                placeRequest.setTriggerPrice(0.0);
                placeRequest.setAfterMarketOrder("Y".equals(request.getAmo()));

                JSONObject dhanResponse = dhanClient.placeOrder(getBaseUrl(dematAccount), placeRequest).get();
                order.orderId      = dhanResponse.optString("orderId", "");
                order.uniqueOrderId = dhanResponse.optString("orderId", "");
            }

            // ── MOTILAL ───────────────────────────────────────────────────────
            if (dematAccount.getBrokerType().equals(BrokerType.MOTILAL)) {
                MotilolOrderParams orderParams = getMotiolOrderParams(request);
                orderParams.setBuyOrSell(transactionType);

                if ("MARKET".equals(orderParams.getOrderType())) {
                    JSONObject ltpData = motilalClient.getLtp(
                            getBaseUrl(dematAccount),
                            secret.getApiKey(),
                            secret.getApiSecret(),
                            secret.getVenderInfo(),
                            dematAccount.getToken().getRefreshToken(),
                            accessToken,
                            request.getExchange(),
                            Long.parseLong(request.getSymbolToken()));

                    double ltp = ltpData.optDouble("ltp", 0.0) / 100.0;
                    if (ltp <= 0) {
                        throw new RuntimeException("Could not fetch live LTP for: " + request.getTradingSymbol());
                    }
                    orderParams.setOrderType("LIMIT");
                    orderParams.setPrice(ltp);
                    log.info("Motilal MARKET→LIMIT | symbol={} ltp=₹{}", request.getTradingSymbol(), ltp);
                }

                MotilalPlaceOrderRequest placeRequest = new MotilalPlaceOrderRequest();
                placeRequest.setApiKey(secret.getApiKey());
                placeRequest.setApiSecret(secret.getApiSecret());
                placeRequest.setVendorInfo(secret.getVenderInfo());
                placeRequest.setAuthToken(dematAccount.getToken().getRefreshToken());
                placeRequest.setAccessToken(accessToken);
                placeRequest.setExchange(orderParams.getExchange());
                placeRequest.setSymbolToken(orderParams.getSymbolToken());
                placeRequest.setBuyOrSell(orderParams.getBuyOrSell());
                placeRequest.setOrderType(orderParams.getOrderType());
                placeRequest.setProductType(orderParams.getProductType());
                placeRequest.setOrderDuration(orderParams.getOrderDuration());
                placeRequest.setPrice(orderParams.getPrice());
                placeRequest.setTriggerPrice(orderParams.getTriggerPrice());
                placeRequest.setQuantityInLot(orderParams.getQuantityInLot());
                placeRequest.setDisclosedQuantity(orderParams.getDisclosedQuantity());
                placeRequest.setAmoOrder("Y".equals(request.getAmo()) ? "Y" : "N");
                placeRequest.setGoodTillDate(orderParams.getGoodTillDate());
                placeRequest.setAlgoId(orderParams.getAlgoId());
                placeRequest.setParticipantCode(orderParams.getParticipantCode());

                JSONObject moResponse = motilalClient.placeOrder(getBaseUrl(dematAccount), placeRequest).get();
                order.orderId      = moResponse.optString("uniqueorderid", "");
                order.uniqueOrderId = moResponse.optString("uniqueorderid", "");
            }

            // ── PROFITMART ────────────────────────────────────────────────────
            if (dematAccount.getBrokerType().equals(BrokerType.PROFITMART)) {
                log.info("Placing Profitmart order | clientId={} tsym={} qty={} side={}",
                        dematAccount.getClientId(), request.getTradingSymbol(),
                        request.getQuantity(), transactionType);

                JSONObject response = profitmartClient.placeOrder(
                        getBaseUrl(dematAccount),
                        dematAccount.getClientId(),
                        accessToken,
                        request.getExchange(),
                        request.getTradingSymbol(),
                        transactionType,
                        request.getQuantity(),
                        0,
                        request.getOrderType(),
                        request.getPrice(),
                        null,
                        request.getProductType(),
                        "DAY",
                        "",
                        "No").get();

                order.orderId      = response.optString("norenordno", "");
                order.uniqueOrderId = response.optString("norenordno", "");

                if (order.orderId == null || order.orderId.isEmpty()) {
                    audit.setStatus("FAILED");
                    audit.setRemarks("Null response from Profitmart");
                    individualOrderAuditRepository.save(audit);
                    throw new RuntimeException("Order failed — null response from Profitmart");
                }
            }

            // ── UPSTOX ────────────────────────────────────────────────────────
            if (dematAccount.getBrokerType().equals(BrokerType.UPSTOX)) {
                Map<String, Object> orderPayload = new HashMap<>();
                orderPayload.put("clientId", dematAccount.getClientId());
                orderPayload.put("accessToken", accessToken);
                orderPayload.put("quantity", request.getQuantity());
                orderPayload.put("product", request.getProductType() != null ? request.getProductType() : "D");
                orderPayload.put("validity", "DAY");
                orderPayload.put("price", request.getPrice() != null ? request.getPrice() : 0.0);
                orderPayload.put("tag", "panchayagnam");
                orderPayload.put("instrumentToken", request.getSymbolToken() != null ? request.getSymbolToken() : request.getTradingSymbol());
                orderPayload.put("orderType", request.getOrderType() != null ? request.getOrderType() : "MARKET");
                orderPayload.put("transactionType", transactionType);
                orderPayload.put("disclosedQuantity", 0);
                orderPayload.put("triggerPrice", 0.0);
                orderPayload.put("isAmo", "Y".equals(request.getAmo()));

                JSONObject response = upstoxClient.placeOrder(getBaseUrl(dematAccount), orderPayload).get();
                order.orderId = response.optString("orderId", "");
                order.uniqueOrderId = response.optString("orderId", "");
            }

            // ── ZERODHA ───────────────────────────────────────────────────────
            if (dematAccount.getBrokerType().equals(BrokerType.ZERODHA)) {
                Map<String, Object> orderPayload = new HashMap<>();
                orderPayload.put("clientId", dematAccount.getClientId());
                orderPayload.put("apiKey", secret.getApiKey());
                orderPayload.put("accessToken", accessToken);
                orderPayload.put("tradingsymbol", request.getTradingSymbol());
                orderPayload.put("exchange", request.getExchange());
                orderPayload.put("transactionType", transactionType);
                orderPayload.put("orderType", request.getOrderType() != null ? request.getOrderType() : "MARKET");
                orderPayload.put("quantity", request.getQuantity());
                orderPayload.put("product", request.getProductType() != null ? request.getProductType() : "CNC");
                orderPayload.put("price", request.getPrice() != null ? request.getPrice() : 0.0);
                orderPayload.put("triggerPrice", 0.0);
                orderPayload.put("validity", "DAY");
                orderPayload.put("disclosedQuantity", 0);
                orderPayload.put("tag", "panchayagnam");

                JSONObject response = zerodhaClient.placeOrder(getBaseUrl(dematAccount), orderPayload).get();
                order.orderId = response.optString("orderId", "");
                order.uniqueOrderId = response.optString("orderId", "");
            }

            // ── GOODWILL ──────────────────────────────────────────────────────
            if (dematAccount.getBrokerType().equals(BrokerType.GOODWILL)) {
                Map<String, Object> orderPayload = new HashMap<>();
                orderPayload.put("clientId", dematAccount.getClientId());
                orderPayload.put("accessToken", accessToken);
                orderPayload.put("exchangeSegment", request.getExchange() != null ? request.getExchange() : "NSE");
                orderPayload.put("exchangeInstrumentId", request.getSymbolToken() != null ? request.getSymbolToken() : "");
                orderPayload.put("productType", request.getProductType() != null ? request.getProductType() : "CNC");
                orderPayload.put("orderType", request.getOrderType() != null ? request.getOrderType() : "MARKET");
                orderPayload.put("orderSide", transactionType);
                orderPayload.put("timeInForce", "DAY");
                orderPayload.put("disclosedQuantity", 0);
                orderPayload.put("orderQuantity", request.getQuantity());
                orderPayload.put("limitPrice", request.getPrice() != null ? request.getPrice() : 0.0);
                orderPayload.put("stopPrice", 0.0);
                orderPayload.put("orderUniqueIdentifier", "PANCHAYAGNAM_" + System.currentTimeMillis());

                JSONObject response = goodwillClient.placeOrder(getBaseUrl(dematAccount), orderPayload).get();
                order.orderId = response.optString("orderId", "");
                order.uniqueOrderId = response.optString("orderId", "");
            }

            audit.setStatus("SUCCESS");
            audit.setOrderId(order.orderId);
            audit.setUniqueOrderId(order.uniqueOrderId);
            audit.setRemarks(null);
            individualOrderAuditRepository.save(audit);

            log.info("{} order SUCCESS — clientId={} symbol={} orderId={}",
                    transactionType, dematAccount.getClientId(),
                    request.getTradingSymbol(), order.orderId);

            return order;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            audit.setStatus("FAILED");
            audit.setRemarks(e.getMessage());
            individualOrderAuditRepository.save(audit);
            log.error("Order failed — clientId={} symbol={} error={}",
                    dematAccount.getClientId(), request.getTradingSymbol(), e.getMessage());
            throw new RuntimeException("Order failed: " + e.getMessage());
        }
    }

    // ── GROUPED BROKER ACCOUNTS ───────────────────────────────────────────────
    public Map<String, List<Map<String, Object>>> getBrokerAccountsGroupedByType(Long pyId) {
        List<PyBrokerAccountEntity> accounts = pyBrokerAccountRepository
                .findByPyUserIdAndActive(pyId, true);

        Map<String, List<Map<String, Object>>> groupedAccounts = new LinkedHashMap<>();
        for (BrokerType brokerType : BrokerType.values()) {
            groupedAccounts.put(brokerType.name(), new ArrayList<>());
        }
        for (PyBrokerAccountEntity account : accounts) {
            Map<String, Object> accountMap = new LinkedHashMap<>();
            accountMap.put("brokerId", account.getId());
            accountMap.put("clientId", account.getClientId());
            groupedAccounts.get(account.getBrokerType().name()).add(accountMap);
        }
        return groupedAccounts;
    }

    // ── ORDER HISTORY ─────────────────────────────────────────────────────────
    @Override
    public JSONObject getOrderHistory(Long accId) throws DeActivatedAccountException {
        PyBrokerAccountEntity dematAccount = pyBrokerAccountRepository
                .findById(accId)
                .orElseThrow(() -> new RuntimeException("Account not found: " + accId));

        if (!dematAccount.getActive()) {
            throw new DeActivatedAccountException(
                    "Live Feed can't be run for deactivated accounts: " + accId);
        }

        // ── PAPER TRADING ORDER HISTORY ──────────────────────────────
        if (paperTradingService.isPaperTradingEnabled()) {
            return getPaperOrderHistory(accId, dematAccount);
        }

        return switch (dematAccount.getBrokerType()) {

            case ANGELONE -> {
                try {
                    String accessToken = pyTokenValidationService.getValidAccessToken(accId);
                    if (accessToken == null) throw new RuntimeException(
                            "Token unavailable for clientId: " + dematAccount.getClientId());
                    JSONObject result = angelOneClient.getOrderHistory(
                            getBaseUrl(dematAccount),
                            dematAccount.getSecret().getApiKey(),
                            accessToken).get();
                    yield normalizeAngelOneOrders(result);
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch order history: " + e.getMessage(), e);
                }
            }

            case MOTILAL -> {
                try {
                    String accessToken = pyTokenValidationService.getValidAccessToken(accId);
                    if (accessToken == null) throw new RuntimeException(
                            "Token unavailable for clientId: " + dematAccount.getClientId());
                    JSONObject response = motilalClient.getOrderHistory(
                            getBaseUrl(dematAccount),
                            dematAccount.getSecret().getApiKey(),
                            dematAccount.getSecret().getApiSecret(),
                            dematAccount.getSecret().getVenderInfo(),
                            dematAccount.getToken().getRefreshToken(),
                            accessToken).get();
                    if (response == null) throw new RuntimeException("Failed to fetch order history");
                    yield normalizeMotilalOrders(response);
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch Motilal order history: " + e.getMessage(), e);
                }
            }

            case DHAN -> {
                try {
                    String accessToken = pyTokenValidationService.getValidAccessToken(accId);
                    if (accessToken == null) throw new RuntimeException(
                            "Token unavailable for clientId: " + dematAccount.getClientId());
                    JSONObject response = dhanClient.getOrderHistory(
                            getBaseUrl(dematAccount),
                            dematAccount.getClientId(),
                            accessToken).get();
                    if (response == null) throw new RuntimeException("Failed to fetch Dhan order history");
                    yield normalizeDhanOrders(response);
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch Dhan order history: " + e.getMessage(), e);
                }
            }

            case PROFITMART -> {
                try {
                    String accessToken = pyTokenValidationService.getValidAccessToken(accId);
                    if (accessToken == null) throw new RuntimeException(
                            "Token unavailable for clientId: " + dematAccount.getClientId());
                    JSONArray result = profitmartClient.getOrderBook(
                            getBaseUrl(dematAccount),
                            dematAccount.getClientId(),
                            accessToken).get();
                    yield normalizeProfitmartOrders(result);
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch Profitmart order history: " + e.getMessage(), e);
                }
            }

            case UPSTOX -> {
                try {
                    String accessToken = pyTokenValidationService.getValidAccessToken(accId);
                    if (accessToken == null) throw new RuntimeException(
                            "Token unavailable for clientId: " + dematAccount.getClientId());
                    JSONObject result = upstoxClient.getOrderHistory(
                            getBaseUrl(dematAccount),
                            dematAccount.getClientId(),
                            accessToken).get();
                    yield result != null ? result : buildOrderResponse(new JSONArray());
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch Upstox order history: " + e.getMessage(), e);
                }
            }

            case ZERODHA -> {
                try {
                    String accessToken = pyTokenValidationService.getValidAccessToken(accId);
                    if (accessToken == null) throw new RuntimeException(
                            "Token unavailable for clientId: " + dematAccount.getClientId());
                    String apiKey = dematAccount.getSecret() != null ? dematAccount.getSecret().getApiKey() : "";
                    JSONObject result = zerodhaClient.getOrderHistory(
                            getBaseUrl(dematAccount),
                            dematAccount.getClientId(),
                            apiKey,
                            accessToken).get();
                    yield result != null ? result : buildOrderResponse(new JSONArray());
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch Zerodha order history: " + e.getMessage(), e);
                }
            }

            case GOODWILL -> {
                try {
                    String accessToken = pyTokenValidationService.getValidAccessToken(accId);
                    if (accessToken == null) throw new RuntimeException(
                            "Token unavailable for clientId: " + dematAccount.getClientId());
                    JSONObject result = goodwillClient.getOrderHistory(
                            getBaseUrl(dematAccount),
                            dematAccount.getClientId(),
                            accessToken).get();
                    yield result != null ? result : buildOrderResponse(new JSONArray());
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch Goodwill order history: " + e.getMessage(), e);
                }
            }

            default -> new JSONObject();
        };
    }

    private JSONObject getPaperOrderHistory(Long accId, PyBrokerAccountEntity dematAccount) {
        List<IndividualOrderAuditEntity> audits =
                individualOrderAuditRepository.findByDematAccountIdOrderByExecutedAtDesc(accId);

        JSONArray normalized = new JSONArray();
        for (IndividualOrderAuditEntity a : audits) {
            String status = "SUCCESS".equalsIgnoreCase(a.getStatus()) ? "complete" : "rejected";
            int qty = a.getQuantity() != null ? a.getQuantity() : 0;
            int filled = "complete".equals(status) ? qty : 0;
            double p = a.getPrice() != null ? a.getPrice() : 0.0;
            String time = a.getExecutedAt() != null ? a.getExecutedAt().toString() : "";

            JSONObject obj = buildUnifiedOrder(
                    a.getVariety() != null ? a.getVariety() : "NORMAL",
                    a.getOrderType() != null ? a.getOrderType() : "LIMIT",
                    a.getProductType() != null ? a.getProductType() : "DELIVERY",
                    "DAY",
                    p,
                    0.0,
                    qty,
                    0,
                    a.getTradingSymbol() != null ? a.getTradingSymbol() : "",
                    a.getTransactionType() != null ? a.getTransactionType() : "BUY",
                    a.getExchange() != null ? a.getExchange() : "NSE",
                    a.getSymbolToken() != null ? a.getSymbolToken() : "",
                    p,
                    filled,
                    qty - filled,
                    a.getOrderId() != null ? a.getOrderId() : "",
                    a.getUniqueOrderId() != null ? a.getUniqueOrderId() : "",
                    a.getOrderId() != null ? a.getOrderId() : "",
                    status,
                    time,
                    time,
                    a.getRemarks() != null ? a.getRemarks() : "[PAPER TRADING - SIMULATED ORDER]",
                    dematAccount.getBrokerType() != null ? dematAccount.getBrokerType().name() : "SIMULATED"
            );
            obj.put("isSimulated", true);
            normalized.put(obj);
        }
        return buildOrderResponse(normalized);
    }

    // ── NORMALIZE ORDERS ──────────────────────────────────────────────────────
    private JSONObject normalizeAngelOneOrders(JSONObject response) {
        try {
            JSONArray data = response.optJSONArray("data");
            if (data == null) return buildOrderResponse(new JSONArray());
            JSONArray normalized = new JSONArray();
            for (int i = 0; i < data.length(); i++) {
                JSONObject o = data.getJSONObject(i);
                normalized.put(buildUnifiedOrder(
                        o.optString("variety", "NORMAL"),
                        o.optString("ordertype", ""),
                        o.optString("producttype", ""),
                        o.optString("duration", "DAY"),
                        o.optDouble("price", 0),
                        o.optDouble("triggerprice", 0),
                        o.optInt("quantity", 0),
                        o.optInt("disclosedquantity", 0),
                        o.optString("tradingsymbol", ""),
                        o.optString("transactiontype", ""),
                        o.optString("exchange", ""),
                        o.optString("symboltoken", ""),
                        o.optDouble("averageprice", 0),
                        o.optInt("filledshares", 0),
                        o.optInt("unfilledshares", 0),
                        o.optString("orderid", ""),
                        o.optString("uniqueorderid", ""),
                        o.optString("exchangeorderid", ""),
                        o.optString("orderstatus", ""),
                        o.optString("updatetime", ""),
                        o.optString("exchtime", ""),
                        o.optString("text", ""),
                        "ANGELONE"));
            }
            return buildOrderResponse(normalized);
        } catch (Exception e) {
            log.error("normalizeAngelOneOrders failed: {}", e.getMessage());
            return buildOrderResponse(new JSONArray());
        }
    }

    private JSONObject normalizeMotilalOrders(JSONObject response) {
        try {
            JSONArray data = response.optJSONArray("data");
            if (data == null) return buildOrderResponse(new JSONArray());
            JSONArray normalized = new JSONArray();
            for (int i = 0; i < data.length(); i++) {
                JSONObject o = data.getJSONObject(i);
                normalized.put(buildUnifiedOrder(
                        o.optString("ordercategory", "NORMAL"),
                        o.optString("ordertype", "").toUpperCase(),
                        o.optString("producttype", ""),
                        o.optString("orderduration", "DAY").toUpperCase(),
                        o.optDouble("price", 0),
                        o.optDouble("triggerprice", 0),
                        o.optInt("orderqty", 0),
                        o.optInt("disclosedqty", 0),
                        o.optString("symbol", ""),
                        o.optString("buyorsell", "").toUpperCase(),
                        o.optString("exchange", ""),
                        String.valueOf(o.optLong("symboltoken", 0)),
                        o.optDouble("averageprice", 0),
                        o.optInt("totalqtytraded", 0),
                        o.optInt("totalqtyremaining", 0),
                        o.optString("orderid", ""),
                        o.optString("uniqueorderid", ""),
                        "",
                        mapMotilalStatus(o.optString("orderstatus", "")),
                        o.optString("lastmodifiedtime", ""),
                        o.optString("entrydatetime", ""),
                        o.optString("error", ""),
                        "MOTILAL"));
            }
            return buildOrderResponse(normalized);
        } catch (Exception e) {
            log.error("normalizeMotilalOrders failed: {}", e.getMessage());
            return buildOrderResponse(new JSONArray());
        }
    }

    private JSONObject normalizeDhanOrders(JSONObject response) {
        try {
            JSONArray data = response.optJSONArray("data");
            if (data == null) return buildOrderResponse(new JSONArray());
            JSONArray normalized = new JSONArray();
            for (int i = 0; i < data.length(); i++) {
                JSONObject o = data.getJSONObject(i);
                normalized.put(buildUnifiedOrder(
                        "NORMAL",
                        o.optString("orderType", ""),
                        o.optString("productType", ""),
                        o.optString("validity", "DAY"),
                        o.optDouble("price", 0),
                        o.optDouble("triggerPrice", 0),
                        o.optInt("quantity", 0),
                        o.optInt("disclosedQuantity", 0),
                        o.optString("tradingSymbol", ""),
                        o.optString("transactionType", ""),
                        o.optString("exchangeSegment", ""),
                        o.optString("securityId", ""),
                        o.optDouble("averageTradedPrice", 0),
                        o.optInt("filledQty", 0),
                        o.optInt("remainingQuantity", 0),
                        o.optString("orderId", ""),
                        o.optString("orderId", ""),
                        o.optString("exchangeOrderId", ""),
                        mapDhanStatus(o.optString("orderStatus", "")),
                        o.optString("updateTime", ""),
                        o.optString("createTime", ""),
                        o.optString("omsErrorDescription", ""),
                        "DHAN"));
            }
            return buildOrderResponse(normalized);
        } catch (Exception e) {
            log.error("normalizeDhanOrders failed: {}", e.getMessage());
            return buildOrderResponse(new JSONArray());
        }
    }

    private JSONObject normalizeProfitmartOrders(JSONArray data) {
        try {
            if (data == null) return buildOrderResponse(new JSONArray());
            JSONArray normalized = new JSONArray();
            for (int i = 0; i < data.length(); i++) {
                JSONObject o = data.getJSONObject(i);
                int totalQty  = o.optInt("qty", 0);
                int filledQty = o.optInt("fillshares", 0);
                normalized.put(buildUnifiedOrder(
                        "NORMAL",
                        o.optString("prctyp",    ""),
                        o.optString("prd",       ""),
                        o.optString("ret",       "DAY"),
                        o.optDouble("prc",       0),
                        o.optDouble("trgprc",    0),
                        totalQty,
                        o.optInt("dscqty",       0),
                        o.optString("tsym",      ""),
                        o.optString("trantype",  ""),
                        o.optString("exch",      ""),
                        o.optString("token",     ""),
                        o.optDouble("avgprc",    0),
                        filledQty,
                        totalQty - filledQty,
                        o.optString("norenordno", ""),
                        o.optString("norenordno", ""),
                        o.optString("exch_tm",    ""),
                        mapProfitmartStatus(o.optString("status", "")),
                        o.optString("norentm",    ""),
                        o.optString("exch_tm",    ""),
                        o.optString("rejreason",  ""),
                        "PROFITMART"));
            }
            return buildOrderResponse(normalized);
        } catch (Exception e) {
            log.error("normalizeProfitmartOrders failed: {}", e.getMessage());
            return buildOrderResponse(new JSONArray());
        }
    }

    // ── STATUS MAPPERS ────────────────────────────────────────────────────────
    private String mapProfitmartStatus(String status) {
        if (status == null) return "unknown";
        return switch (status.toUpperCase()) {
            case "OPEN"            -> "open";
            case "COMPLETE"        -> "complete";
            case "CANCELLED"       -> "cancelled";
            case "REJECTED"        -> "rejected";
            case "TRIGGER_PENDING" -> "trigger pending";
            case "OPEN_PENDING"    -> "open";
            default                -> status.toLowerCase();
        };
    }

    private String mapMotilalStatus(String status) {
        if (status == null) return "unknown";
        return switch (status.toLowerCase()) {
            case "confirm", "confirmed"           -> "open";
            case "executed", "fully executed"     -> "complete";
            case "cancelled", "cancel"            -> "cancelled";
            case "rejected", "error"              -> "rejected";
            case "open pending", "modify pending" -> "open";
            case "trigger pending"                -> "trigger pending";
            default                               -> status.toLowerCase();
        };
    }

    private String mapDhanStatus(String status) {
        if (status == null) return "unknown";
        return switch (status.toUpperCase()) {
            case "PENDING", "TRANSIT", "PART_TRADED" -> "open";
            case "TRADED"                            -> "complete";
            case "CANCELLED", "EXPIRED"              -> "cancelled";
            case "REJECTED"                          -> "rejected";
            default                                  -> status.toLowerCase();
        };
    }

    // ── UNIFIED ORDER BUILDER ─────────────────────────────────────────────────
    private JSONObject buildUnifiedOrder(
            String variety, String orderType, String productType,
            String duration, double price, double triggerPrice,
            int quantity, int disclosedQty, String tradingSymbol,
            String txType, String exchange, String symbolToken,
            double avgPrice, int filledShares, int unfilledShares,
            String orderId, String uniqueOrderId, String exchangeOrderId,
            String orderStatus, String updateTime, String exchTime,
            String remarks, String broker) {

        JSONObject obj = new JSONObject();
        obj.put("variety",          variety);
        obj.put("ordertype",        orderType);
        obj.put("producttype",      productType);
        obj.put("duration",         duration);
        obj.put("price",            round(price));
        obj.put("triggerprice",     round(triggerPrice));
        obj.put("quantity",         quantity);
        obj.put("disclosedquantity",disclosedQty);
        obj.put("tradingsymbol",    tradingSymbol);
        obj.put("transactiontype",  txType);
        obj.put("exchange",         exchange);
        obj.put("symboltoken",      symbolToken);
        obj.put("averageprice",     round(avgPrice));
        obj.put("filledshares",     filledShares);
        obj.put("unfilledshares",   unfilledShares);
        if (broker.equals("MOTILAL")) {
            obj.put("orderid",      uniqueOrderId);
            obj.put("uniqueorderid",orderId);
        } else {
            obj.put("orderid",      orderId);
            obj.put("uniqueorderid",uniqueOrderId);
        }
        obj.put("exchangeorderid",  exchangeOrderId);
        obj.put("orderstatus",      orderStatus);
        obj.put("status",           orderStatus);
        obj.put("updatetime",       updateTime);
        obj.put("exchtime",         exchTime);
        obj.put("text",             remarks);
        obj.put("broker",           broker);
        return obj;
    }

    private JSONObject buildOrderResponse(JSONArray orders) {
        JSONObject response = new JSONObject();
        response.put("status",    true);
        response.put("message",   "SUCCESS");
        response.put("errorcode", "");
        response.put("data",      orders);
        return response;
    }

    private double round(double value) {
        return Math.round(value * 100.0) / 100.0;
    }

    // ── BUILD SMART CONNECT ───────────────────────────────────────────────────
    private SmartConnect buildSmartConnect(Long accId) {
        PyBrokerAccountEntity dematAccount = pyBrokerAccountRepository
                .findById(accId)
                .orElseThrow(() -> new RuntimeException("Account not found: " + accId));
        PyBrokerSecret secret = dematAccount.getSecret();
        if (secret == null) throw new RuntimeException(
                "No API credentials for: " + dematAccount.getClientId());
        String accessToken = pyTokenValidationService.getValidAccessToken(accId);
        if (accessToken == null) throw new RuntimeException(
                "Token unavailable for clientId: " + dematAccount.getClientId());
        SmartConnect smartConnect = new SmartConnect(secret.getApiKey());
        smartConnect.setAccessToken(accessToken);
        return smartConnect;
    }

    // ── ORDER PARAMS BUILDERS ─────────────────────────────────────────────────
    public OrderParams getAngelOneOrderParams(IndividualOrderRequest request) {
        OrderParams orderParams = new OrderParams();
        orderParams.setExchange(request.getExchange());
        orderParams.setTradingsymbol(request.getTradingSymbol());
        orderParams.setSymboltoken(request.getSymbolToken());
        orderParams.setOrdertype(request.getOrderType());
        orderParams.setProducttype(request.getProductType());
        orderParams.setQuantity(request.getQuantity());
        orderParams.setPrice(request.getPrice());
        orderParams.setDuration("DAY");
        orderParams.setSquareoff("0");
        orderParams.setStoploss("0");
        orderParams.setTriggerprice("0");
        return orderParams;
    }

    public DhanOrderParams getDhanOrderParams(IndividualOrderRequest request) {
        DhanOrderParams orderParams = new DhanOrderParams();
        orderParams.setDhanClientId("");
        orderParams.setCorrelationId("PANCHAYAGAM_" + System.currentTimeMillis());
        orderParams.setExchangeSegment(dhanAccountService.toDhanExchange(request.getExchange()));
        orderParams.setProductType(dhanAccountService.toDhanProductType(request.getProductType()));
        orderParams.setOrderType(dhanAccountService.toDhanOrderType(request.getOrderType()));
        orderParams.setValidity("DAY");
        orderParams.setSecurityId(request.getSymbolToken());
        orderParams.setQuantity(request.getQuantity());
        orderParams.setDisclosedQuantity(0);
        orderParams.setPrice(request.getPrice());
        orderParams.setTriggerPrice(0.0);
        orderParams.setAfterMarketOrder(false);
        orderParams.setAmoTime("OPEN");
        return orderParams;
    }

    public MotilolOrderParams getMotiolOrderParams(IndividualOrderRequest request) {
        MotilolOrderParams orderParams = new MotilolOrderParams();
        orderParams.setExchange(request.getExchange());
        orderParams.setSymbolToken(Integer.parseInt(request.getSymbolToken()));
        String orderType = switch (request.getOrderType()) {
            case "STOPLOSS_LIMIT", "STOPLOSS_MARKET" -> "STOPLOSS";
            case "MARKET"                            -> "MARKET";
            case "LIMIT"                             -> "LIMIT";
            default                                  -> "MARKET";
        };
        orderParams.setOrderType(orderType);
        String productType = switch (request.getProductType()) {
            case "DELIVERY"                    -> "DELIVERY";
            case "CARRYFORWARD", "INTRADAY",
                 "MARGIN"                      -> "NORMAL";
            default                            -> "NORMAL";
        };
        orderParams.setProductType(productType);
        orderParams.setOrderDuration("DAY");
        orderParams.setPrice(request.getPrice());
        orderParams.setTriggerPrice(0.0);
        orderParams.setQuantityInLot(request.getQuantity());
        orderParams.setDisclosedQuantity(0);
        orderParams.setAmoOrder("N");
        orderParams.setGoodTillDate("");
        orderParams.setAlgoId("");
        orderParams.setTag("PANCHAYAGM");
        orderParams.setParticipantCode("");
        return orderParams;
    }

    // ── GROUPED BROKER ACCOUNTS (Summary DTO) ─────────────────────────────────
    @Override
    @Transactional(readOnly = true)
    public ApiResponse<Map<String, List<PyBrokerAccountSummaryDto>>> getBrokerAccountsGrouped(Long pyId) {
        try {
            PyUser user = pyUserRepository.findById(pyId)
                    .orElseThrow(() -> new RuntimeException("User not found with pyId: " + pyId));
            List<PyBrokerAccountEntity> accounts = user.getRole() == PyUser.Role.SUPER_ADMIN
                    ? pyBrokerAccountRepository.findByActiveTrue()
                    : pyBrokerAccountRepository.findByPyUserIdAndActiveTrue(pyId);

            Map<String, List<PyBrokerAccountSummaryDto>> groupedAccounts = new LinkedHashMap<>();
            for (BrokerType brokerType : BrokerType.values()) {
                groupedAccounts.put(brokerType.name(), new ArrayList<>());
            }
            for (PyBrokerAccountEntity account : accounts) {
                PyBrokerAccountSummaryDto dto = new PyBrokerAccountSummaryDto();
                dto.setBrokerId(account.getId());
                dto.setBrokerClientId(account.getClientId());
                dto.setUserName(account.getUserName());
                dto.setPyId(account.getPyUser().getId());
                dto.setIsActive(account.getActive());
                dto.setIsOwn(account.getIsOwn());
                groupedAccounts.get(account.getBrokerType().name()).add(dto);
            }
            return ApiResponse.success("Broker accounts fetched successfully", groupedAccounts);
        } catch (Exception e) {
            log.error("Failed to fetch grouped broker accounts for pyId={}: {}", pyId, e.getMessage());
            return ApiResponse.error(500, "Failed to fetch broker accounts: " + e.getMessage());
        }
    }

    // ── POSITIONS ─────────────────────────────────────────────────────────────
    @Override
    public JSONObject getPositions(Long accId) {
        PyBrokerAccountEntity account = pyBrokerAccountRepository
                .findById(accId)
                .orElseThrow(() -> new RuntimeException("Account not found: " + accId));

        if (paperTradingService.isPaperTradingEnabled()) {
            List<com.py.trading.entity.PaperPositionEntity> paperPositions = paperTradingEngine.getPositions(accId);
            JSONObject response = new JSONObject();
            response.put("status", true);
            response.put("message", "SUCCESS");
            JSONArray data = new JSONArray();
            for (com.py.trading.entity.PaperPositionEntity pos : paperPositions) {
                JSONObject p = new JSONObject();
                p.put("tradingsymbol", pos.getTradingSymbol());
                p.put("symboltoken", pos.getSymbolToken());
                p.put("exchange", pos.getExchange());
                p.put("producttype", pos.getProductType());
                p.put("netqty", pos.getQuantity());
                p.put("buyavgprice", pos.getAverageBuyPrice());
                p.put("sellavgprice", 0.0);
                p.put("realised", pos.getRealizedPnl());
                double ltp = pos.getLastSimulatedPrice() != null ? pos.getLastSimulatedPrice() : pos.getAverageBuyPrice();
                double unrealised = (ltp - pos.getAverageBuyPrice()) * (pos.getQuantity() != null ? pos.getQuantity() : 0);
                p.put("unrealised", unrealised);
                p.put("ltp", ltp);
                data.put(p);
            }
            response.put("data", data);
            return response;
        }

        String accessToken = pyTokenValidationService.getValidAccessToken(accId);
        if (accessToken == null) throw new RuntimeException(
                "Token unavailable for clientId: " + account.getClientId());

        return switch (account.getBrokerType()) {

            case ANGELONE -> {
                SmartConnect smartConnect = new SmartConnect(account.getSecret().getApiKey());
                smartConnect.setAccessToken(accessToken);
                yield smartConnect.getPosition();
            }

            case PROFITMART -> {
                try {
                    JSONArray result = profitmartClient.getPositions(
                            getBaseUrl(account),
                            account.getClientId(),
                            accessToken).get();
                    JSONObject response = new JSONObject();
                    response.put("status",  true);
                    response.put("message", "SUCCESS");
                    response.put("data",    result != null ? result : new JSONArray());
                    yield response;
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch Profitmart positions: " + e.getMessage(), e);
                }
            }

            case DHAN -> {
                try {
                    JSONObject result = dhanClient.getPositions(
                            getBaseUrl(account),
                            account.getClientId(),
                            accessToken).get();
                    yield result != null ? result : new JSONObject().put("status", true).put("data", new JSONArray());
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch Dhan positions: " + e.getMessage(), e);
                }
            }

            case ZERODHA -> {
                try {
                    String apiKey = account.getSecret() != null ? account.getSecret().getApiKey() : "";
                    JSONObject result = zerodhaClient.getPositions(
                            getBaseUrl(account),
                            account.getClientId(),
                            apiKey,
                            accessToken).get();
                    yield result != null ? result : new JSONObject().put("status", true).put("data", new JSONArray());
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch Zerodha positions: " + e.getMessage(), e);
                }
            }

            case UPSTOX -> {
                try {
                    JSONObject result = upstoxClient.getPositions(
                            getBaseUrl(account),
                            account.getClientId(),
                            accessToken).get();
                    yield result != null ? result : new JSONObject().put("status", true).put("data", new JSONArray());
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch Upstox positions: " + e.getMessage(), e);
                }
            }

            case GOODWILL -> {
                try {
                    JSONObject result = goodwillClient.getPositions(
                            getBaseUrl(account),
                            account.getClientId(),
                            accessToken).get();
                    yield result != null ? result : new JSONObject().put("status", true).put("data", new JSONArray());
                } catch (Exception e) {
                    throw new RuntimeException("Failed to fetch Goodwill positions: " + e.getMessage(), e);
                }
            }

            default -> throw new IllegalArgumentException(
                    "Positions not supported for broker: " + account.getBrokerType());
        };
    }

    // ── MODIFY ORDER ─────────────────────────────────────────────────────────
    @Override
    public Order modifyIndividualOrder(ModifyOrderRequest request) {

        PyBrokerAccountEntity dematAccount = pyBrokerAccountRepository
                .findById(request.getAccId())
                .orElseThrow(() -> new RuntimeException(
                        "Demat account not found: " + request.getAccId()));

        IndividualOrderAuditEntity audit = new IndividualOrderAuditEntity();
        audit.setDematAccountId(dematAccount.getId());
        audit.setClientId(dematAccount.getClientId());
        audit.setUserName(dematAccount.getUserName());
        audit.setTradingSymbol(request.getTradingSymbol());
        audit.setExchange(request.getExchange());
        audit.setQuantity(request.getQuantity());
        audit.setOrderType(request.getOrderType());
        audit.setProductType(request.getProductType());
        audit.setPrice(request.getPrice());
        audit.setTransactionType("MODIFY");
        audit.setVariety(request.getVariety() != null ? request.getVariety() : "NORMAL");
        audit.setSymbolToken(request.getSymbolToken());
        audit.setExecutedAt(LocalDateTime.now());
        audit.setBrokerType(dematAccount.getBrokerType());
        audit.setOrderId(request.getOrderId());

        // ── PAPER TRADING ENGINE / SIMULATED ORDER CHECK ──────────────────
        boolean isSimulatedOrder = (request.getOrderId() != null && request.getOrderId().startsWith("PAPER-SIM-"));
        if (paperTradingService.isPaperTradingEnabled() || isSimulatedOrder) {
            String targetOrderId = request.getOrderId();
            if (targetOrderId == null || targetOrderId.trim().isEmpty()) {
                audit.setStatus("FAILED");
                audit.setRemarks("Order ID is required to modify an order");
                individualOrderAuditRepository.save(audit);
                throw new IllegalArgumentException("Order ID is required to modify an order");
            }

            Optional<IndividualOrderAuditEntity> origOpt = individualOrderAuditRepository
                    .findFirstByOrderIdOrderByExecutedAtDesc(targetOrderId);
            if (origOpt.isEmpty()) {
                audit.setStatus("FAILED");
                audit.setRemarks("Simulated order not found: " + targetOrderId);
                individualOrderAuditRepository.save(audit);
                throw new IllegalArgumentException("Simulated order not found: " + targetOrderId);
            }

            IndividualOrderAuditEntity origOrder = origOpt.get();
            if (!dematAccount.getId().equals(origOrder.getDematAccountId())) {
                audit.setStatus("FAILED");
                audit.setRemarks("Order does not belong to demat account: " + dematAccount.getId());
                individualOrderAuditRepository.save(audit);
                throw new SecurityException("Order " + targetOrderId + " does not belong to demat account " + dematAccount.getId());
            }

            String status = origOrder.getStatus() != null ? origOrder.getStatus().toUpperCase() : "";
            if ("SUCCESS".equals(status) || "COMPLETE".equals(status)) {
                audit.setStatus("FAILED");
                audit.setRemarks("Cannot modify simulated order: order is already executed / filled");
                individualOrderAuditRepository.save(audit);
                throw new IllegalStateException("Cannot modify order " + targetOrderId + ": simulated order is already executed / filled");
            }
            if ("CANCELLED".equals(status)) {
                audit.setStatus("FAILED");
                audit.setRemarks("Cannot modify simulated order: order is already cancelled");
                individualOrderAuditRepository.save(audit);
                throw new IllegalStateException("Cannot modify order " + targetOrderId + ": simulated order is already cancelled");
            }
            if ("FAILED".equals(status) || "REJECTED".equals(status)) {
                audit.setStatus("FAILED");
                audit.setRemarks("Cannot modify simulated order: order is in terminal state (" + status + ")");
                individualOrderAuditRepository.save(audit);
                throw new IllegalStateException("Cannot modify order " + targetOrderId + ": simulated order is in terminal state (" + status + ")");
            }

            if ("OPEN".equals(status) || "PENDING".equals(status)) {
                if (request.getPrice() != null && request.getPrice() > 0) {
                    origOrder.setPrice(request.getPrice());
                }
                if (request.getQuantity() != null && request.getQuantity() > 0) {
                    origOrder.setQuantity(request.getQuantity());
                }
                origOrder.setRemarks("SIMULATED MODIFY - Updated at " + LocalDateTime.now());
                individualOrderAuditRepository.save(origOrder);

                audit.setStatus("SUCCESS");
                audit.setRemarks("SIMULATED ORDER MODIFIED");
                individualOrderAuditRepository.save(audit);

                Order o = new Order();
                o.orderId = targetOrderId;
                return o;
            }

            audit.setStatus("FAILED");
            audit.setRemarks("Cannot modify simulated order with status: " + status);
            individualOrderAuditRepository.save(audit);
            throw new IllegalStateException("Cannot modify order " + targetOrderId + " with status: " + status);
        }

        // ── LIVE TRADING SAFEGUARD ───────────────────────────────────────
        paperTradingService.validateLiveOrderAllowed();

        try {
            PyBrokerSecret secret = dematAccount.getSecret();
            if (secret == null) {
                audit.setStatus("FAILED");
                audit.setRemarks("No API credentials found");
                individualOrderAuditRepository.save(audit);
                throw new RuntimeException("No API credentials found for: " + dematAccount.getClientId());
            }

            String accessToken = pyTokenValidationService.getValidAccessToken(dematAccount.getId());
            if (accessToken == null) {
                audit.setStatus("FAILED");
                audit.setRemarks("Token unavailable — account deactivated");
                individualOrderAuditRepository.save(audit);
                throw new RuntimeException("Token unavailable for clientId: " + dematAccount.getClientId());
            }

            return switch (dematAccount.getBrokerType()) {

                case ANGELONE -> {
                    AngelOneModifyOrderRequest modifyRequest = new AngelOneModifyOrderRequest();
                    modifyRequest.setApiKey(secret.getApiKey());
                    modifyRequest.setAccessToken(accessToken);
                    modifyRequest.setOrderId(request.getOrderId());
                    modifyRequest.setExchange(request.getExchange());
                    modifyRequest.setTradingSymbol(request.getTradingSymbol());
                    modifyRequest.setSymbolToken(request.getSymbolToken());
                    modifyRequest.setOrderType(request.getOrderType());
                    modifyRequest.setProductType(request.getProductType());
                    modifyRequest.setQuantity(request.getQuantity());
                    modifyRequest.setPrice(request.getPrice());
                    modifyRequest.setDuration(request.getDuration() != null ? request.getDuration() : "DAY");
                    modifyRequest.setTriggerPrice(request.getTriggerPrice());
                    modifyRequest.setVariety(request.getVariety() != null ? request.getVariety() : "NORMAL");

                    log.info("Modifying AngelOne order | clientId={} orderId={} symbol={}",
                            dematAccount.getClientId(), request.getOrderId(), request.getTradingSymbol());

                    JSONObject response = angelOneClient.modifyOrder(getBaseUrl(dematAccount), modifyRequest).get();
                    String orderId = response.optString("orderId");
                    if (orderId == null || orderId.isEmpty()) {
                        audit.setStatus("FAILED");
                        audit.setRemarks("Null response from broker on modify");
                        individualOrderAuditRepository.save(audit);
                        throw new RuntimeException("Modify order failed — null response from broker");
                    }
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderId);
                    audit.setRemarks("MODIFIED");
                    individualOrderAuditRepository.save(audit);
                    log.info("AngelOne modify order SUCCESS | clientId={} orderId={}", dematAccount.getClientId(), orderId);
                    Order o1 = new Order();
                    o1.orderId = orderId;
                    yield o1;
                }

                case MOTILAL -> {
                    log.info("Modifying Motilal order | clientId={} orderId={}", dematAccount.getClientId(), request.getOrderId());
                    PyBrokerToken tokenEntity = dematAccount.getToken();
                    if (tokenEntity == null) {
                        audit.setStatus("FAILED");
                        audit.setRemarks("No Motilal token found");
                        individualOrderAuditRepository.save(audit);
                        throw new RuntimeException("No Motilal token for: " + dematAccount.getClientId());
                    }
                    String authToken = tokenEntity.getRefreshToken();
                    JSONObject ordersResponse = motilalClient.getOrderHistory(
                            getBaseUrl(dematAccount),
                            secret.getApiKey(), secret.getApiSecret(),
                            secret.getVenderInfo(), authToken, accessToken).get();
                    JSONArray orderData = ordersResponse.optJSONArray("data");
                    if (orderData == null) {
                        audit.setStatus("FAILED");
                        audit.setRemarks("Empty order book from Motilal");
                        individualOrderAuditRepository.save(audit);
                        throw new RuntimeException("Empty order book from Motilal for: " + dematAccount.getClientId());
                    }
                    String lastModifiedTime = null;
                    int qtyTradedToday = 0;
                    for (int i = 0; i < orderData.length(); i++) {
                        JSONObject o = orderData.getJSONObject(i);
                        if (request.getOrderId().equals(o.optString("uniqueorderid"))) {
                            lastModifiedTime = o.optString("lastmodifiedtime", "0");
                            qtyTradedToday   = o.optInt("qtytradedtoday", 0);
                            break;
                        }
                    }
                    if (lastModifiedTime == null) {
                        audit.setStatus("FAILED");
                        audit.setRemarks("Order not found in Motilal order book: " + request.getOrderId());
                        individualOrderAuditRepository.save(audit);
                        throw new RuntimeException("Order not found in Motilal order book: " + request.getOrderId());
                    }
                    String resolvedOrderType = request.getOrderType();
                    double resolvedPrice     = request.getPrice();
                    if ("MARKET".equalsIgnoreCase(resolvedOrderType)) {
                        JSONObject ltpData = motilalClient.getLtp(
                                getBaseUrl(dematAccount),
                                secret.getApiKey(), secret.getApiSecret(),
                                secret.getVenderInfo(), authToken, accessToken,
                                request.getExchange(), Long.parseLong(request.getSymbolToken()));
                        double ltp = ltpData.optDouble("ltp", 0.0) / 100.0;
                        if (ltp <= 0) {
                            audit.setStatus("FAILED");
                            audit.setRemarks("Could not fetch LTP for MARKET→LIMIT conversion");
                            individualOrderAuditRepository.save(audit);
                            throw new RuntimeException("Could not fetch live LTP for: " + request.getTradingSymbol());
                        }
                        resolvedOrderType = "LIMIT";
                        resolvedPrice     = ltp;
                        log.info("Motilal MODIFY MARKET→LIMIT | symbol={} ltp=₹{}", request.getTradingSymbol(), ltp);
                    }
                    MotilalModifyOrderRequest modifyRequest = new MotilalModifyOrderRequest();
                    modifyRequest.setApiKey(secret.getApiKey());
                    modifyRequest.setApiSecret(secret.getApiSecret());
                    modifyRequest.setVendorInfo(secret.getVenderInfo());
                    modifyRequest.setAuthToken(authToken);
                    modifyRequest.setAccessToken(accessToken);
                    modifyRequest.setUniqueOrderId(request.getOrderId());
                    modifyRequest.setNewOrderType(resolvedOrderType);
                    modifyRequest.setNewOrderDuration(request.getDuration() != null ? request.getDuration() : "DAY");
                    modifyRequest.setNewPrice(resolvedPrice);
                    modifyRequest.setNewTriggerPrice(request.getTriggerPrice());
                    modifyRequest.setNewQuantityInLot(request.getQuantity());
                    modifyRequest.setLastModifiedTime(lastModifiedTime);
                    modifyRequest.setQtyTradedToday(qtyTradedToday);
                    JSONObject response = motilalClient.modifyOrder(getBaseUrl(dematAccount), modifyRequest).get();
                    String uniqueOrderId = response.optString("uniqueorderid", request.getOrderId());
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(uniqueOrderId);
                    audit.setRemarks("MODIFIED");
                    individualOrderAuditRepository.save(audit);
                    log.info("Motilal modify order SUCCESS | clientId={} orderId={}", dematAccount.getClientId(), uniqueOrderId);
                    Order o2 = new Order();
                    o2.orderId = uniqueOrderId;
                    yield o2;
                }

                case DHAN -> {
                    log.info("Modifying Dhan order | clientId={} orderId={}", dematAccount.getClientId(), request.getOrderId());
                    DhanModifyOrderRequest modifyRequest = new DhanModifyOrderRequest();
                    modifyRequest.setClientId(dematAccount.getClientId());
                    modifyRequest.setAccessToken(accessToken);
                    modifyRequest.setDhanClientId(dematAccount.getClientId());
                    modifyRequest.setOrderId(request.getOrderId());
                    modifyRequest.setOrderType(toDhanOrderType(request.getOrderType()));
                    modifyRequest.setQuantity(request.getQuantity());
                    modifyRequest.setValidity("DAY");
                    modifyRequest.setDisclosedQuantity(0);
                    modifyRequest.setPrice(request.getPrice());
                    modifyRequest.setTriggerPrice(request.getTriggerPrice() != null ? request.getTriggerPrice() : 0.0);
                    JSONObject response = dhanClient.modifyOrder(getBaseUrl(dematAccount), modifyRequest).get();
                    String orderId = response.optString("orderId", request.getOrderId());
                    if (orderId == null || orderId.isEmpty()) {
                        audit.setStatus("FAILED");
                        audit.setRemarks("Null response from Dhan on modify");
                        individualOrderAuditRepository.save(audit);
                        throw new RuntimeException("Modify order failed — null response from Dhan");
                    }
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderId);
                    audit.setRemarks("MODIFIED");
                    individualOrderAuditRepository.save(audit);
                    log.info("Dhan modify order SUCCESS | clientId={} orderId={}", dematAccount.getClientId(), orderId);
                    Order o3 = new Order();
                    o3.orderId = orderId;
                    yield o3;
                }

                case PROFITMART -> {
                    log.info("Modifying Profitmart order | clientId={} orderNo={}", dematAccount.getClientId(), request.getOrderId());
                    JSONObject response = profitmartClient.modifyOrder(
                            getBaseUrl(dematAccount),
                            dematAccount.getClientId(),
                            accessToken,
                            request.getOrderId(),
                            request.getExchange(),
                            request.getTradingSymbol(),
                            request.getQuantity(),
                            request.getOrderType(),
                            request.getPrice(),
                            request.getTriggerPrice(),
                            request.getDuration() != null ? request.getDuration() : "DAY",
                            "No").get();
                    String orderNo = response.optString("result", request.getOrderId());
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderNo);
                    audit.setRemarks("MODIFIED");
                    individualOrderAuditRepository.save(audit);
                    log.info("Profitmart modify order SUCCESS | clientId={} orderNo={}", dematAccount.getClientId(), orderNo);
                    Order o4 = new Order();
                    o4.orderId = orderNo;
                    yield o4;
                }

                case UPSTOX -> {
                    Map<String, Object> payload = new HashMap<>();
                    payload.put("clientId", dematAccount.getClientId());
                    payload.put("accessToken", accessToken);
                    payload.put("orderId", request.getOrderId());
                    payload.put("quantity", request.getQuantity());
                    payload.put("price", request.getPrice());
                    payload.put("orderType", request.getOrderType());
                    payload.put("triggerPrice", request.getTriggerPrice());
                    payload.put("validity", request.getDuration() != null ? request.getDuration() : "DAY");
                    JSONObject response = upstoxClient.modifyOrder(getBaseUrl(dematAccount), payload).get();
                    String orderId = response.optString("orderId", request.getOrderId());
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderId);
                    audit.setRemarks("MODIFIED");
                    individualOrderAuditRepository.save(audit);
                    Order o = new Order();
                    o.orderId = orderId;
                    yield o;
                }

                case ZERODHA -> {
                    Map<String, Object> payload = new HashMap<>();
                    payload.put("clientId", dematAccount.getClientId());
                    payload.put("apiKey", secret.getApiKey());
                    payload.put("accessToken", accessToken);
                    payload.put("orderId", request.getOrderId());
                    payload.put("quantity", request.getQuantity());
                    payload.put("price", request.getPrice());
                    payload.put("orderType", request.getOrderType());
                    payload.put("triggerPrice", request.getTriggerPrice());
                    payload.put("validity", request.getDuration() != null ? request.getDuration() : "DAY");
                    JSONObject response = zerodhaClient.modifyOrder(getBaseUrl(dematAccount), payload).get();
                    String orderId = response.optString("orderId", request.getOrderId());
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderId);
                    audit.setRemarks("MODIFIED");
                    individualOrderAuditRepository.save(audit);
                    Order o = new Order();
                    o.orderId = orderId;
                    yield o;
                }

                case GOODWILL -> {
                    Map<String, Object> payload = new HashMap<>();
                    payload.put("clientId", dematAccount.getClientId());
                    payload.put("accessToken", accessToken);
                    payload.put("appOrderId", request.getOrderId());
                    payload.put("orderQuantity", request.getQuantity());
                    payload.put("limitPrice", request.getPrice());
                    payload.put("orderType", request.getOrderType());
                    payload.put("stopPrice", request.getTriggerPrice());
                    JSONObject response = goodwillClient.modifyOrder(getBaseUrl(dematAccount), payload).get();
                    String orderId = response.optString("orderId", request.getOrderId());
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderId);
                    audit.setRemarks("MODIFIED");
                    individualOrderAuditRepository.save(audit);
                    Order o = new Order();
                    o.orderId = orderId;
                    yield o;
                }

                default -> {
                    audit.setStatus("FAILED");
                    audit.setRemarks("Broker not supported: " + dematAccount.getBrokerType());
                    individualOrderAuditRepository.save(audit);
                    throw new RuntimeException("Modify order not yet implemented for broker: "
                            + dematAccount.getBrokerType());
                }
            };

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            audit.setStatus("FAILED");
            audit.setRemarks(e.getMessage());
            individualOrderAuditRepository.save(audit);
            log.error("Modify order failed | clientId={} orderId={} error={}",
                    dematAccount.getClientId(), request.getOrderId(), e.getMessage());
            throw new RuntimeException("Modify order failed: " + e.getMessage());
        }
    }

    // ── CANCEL ORDER ─────────────────────────────────────────────────────────
    @Override
    public Order cancelIndividualOrder(CancelOrderRequest request) {

        PyBrokerAccountEntity dematAccount = pyBrokerAccountRepository
                .findById(request.getAccId())
                .orElseThrow(() -> new RuntimeException(
                        "Demat account not found: " + request.getAccId()));

        IndividualOrderAuditEntity audit = new IndividualOrderAuditEntity();
        audit.setDematAccountId(dematAccount.getId());
        audit.setClientId(dematAccount.getClientId());
        audit.setUserName(dematAccount.getUserName());
        audit.setTransactionType("CANCEL");
        audit.setVariety(request.getVariety() != null ? request.getVariety() : "NORMAL");
        audit.setExecutedAt(LocalDateTime.now());
        audit.setBrokerType(dematAccount.getBrokerType());
        audit.setOrderId(request.getOrderId());

        // ── PAPER TRADING ENGINE / SIMULATED ORDER CHECK ──────────────────
        boolean isSimulatedOrder = (request.getOrderId() != null && request.getOrderId().startsWith("PAPER-SIM-"));
        if (paperTradingService.isPaperTradingEnabled() || isSimulatedOrder) {
            String targetOrderId = request.getOrderId();
            if (targetOrderId == null || targetOrderId.trim().isEmpty()) {
                audit.setStatus("FAILED");
                audit.setRemarks("Order ID is required to cancel an order");
                individualOrderAuditRepository.save(audit);
                throw new IllegalArgumentException("Order ID is required to cancel an order");
            }

            Optional<IndividualOrderAuditEntity> origOpt = individualOrderAuditRepository
                    .findFirstByOrderIdOrderByExecutedAtDesc(targetOrderId);
            if (origOpt.isEmpty()) {
                audit.setStatus("FAILED");
                audit.setRemarks("Simulated order not found: " + targetOrderId);
                individualOrderAuditRepository.save(audit);
                throw new IllegalArgumentException("Simulated order not found: " + targetOrderId);
            }

            IndividualOrderAuditEntity origOrder = origOpt.get();
            if (!dematAccount.getId().equals(origOrder.getDematAccountId())) {
                audit.setStatus("FAILED");
                audit.setRemarks("Order does not belong to demat account: " + dematAccount.getId());
                individualOrderAuditRepository.save(audit);
                throw new SecurityException("Order " + targetOrderId + " does not belong to demat account " + dematAccount.getId());
            }

            String status = origOrder.getStatus() != null ? origOrder.getStatus().toUpperCase() : "";
            if ("SUCCESS".equals(status) || "COMPLETE".equals(status)) {
                audit.setStatus("FAILED");
                audit.setRemarks("Cannot cancel simulated order: order is already executed / filled");
                individualOrderAuditRepository.save(audit);
                throw new IllegalStateException("Cannot cancel order " + targetOrderId + ": simulated order is already executed / filled");
            }
            if ("CANCELLED".equals(status)) {
                audit.setStatus("FAILED");
                audit.setRemarks("Cannot cancel simulated order: order is already cancelled");
                individualOrderAuditRepository.save(audit);
                throw new IllegalStateException("Cannot cancel order " + targetOrderId + ": simulated order is already cancelled");
            }
            if ("FAILED".equals(status) || "REJECTED".equals(status)) {
                audit.setStatus("FAILED");
                audit.setRemarks("Cannot cancel simulated order: order is in terminal state (" + status + ")");
                individualOrderAuditRepository.save(audit);
                throw new IllegalStateException("Cannot cancel order " + targetOrderId + ": simulated order is in terminal state (" + status + ")");
            }

            if ("OPEN".equals(status) || "PENDING".equals(status)) {
                origOrder.setStatus("CANCELLED");
                origOrder.setRemarks("SIMULATED CANCEL - Cancelled by user at " + LocalDateTime.now());
                individualOrderAuditRepository.save(origOrder);

                audit.setStatus("SUCCESS");
                audit.setRemarks("SIMULATED ORDER CANCELLED");
                individualOrderAuditRepository.save(audit);

                Order o = new Order();
                o.orderId = targetOrderId;
                return o;
            }

            audit.setStatus("FAILED");
            audit.setRemarks("Cannot cancel simulated order with status: " + status);
            individualOrderAuditRepository.save(audit);
            throw new IllegalStateException("Cannot cancel order " + targetOrderId + " with status: " + status);
        }

        // ── LIVE TRADING SAFEGUARD ───────────────────────────────────────
        paperTradingService.validateLiveOrderAllowed();

        try {
            PyBrokerSecret secret = dematAccount.getSecret();
            if (secret == null) {
                audit.setStatus("FAILED");
                audit.setRemarks("No API credentials found");
                individualOrderAuditRepository.save(audit);
                throw new RuntimeException("No API credentials found for: " + dematAccount.getClientId());
            }

            String accessToken = pyTokenValidationService.getValidAccessToken(dematAccount.getId());
            if (accessToken == null) {
                audit.setStatus("FAILED");
                audit.setRemarks("Token unavailable — account deactivated");
                individualOrderAuditRepository.save(audit);
                throw new RuntimeException("Token unavailable for clientId: " + dematAccount.getClientId());
            }

            return switch (dematAccount.getBrokerType()) {

                case ANGELONE -> {
                    String variety = request.getVariety() != null ? request.getVariety() : "NORMAL";
                    log.info("Cancelling AngelOne order | clientId={} orderId={}", dematAccount.getClientId(), request.getOrderId());
                    AngelOneCancelOrderRequest cancelRequest = new AngelOneCancelOrderRequest();
                    cancelRequest.setApiKey(secret.getApiKey());
                    cancelRequest.setAccessToken(accessToken);
                    cancelRequest.setOrderId(request.getOrderId());
                    cancelRequest.setVariety(variety);
                    JSONObject response = angelOneClient.cancelOrder(getBaseUrl(dematAccount), cancelRequest).get();
                    String orderId = response.optString("orderId");
                    if (orderId == null || orderId.isEmpty()) {
                        audit.setStatus("FAILED");
                        audit.setRemarks("Null response from broker on cancel");
                        individualOrderAuditRepository.save(audit);
                        throw new RuntimeException("Cancel order failed — null response from broker");
                    }
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderId);
                    audit.setRemarks("CANCELLED");
                    individualOrderAuditRepository.save(audit);
                    log.info("AngelOne cancel order SUCCESS | clientId={} orderId={}", dematAccount.getClientId(), orderId);
                    Order o1 = new Order();
                    o1.orderId = orderId;
                    yield o1;
                }

                case MOTILAL -> {
                    log.info("Cancelling Motilal order | clientId={} orderId={}", dematAccount.getClientId(), request.getOrderId());
                    PyBrokerToken tokenEntity = dematAccount.getToken();
                    if (tokenEntity == null) {
                        audit.setStatus("FAILED");
                        audit.setRemarks("No Motilal token found");
                        individualOrderAuditRepository.save(audit);
                        throw new RuntimeException("No Motilal token for: " + dematAccount.getClientId());
                    }
                    MotilalCancelOrderRequest cancelRequest = new MotilalCancelOrderRequest();
                    cancelRequest.setApiKey(secret.getApiKey());
                    cancelRequest.setApiSecret(secret.getApiSecret());
                    cancelRequest.setVendorInfo(secret.getVenderInfo());
                    cancelRequest.setAuthToken(tokenEntity.getRefreshToken());
                    cancelRequest.setAccessToken(accessToken);
                    cancelRequest.setUniqueOrderId(request.getOrderId());
                    JSONObject response = motilalClient.cancelOrder(getBaseUrl(dematAccount), cancelRequest).get();
                    String uniqueOrderId = response.optString("uniqueorderid", request.getOrderId());
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(uniqueOrderId);
                    audit.setRemarks("CANCELLED");
                    individualOrderAuditRepository.save(audit);
                    log.info("Motilal cancel order SUCCESS | clientId={} orderId={}", dematAccount.getClientId(), uniqueOrderId);
                    Order o2 = new Order();
                    o2.orderId = uniqueOrderId;
                    yield o2;
                }

                case DHAN -> {
                    log.info("Cancelling Dhan order | clientId={} orderId={}", dematAccount.getClientId(), request.getOrderId());
                    DhanCancelOrderRequest cancelRequest = new DhanCancelOrderRequest();
                    cancelRequest.setClientId(dematAccount.getClientId());
                    cancelRequest.setAccessToken(accessToken);
                    cancelRequest.setOrderId(request.getOrderId());
                    JSONObject response = dhanClient.cancelOrder(getBaseUrl(dematAccount), cancelRequest).get();
                    String orderId    = response.optString("orderId",     request.getOrderId());
                    String orderStatus = response.optString("orderStatus", "");
                    if ("FAILED".equals(orderStatus)) {
                        audit.setStatus("FAILED");
                        audit.setRemarks("Dhan cancel failed: " + response.optString("errorBody", ""));
                        individualOrderAuditRepository.save(audit);
                        throw new RuntimeException("Cancel order failed for Dhan orderId: " + request.getOrderId());
                    }
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderId);
                    audit.setRemarks("CANCELLED");
                    individualOrderAuditRepository.save(audit);
                    log.info("Dhan cancel order SUCCESS | clientId={} orderId={}", dematAccount.getClientId(), orderId);
                    Order o3 = new Order();
                    o3.orderId = orderId;
                    yield o3;
                }

                case PROFITMART -> {
                    log.info("Cancelling Profitmart order | clientId={} orderNo={}", dematAccount.getClientId(), request.getOrderId());
                    JSONObject response = profitmartClient.cancelOrder(
                            getBaseUrl(dematAccount),
                            dematAccount.getClientId(),
                            accessToken,
                            request.getOrderId()).get();
                    String orderNo = response.optString("result", request.getOrderId());
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderNo);
                    audit.setRemarks("CANCELLED");
                    individualOrderAuditRepository.save(audit);
                    log.info("Profitmart cancel order SUCCESS | clientId={} orderNo={}", dematAccount.getClientId(), orderNo);
                    Order o4 = new Order();
                    o4.orderId = orderNo;
                    yield o4;
                }

                case UPSTOX -> {
                    Map<String, Object> payload = new HashMap<>();
                    payload.put("clientId", dematAccount.getClientId());
                    payload.put("accessToken", accessToken);
                    payload.put("orderId", request.getOrderId());
                    JSONObject response = upstoxClient.cancelOrder(getBaseUrl(dematAccount), payload).get();
                    String orderId = response.optString("orderId", request.getOrderId());
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderId);
                    audit.setRemarks("CANCELLED");
                    individualOrderAuditRepository.save(audit);
                    Order o = new Order();
                    o.orderId = orderId;
                    yield o;
                }

                case ZERODHA -> {
                    Map<String, Object> payload = new HashMap<>();
                    payload.put("clientId", dematAccount.getClientId());
                    payload.put("apiKey", secret.getApiKey());
                    payload.put("accessToken", accessToken);
                    payload.put("orderId", request.getOrderId());
                    JSONObject response = zerodhaClient.cancelOrder(getBaseUrl(dematAccount), payload).get();
                    String orderId = response.optString("orderId", request.getOrderId());
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderId);
                    audit.setRemarks("CANCELLED");
                    individualOrderAuditRepository.save(audit);
                    Order o = new Order();
                    o.orderId = orderId;
                    yield o;
                }

                case GOODWILL -> {
                    Map<String, Object> payload = new HashMap<>();
                    payload.put("clientId", dematAccount.getClientId());
                    payload.put("accessToken", accessToken);
                    payload.put("appOrderId", request.getOrderId());
                    JSONObject response = goodwillClient.cancelOrder(getBaseUrl(dematAccount), payload).get();
                    String orderId = response.optString("orderId", request.getOrderId());
                    audit.setStatus("SUCCESS");
                    audit.setOrderId(orderId);
                    audit.setRemarks("CANCELLED");
                    individualOrderAuditRepository.save(audit);
                    Order o = new Order();
                    o.orderId = orderId;
                    yield o;
                }

                default -> throw new RuntimeException(
                        "Cancel order not yet implemented for broker: " + dematAccount.getBrokerType());
            };

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            audit.setStatus("FAILED");
            audit.setRemarks(e.getMessage());
            individualOrderAuditRepository.save(audit);
            log.error("Cancel order failed | clientId={} orderId={} error={}",
                    dematAccount.getClientId(), request.getOrderId(), e.getMessage());
            throw new RuntimeException("Cancel order failed: " + e.getMessage());
        }
    }

    // ── VALIDATE IP ───────────────────────────────────────────────────────────
    @Override
    public ApiResponse<?> validateIpConfig(String ipAddress, BrokerType brokerType) {
        return pyBrokerIpConfigService.validateIpForAccount(ipAddress, brokerType);
    }

    // ── EXCHANGE CONVERTERS ───────────────────────────────────────────────────
    private String toDhanExchange(String exchange) {
        return switch (exchange.toUpperCase()) {
            case "NSE" -> "NSE_EQ";
            case "BSE" -> "BSE_EQ";
            case "NFO" -> "NSE_FNO";
            case "BFO" -> "BSE_FNO";
            case "CDS" -> "NSE_CURRENCY";
            case "MCX" -> "MCX_COMM";
            default    -> exchange;
        };
    }

    private String toDhanProductType(String productType) {
        return switch (productType.toUpperCase()) {
            case "DELIVERY", "CNC"      -> "CNC";
            case "INTRADAY", "MIS"      -> "INTRADAY";
            case "MARGIN"               -> "MARGIN";
            case "CARRYFORWARD", "MTF"  -> "MTF";
            default                     -> "INTRADAY";
        };
    }

    private String toDhanOrderType(String orderType) {
        return switch (orderType.toUpperCase()) {
            case "MARKET"                    -> "MARKET";
            case "LIMIT"                     -> "LIMIT";
            case "STOPLOSS_LIMIT", "SL"      -> "STOP_LOSS";
            case "STOPLOSS_MARKET", "SL-M"   -> "STOP_LOSS_MARKET";
            default                          -> "MARKET";
        };
    }

    // ── LTP ───────────────────────────────────────────────────────────────────
    @Override
    public JSONObject getLTP(Long pyUserId, String exchange,
            String tradingSymbol, String symbolToken) {

        List<PyBrokerAccountEntity> accounts = pyBrokerAccountRepository
                .findByPyUserIdAndActiveTrue(pyUserId);
        if (accounts.isEmpty()) throw new RuntimeException(
                "No active broker accounts found for pyUserId: " + pyUserId);

        List<BrokerType> priority = List.of(
                BrokerType.ANGELONE,
                BrokerType.MOTILAL,
                BrokerType.DHAN,
                BrokerType.PROFITMART,
                BrokerType.UPSTOX);

        for (BrokerType brokerType : priority) {
            Optional<PyBrokerAccountEntity> accountOpt = accounts.stream()
                    .filter(a -> a.getBrokerType().equals(brokerType))
                    .findFirst();
            if (accountOpt.isEmpty()) continue;

            PyBrokerAccountEntity account = accountOpt.get();
            String accessToken = pyTokenValidationService.getValidAccessToken(account.getId());
            if (accessToken == null) {
                log.warn("Token invalid for broker={} clientId={} — trying next", brokerType, account.getClientId());
                continue;
            }
            try {
                return fetchLTP(account, accessToken, exchange, tradingSymbol, symbolToken);
            } catch (Exception e) {
                log.warn("LTP failed for broker={} clientId={}: {} — trying next",
                        brokerType, account.getClientId(), e.getMessage());
            }
        }

        log.warn("All brokers failed for LTP | pyUserId={} symbol={} — falling back to Groww", pyUserId, tradingSymbol);
        return growwPriceService.getLTP(tradingSymbol);
    }

    private JSONObject fetchLTP(PyBrokerAccountEntity account, String accessToken,
            String exchange, String tradingSymbol, String symbolToken) throws Exception {

        return switch (account.getBrokerType()) {

            case ANGELONE -> {
                JSONObject result = angelOneClient.getLTP(
                        getBaseUrl(account),
                        account.getSecret().getApiKey(),
                        accessToken, exchange, tradingSymbol, symbolToken).get();
                JSONObject data = new JSONObject();
                data.put("exchange",      result.optString("exchange", exchange));
                data.put("tradingsymbol", result.optString("tradingsymbol", tradingSymbol));
                data.put("ltp",           result.optDouble("ltp", 0));
                data.put("brokerUsed",    "ANGELONE");
                yield data;
            }

            case MOTILAL -> {
                JSONObject result = motilalClient.getLtp(
                        getBaseUrl(account),
                        account.getSecret().getApiKey(),
                        account.getSecret().getApiSecret(),
                        account.getSecret().getVenderInfo(),
                        account.getToken().getRefreshToken(),
                        accessToken, exchange, Long.parseLong(symbolToken));
                JSONObject data = new JSONObject();
                data.put("exchange",      exchange);
                data.put("tradingsymbol", tradingSymbol);
                data.put("ltp",           result.optDouble("ltp", 0) / 100.0);
                data.put("brokerUsed",    "MOTILAL");
                yield data;
            }

            case PROFITMART -> {
                JSONObject result = profitmartClient.getQuotes(
                        getBaseUrl(account),
                        account.getClientId(),
                        accessToken, exchange, symbolToken).get();
                JSONObject data = new JSONObject();
                data.put("exchange",      exchange);
                data.put("tradingsymbol", tradingSymbol);
                data.put("ltp",           result.optDouble("lp", 0));
                data.put("brokerUsed",    "PROFITMART");
                yield data;
            }

            default -> growwPriceService.getLTP(tradingSymbol);
        };
    }

    // ── RMS DTO MAPPER ────────────────────────────────────────────────────────
    public BrokerRmsDto mapToRmsDto(BrokerType brokerType, JSONObject rmsData) {
        BrokerRmsDto rms = new BrokerRmsDto();
        if (rmsData == null) return rms;

        switch (brokerType) {

            case ANGELONE -> {
                rms.setAvailableCash(       Double.valueOf(rmsData.optString("availablecash",       "0")));
                rms.setCollateral(          Double.valueOf(rmsData.optString("collateral",          "0")));
                rms.setUtilizedAmount(      Double.valueOf(rmsData.optString("utiliseddebits",      "0")));
                rms.setWithdrawableBalance( Double.valueOf(rmsData.optString("net",                 "0")));
                rms.setAvailableFno(        Double.valueOf(rmsData.optString("availablelimitmargin","0")));
                double m2mR = parseDouble(rmsData.optString("m2mrealized",   "0"));
                double m2mU = parseDouble(rmsData.optString("m2munrealized", "0"));
                rms.setTotalPnl(m2mR + m2mU);
            }

            case MOTILAL -> {
                JSONArray data = rmsData.optJSONArray("data");
                if (data != null) {
                    for (int i = 0; i < data.length(); i++) {
                        JSONObject item = data.getJSONObject(i);
                        int    srno = item.optInt("srno",   -1);
                        double amt  = item.optDouble("amount", 0);
                        switch (srno) {
                            case 102 -> rms.setAvailableCash(amt);
                            case 103 -> rms.setAvailableFno(amt);
                            case 301 -> rms.setUtilizedAmount(amt);
                            case 600 -> rms.setTotalPnl(amt);
                        }
                    }
                }
            }

            case DHAN -> {
                rms.setAvailableCash(      rmsData.optDouble("availabelBalance",    0));
                rms.setCollateral(         rmsData.optDouble("collateralAmount",    0));
                rms.setUtilizedAmount(     rmsData.optDouble("utilizedAmount",      0));
                rms.setWithdrawableBalance(rmsData.optDouble("withdrawableBalance", 0));
            }

            case PROFITMART -> {
                rms.setAvailableCash(      parseDouble(rmsData.optString("cash",        "0")));
                rms.setCollateral(         parseDouble(rmsData.optString("brkcollamt",  "0")));
                rms.setUtilizedAmount(     parseDouble(rmsData.optString("blk_amt",     "0")));
                rms.setWithdrawableBalance(parseDouble(rmsData.optString("payin",       "0")));
                rms.setAvailableFno(       parseDouble(rmsData.optString("turnoverlmt", "0")));
            }

            case ZERODHA -> {
                rms.setAvailableCash(Double.valueOf(rmsData.optString("availablecash", "0")));
                JSONObject data = rmsData.optJSONObject("data");
                if (data != null) {
                    JSONObject equity = data.optJSONObject("equity");
                    if (equity != null) {
                        rms.setCollateral(equity.optDouble("collateral", 0.0));
                        rms.setUtilizedAmount(equity.optDouble("utilised", 0.0));
                        rms.setWithdrawableBalance(equity.optDouble("net", 0.0));
                    }
                }
            }

            case UPSTOX -> {
                rms.setAvailableCash(Double.valueOf(rmsData.optString("availablecash", "0")));
                JSONObject data = rmsData.optJSONObject("data");
                if (data != null) {
                    JSONObject equity = data.optJSONObject("equity");
                    if (equity != null) {
                        rms.setUtilizedAmount(equity.optDouble("used_margin", 0.0));
                        rms.setWithdrawableBalance(equity.optDouble("payin_amount", 0.0));
                    }
                }
            }

            case GOODWILL -> {
                rms.setAvailableCash(Double.valueOf(rmsData.optString("availablecash", "0")));
            }

            default -> log.warn("RMS mapping not implemented for broker={}", brokerType);
        }

        return rms;
    }

    // ── CONVERT POSITION ─────────────────────────────────────────────────────
    @Override
    public JSONObject convertPosition(Long accId, ConvertPositionRequest request) {

        PyBrokerAccountEntity account = pyBrokerAccountRepository
                .findById(accId)
                .orElseThrow(() -> new RuntimeException("Account not found: " + accId));

        if (paperTradingService.isPaperTradingEnabled()) {
            throw new UnsupportedOperationException("Position conversion is not supported in paper trading mode.");
        }

        paperTradingService.validateLiveOrderAllowed();

        String accessToken = pyTokenValidationService.getValidAccessToken(accId);
        if (accessToken == null) throw new RuntimeException(
                "Token unavailable for clientId: " + account.getClientId());

        switch (account.getBrokerType()) {

            case ANGELONE -> {
                PyBrokerSecret secret = account.getSecret();
                if (secret == null) throw new RuntimeException(
                        "No API credentials found for: " + account.getClientId());
                log.info("AngelOne convert position | clientId={} symbol={} {} -> {}",
                        account.getClientId(), request.getTradingsymbol(),
                        request.getOldproducttype(), request.getNewproducttype());
                AngelOneConvertPositionRequest convertRequest = new AngelOneConvertPositionRequest();
                convertRequest.setApiKey(secret.getApiKey());
                convertRequest.setAccessToken(accessToken);
                convertRequest.setExchange(request.getExchange());
                convertRequest.setSymboltoken(request.getSymboltoken());
                convertRequest.setOldproducttype(request.getOldproducttype());
                convertRequest.setNewproducttype(request.getNewproducttype());
                convertRequest.setTradingsymbol(request.getTradingsymbol());
                convertRequest.setSymbolname(request.getSymbolname());
                convertRequest.setInstrumenttype(request.getInstrumenttype());
                convertRequest.setPriceden(request.getPriceden());
                convertRequest.setPricenum(request.getPricenum());
                convertRequest.setGenden(request.getGenden());
                convertRequest.setGennum(request.getGennum());
                convertRequest.setPrecision(request.getPrecision());
                convertRequest.setMultiplier(request.getMultiplier());
                convertRequest.setBoardlotsize(request.getBoardlotsize());
                convertRequest.setBuyqty(request.getBuyqty());
                convertRequest.setSellqty(request.getSellqty());
                convertRequest.setBuyamount(request.getBuyamount());
                convertRequest.setSellamount(request.getSellamount());
                convertRequest.setTransactiontype(request.getTransactiontype());
                convertRequest.setQuantity(request.getQuantity());
                convertRequest.setType(request.getType());
                try {
                    JSONObject response = angelOneClient.convertPosition(getBaseUrl(account), convertRequest).get();
                    log.info("AngelOne convert position SUCCESS | clientId={}", account.getClientId());
                    return response;
                } catch (Exception e) {
                    log.error("AngelOne convert position failed | clientId={}: {}", account.getClientId(), e.getMessage(), e);
                    throw new RuntimeException("Convert position failed: " + e.getMessage(), e);
                }
            }

            case MOTILAL -> {
                PyBrokerSecret secret = account.getSecret();
                if (secret == null) throw new RuntimeException(
                        "No API credentials found for: " + account.getClientId());
                log.info("Motilal convert position | clientId={} scripcode={} {} -> {}",
                        account.getClientId(), request.getSymboltoken(),
                        request.getOldproducttype(), request.getNewproducttype());
                MotilalConvertPositionRequest convertRequest = new MotilalConvertPositionRequest();
                convertRequest.setApiKey(secret.getApiKey());
                convertRequest.setApiSecret(secret.getApiSecret());
                convertRequest.setVendorInfo(secret.getVenderInfo());
                convertRequest.setAuthToken(account.getToken().getRefreshToken());
                convertRequest.setAccessToken(accessToken);
                convertRequest.setClientcode(account.getClientId());
                convertRequest.setExchange(request.getExchange());
                convertRequest.setScripcode(Long.parseLong(request.getSymboltoken()));
                convertRequest.setQuantity(request.getQuantity());
                convertRequest.setOldproduct(request.getOldproducttype());
                convertRequest.setNewproduct(request.getNewproducttype());
                try {
                    JSONObject response = motilalClient.convertPosition(getBaseUrl(account), convertRequest).get();
                    log.info("Motilal convert position SUCCESS | clientId={}", account.getClientId());
                    return response;
                } catch (RuntimeException e) {
                    throw e;
                } catch (Exception e) {
                    log.error("Motilal convert position failed | clientId={}: {}", account.getClientId(), e.getMessage(), e);
                    throw new RuntimeException("Convert position failed: " + e.getMessage(), e);
                }
            }

            default -> throw new RuntimeException(
                    "Convert position not supported for broker: " + account.getBrokerType());
        }
    }
}