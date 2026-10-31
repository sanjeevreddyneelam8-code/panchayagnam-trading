package com.py.tokensValidation;

import com.py.common.enums.BrokerType;
import com.py.common.util.TotpUtil;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.entity.PyBrokerSecret;
import com.py.demataccount.entity.PyBrokerToken;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.demataccount.repository.PyBrokerTokenRepository;
import com.py.tokenrefresh.service.TokenRefreshService;
import com.py.utils.AngelOneMicroserviceClient;
import com.py.utils.DhanMicroserviceClient;
import com.py.utils.MotilalMicroserviceClient;
import com.py.ipconfig.repository.PyBrokerIpConfigRepository;
import org.apache.commons.codec.digest.DigestUtils;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;

import static com.py.common.util.PyCommonUtil.getBaseUrl;

@Service
public class PyTokenValidationService {

    private static final Logger log = LoggerFactory
            .getLogger(PyTokenValidationService.class);

    @Value("${trading.paper-trading.enabled:${PAPER_TRADING_ENABLED:true}}")
    private boolean paperTradingEnabled;

    @Autowired
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @Autowired
    private PyBrokerTokenRepository pyBrokerTokenRepository;

    @Autowired
    private PyBrokerIpConfigRepository pyBrokerIpConfigRepository;

    @Autowired
    private TokenRefreshService angelOneTokenRefreshService;

    @Autowired
    private TotpUtil totpUtil;

    @Autowired
    private AngelOneMicroserviceClient angelOneClient;

    @Autowired
    private MotilalMicroserviceClient motilalClient;

    @Autowired
    private DhanMicroserviceClient dhanClient;

    public boolean isProtectedAccount(PyBrokerAccountEntity account) {
        if (paperTradingEnabled) {
            return true;
        }
        if (account == null) {
            return false;
        }
        String clientId = account.getClientId();
        if (clientId != null && (
                clientId.equals("1100345678") ||
                clientId.startsWith("ZR") ||
                clientId.startsWith("UP") ||
                clientId.startsWith("AG") ||
                clientId.startsWith("MO") ||
                clientId.startsWith("PM") ||
                clientId.startsWith("GW") ||
                clientId.startsWith("GR") ||
                clientId.toLowerCase().contains("demo")
        )) {
            return true;
        }
        PyBrokerToken token = account.getToken();
        if (token != null && token.getAccessToken() != null) {
            String acc = token.getAccessToken();
            if (acc.contains("demo") || acc.startsWith("PAPER-")) {
                return true;
            }
        }
        return false;
    }

    // ── MAIN METHOD ───────────────────────────────────────────────────────────
    public String getValidAccessToken(Long brokerAccountId) {
        try {
            PyBrokerAccountEntity account = pyBrokerAccountRepository
                    .findById(brokerAccountId)
                    .orElseThrow(() -> new RuntimeException(
                    "Broker account not found: " + brokerAccountId));

            if (isProtectedAccount(account)) {
                if (account.getToken() != null && account.getToken().getAccessToken() != null && !account.getToken().getAccessToken().isBlank()) {
                    return account.getToken().getAccessToken();
                }
                return "PAPER-TOKEN-" + account.getBrokerType() + "-" + account.getClientId();
            }

            if (isTokenValid(account)) {
                log.info("Token valid for clientId={}", account.getClientId());
                return account.getToken().getAccessToken();
            }

            log.warn("Token expired for clientId={} broker={} — refreshing...",
                    account.getClientId(), account.getBrokerType());

            return refreshTokenInNewTransaction(account);

        } catch (Exception e) {
            log.error("Token validation failed for brokerAccountId={}: {}",
                    brokerAccountId, e.getMessage());
            return null;
        }
    }

    // ── CHECK TOKEN VALIDITY ──────────────────────────────────────────────────
    public boolean isTokenValid(PyBrokerAccountEntity account) {
        if (isProtectedAccount(account)) {
            return true;
        }

        PyBrokerToken token = account.getToken();

        if (token == null) {
            log.warn("No token found for clientId={}", account.getClientId());
            return false;
        }

        if (token.getAccessToken() == null || token.getAccessToken().isBlank()) {
            log.warn("Access token is null for clientId={}", account.getClientId());
            return false;
        }

        if (token.getExpiresAt() == null
                || token.getExpiresAt().isBefore(LocalDateTime.now())) {
            log.warn("Token expired at {} for clientId={}",
                    token.getExpiresAt(), account.getClientId());
            return false;
        }

        return true;
    }

    // ── REFRESH IN NEW TRANSACTION ────────────────────────────────────────────
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public String refreshTokenInNewTransaction(PyBrokerAccountEntity account) {
        return switch (account.getBrokerType()) {
            case ANGELONE ->
                refreshAngelOneToken(account);
            case MOTILAL ->
                refreshMotilalToken(account);
            case DHAN ->
                refreshDhanToken(account);
            default -> {
                log.error("Unsupported broker type: {} for clientId={}",
                        account.getBrokerType(), account.getClientId());
                yield null;
            }
        };
    }

    // ── ANGEL ONE REFRESH ─────────────────────────────────────────────────────
    private String refreshAngelOneToken(PyBrokerAccountEntity account) {
        try {
            log.info("Refreshing AngelOne token via microservice for clientId={}",
                    account.getClientId());

            PyBrokerSecret secret = account.getSecret();
            String totp = totpUtil.generate(secret.getTotpSecret());
            String baseUrl = getBaseUrl(account);

            JSONObject loginData = angelOneClient.login(
                    baseUrl,
                    account.getClientId(),
                    secret.getPassword(),
                    totp,
                    secret.getApiKey());

            if (loginData == null) {
                throw new RuntimeException("Null response from AngelOne microservice");
            }

            PyBrokerToken token = account.getToken();
            token.setAccessToken(loginData.getString("jwtToken"));
            token.setRefreshToken(loginData.optString("refreshToken", ""));
            token.setFeedToken(loginData.optString("feedToken", ""));
            token.setExpiresAt(getTokenExpiry(BrokerType.ANGELONE));
            PyBrokerToken saved = pyBrokerTokenRepository.save(token);

            log.info("AngelOne token refreshed successfully for clientId={}",
                    account.getClientId());
            return saved.getAccessToken();

        } catch (Exception e) {
            log.error("AngelOne token refresh failed for clientId={} — marking inactive. Reason: {}",
                    account.getClientId(), e.getMessage());
            markAccountInactive(account, "AngelOne token refresh failed: " + e.getMessage());
            return null;
        }
    }

    // ── MOTILAL REFRESH ───────────────────────────────────────────────────────
    private String refreshMotilalToken(PyBrokerAccountEntity account) {
        try {
            log.info("Refreshing Motilal token via microservice for clientId={}",
                    account.getClientId());

            PyBrokerSecret secret = account.getSecret();
            String totp = totpUtil.generate(secret.getTotpSecret());
            String hashedPassword = DigestUtils.sha256Hex(
                    secret.getPassword() + secret.getApiKey());
            String baseUrl = getBaseUrl(account);

            log.info("Motilal re-login initiated for clientId={}",
                    account.getClientId());

            // ── Step 1: Login → get AuthToken ─────────────────────────────
            JSONObject loginResponse = motilalClient.login(
                    baseUrl,
                    account.getClientId(),
                    hashedPassword,
                    secret.getTwoFa(),
                    totp,
                    secret.getApiKey(),
                    secret.getApiSecret(),
                    secret.getVenderInfo());

            String authToken = loginResponse.getString("AuthToken");

            // ── Step 2: Exchange AuthToken → AccessToken ──────────────────
            JSONObject accessTokenResponse = motilalClient.getAccessToken(
                    baseUrl,
                    authToken,
                    secret.getApiKey(),
                    secret.getApiSecret(),
                    secret.getVenderInfo());

            String accessToken = accessTokenResponse.getString("accesstoken");

            // ── Step 3: Persist new tokens ────────────────────────────────
            PyBrokerToken token = account.getToken();
            token.setRefreshToken(authToken);
            token.setAccessToken(accessToken);
            token.setExpiresAt(getMotilalTokenExpiry());
            PyBrokerToken saved = pyBrokerTokenRepository.save(token);

            log.info("Motilal token refreshed successfully for clientId={}",
                    account.getClientId());
            return saved.getAccessToken();

        } catch (Exception e) {
            log.error("Motilal token refresh failed for clientId={} — marking inactive. Reason: {}",
                    account.getClientId(), e.getMessage());
            markAccountInactive(account, "Motilal token refresh failed: " + e.getMessage());
            return null;
        }
    }

    // ── DHAN REFRESH ──────────────────────────────────────────────────────────
    private String refreshDhanToken(PyBrokerAccountEntity account) {
        try {
            log.info("Refreshing Dhan token via microservice for clientId={}",
                    account.getClientId());

            PyBrokerSecret secret = account.getSecret();
            String totp = totpUtil.generate(secret.getTotpSecret());
            String baseUrl = getBaseUrl(account);

            JSONObject loginResponse = dhanClient.login(
                    baseUrl,
                    account.getClientId(),
                    secret.getPassword(),
                    totp);

            String accessToken = loginResponse.getString("accessToken");

            PyBrokerToken token = account.getToken();
            token.setAccessToken(accessToken);
            token.setExpiresAt(getTokenExpiry(BrokerType.DHAN));
            PyBrokerToken saved = pyBrokerTokenRepository.save(token);

            log.info("Dhan token refreshed successfully for clientId={}",
                    account.getClientId());
            return saved.getAccessToken();

        } catch (Exception e) {
            log.error("Dhan token refresh failed for clientId={} — marking inactive. Reason: {}",
                    account.getClientId(), e.getMessage());
            markAccountInactive(account, "Dhan token refresh failed: " + e.getMessage());
            return null;
        }
    }

    // ── MARK ACCOUNT INACTIVE ─────────────────────────────────────────────────
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void markAccountInactive(PyBrokerAccountEntity account, String reason) {
        if (isProtectedAccount(account)) {
            log.info("Protected demo/paper account detected — suppressing deactivation for clientId={}",
                    account != null ? account.getClientId() : "unknown");
            return;
        }
        try {
            PyBrokerAccountEntity dbAccount = pyBrokerAccountRepository
                    .findById(account.getId())
                    .orElse(null);

            if (dbAccount == null) {
                log.error("Cannot mark inactive — account not found: {}", account.getId());
                return;
            }

            dbAccount.setActive(false);
            dbAccount.setLastLoginStatus("FAILED");
            dbAccount.setLastLoginError(reason);
            dbAccount.setLastLoginAttempt(LocalDateTime.now());
            pyBrokerAccountRepository.save(dbAccount);

            log.error("Account DEACTIVATED — clientId={} broker={} reason={}",
                    account.getClientId(), account.getBrokerType(), reason);

        } catch (Exception ex) {
            log.error("Failed to mark account inactive for clientId={}: {}",
                    account.getClientId(), ex.getMessage());
        }
    }

    // ── TOKEN EXPIRY HELPERS ──────────────────────────────────────────────────
    private LocalDateTime getMotilalTokenExpiry() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime todaySixAm = LocalDate.now().atTime(6, 0);
        return now.isBefore(todaySixAm) ? todaySixAm : todaySixAm.plusDays(1);
    }

    private LocalDateTime getTokenExpiry(BrokerType brokerType) {
        LocalDateTime now = LocalDateTime.now();
        return switch (brokerType) {
            case ANGELONE ->
                LocalDate.now().plusDays(1).atStartOfDay();
            case MOTILAL -> {
                LocalDateTime todaySixAm = LocalDate.now().atTime(6, 0);
                yield now.isBefore(todaySixAm) ? todaySixAm : todaySixAm.plusDays(1);
            }
            case DHAN ->
                now.plusHours(24);
            default ->
                now.plusHours(24);
        };
    }
}
