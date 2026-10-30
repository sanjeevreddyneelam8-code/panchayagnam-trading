package com.py.demataccount.controller;

import com.py.common.enums.BrokerType;
import com.py.common.util.PyCommonUtil;
import com.py.common.util.TotpUtil;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.entity.PyBrokerSecret;
import com.py.demataccount.entity.PyBrokerToken;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.demataccount.utils.BrokerProfileLoader;
import com.py.demataccount.utils.BrokerTokenSecretManager;
import com.py.ipconfig.entity.PyBrokerIpConfigEntity;
import com.py.ipconfig.repository.PyBrokerIpConfigRepository;
import com.py.utils.*;
import jakarta.servlet.http.HttpServletResponse;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Unified OAuth Connect and Callback Controller for all brokers.
 *
 * Provides:
 * 1. GET /api/v1/oauth/connect/{broker}?clientId=...
 *    Opens the broker's official authentication page or paper simulation.
 * 2. GET /api/v1/oauth/callback/{broker}
 *    Automatically intercepts the callback code/request_token, exchanges it for a session token,
 *    saves it encrypted, updates lastLoginStatus=SUCCESS, and signals the UI via postMessage.
 */
@RestController
@RequestMapping("/api/v1/oauth")
public class UnifiedOAuthController {

    private static final Logger log = LoggerFactory.getLogger(UnifiedOAuthController.class);

    private static final Map<String, String> pendingConnects = new ConcurrentHashMap<>();

    @Value("${trading.paper-trading.enabled:true}")
    private boolean paperTradingEnabled;

    @Value("${server.port:8081}")
    private String serverPort;

    @Autowired
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @Autowired
    private PyBrokerIpConfigRepository ipConfigRepository;

    @Autowired
    private BrokerTokenSecretManager tokenSecretManager;

    @Autowired
    private ZerodhaMicroserviceClient zerodhaClient;

    @Autowired
    private UpstoxMicroserviceClient upstoxClient;

    @Autowired
    private GoodwillMicroserviceClient goodwillClient;

    @Autowired
    private ProfitmartMicroserviceClient profitmartClient;

    @Autowired
    private AngelOneMicroserviceClient angelOneClient;

    @Autowired
    private MotilalMicroserviceClient motilalClient;

    @Autowired
    private BrokerProfileLoader profileLoader;

    @Autowired
    private TotpUtil totpUtil;

    // ── CONNECT INITIATION ──────────────────────────────────────────────────
    @GetMapping(value = "/connect/{broker}", produces = MediaType.TEXT_HTML_VALUE)
    public void initiateConnect(
            @PathVariable("broker") String brokerName,
            @RequestParam("clientId") String clientId,
            HttpServletResponse response) throws IOException {

        log.info("Initiating OAuth connect | broker={} clientId={}", brokerName, clientId);

        PyBrokerAccountEntity account = pyBrokerAccountRepository.findByClientId(clientId).orElse(null);
        if (account == null) {
            response.setStatus(HttpServletResponse.SC_NOT_FOUND);
            response.getWriter().write(renderErrorHtml(brokerName, clientId, "Account with Client ID '" + clientId + "' not found."));
            return;
        }

        PyBrokerSecret secret = account.getSecret();
        String apiKey = secret != null ? secret.getApiKey() : null;

        pendingConnects.put(brokerName.toUpperCase() + "_" + clientId, clientId);
        pendingConnects.put(brokerName.toUpperCase(), clientId);

        String callbackBase = "http://localhost:" + serverPort + "/api/v1/oauth/callback/" + brokerName.toUpperCase();

        // 1. If paper trading is active, provide immediate test simulation alongside live broker login option
        if (paperTradingEnabled) {
            String simCallbackUrl = callbackBase + "?clientId=" + clientId + "&code=SIM-AUTH-" + System.currentTimeMillis() + "&request_token=SIM-REQ-" + System.currentTimeMillis();
            String liveLoginUrl = buildLiveOAuthUrl(brokerName.toUpperCase(), apiKey != null ? apiKey : "", callbackBase, clientId);

            response.setContentType("text/html;charset=UTF-8");
            response.getWriter().write(renderConnectGatewayHtml(brokerName.toUpperCase(), clientId, liveLoginUrl, simCallbackUrl));
            return;
        }

        // 2. In live mode, redirect directly to the official broker OAuth login page
        String liveLoginUrl = buildLiveOAuthUrl(brokerName.toUpperCase(), apiKey != null ? apiKey : "", callbackBase, clientId);
        response.sendRedirect(liveLoginUrl);
    }

    private String buildLiveOAuthUrl(String broker, String apiKey, String callbackBase, String clientId) {
        return switch (broker) {
            case "ZERODHA" -> "https://kite.zerodha.com/connect/login?v=3&api_key=" + apiKey + "&redirect_params=clientId%3D" + clientId;
            case "UPSTOX" -> "https://api.upstox.com/v2/login/authorization/dialog?response_type=code&client_id=" + apiKey + "&redirect_uri=" + callbackBase + "&state=" + clientId;
            case "PROFITMART" -> "https://profitmart.in/web/NorenWClient/QuickAuth";
            case "GOODWILL" -> "https://giga.gwcindia.in/interactive/user/session";
            case "ANGELONE" -> "https://smartapi.angelbroking.com";
            case "MOTILAL" -> "https://openapi.motilaloswal.com";
            default -> callbackBase + "?clientId=" + clientId;
        };
    }

    // ── AUTOMATIC OAUTH CALLBACK ─────────────────────────────────────────────
    @GetMapping(value = "/callback/{broker}", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> handleCallback(
            @PathVariable("broker") String brokerName,
            @RequestParam(value = "request_token", required = false) String requestToken,
            @RequestParam(value = "code", required = false) String code,
            @RequestParam(value = "state", required = false) String state,
            @RequestParam(value = "clientId", required = false) String clientIdParam,
            @RequestParam(value = "status", required = false) String status,
            @RequestParam(value = "action", required = false) String action) {

        String broker = brokerName.toUpperCase();
        log.info("OAuth callback received | broker={} code={} requestToken={} state={} clientIdParam={}",
                broker, code != null, requestToken != null, state, clientIdParam);

        String effectiveClientId = clientIdParam;
        if (effectiveClientId == null || effectiveClientId.isBlank()) {
            effectiveClientId = state;
        }
        if (effectiveClientId == null || effectiveClientId.isBlank()) {
            effectiveClientId = pendingConnects.get(broker);
        }

        if (effectiveClientId == null || effectiveClientId.isBlank()) {
            return ResponseEntity.badRequest().body(renderErrorHtml(broker, "Unknown", "Could not identify client account from OAuth callback parameters."));
        }

        PyBrokerAccountEntity account = pyBrokerAccountRepository.findByClientId(effectiveClientId).orElse(null);
        if (account == null) {
            return ResponseEntity.badRequest().body(renderErrorHtml(broker, effectiveClientId, "Account record not found in system for Client ID: " + effectiveClientId));
        }

        PyBrokerSecret secret = account.getSecret();
        String apiKey = secret != null ? secret.getApiKey() : "";
        String apiSecret = secret != null ? secret.getApiSecret() : "";

        // Resolve microservice URL
        PyBrokerIpConfigEntity ipConfig = ipConfigRepository.findByIpAddress("127.0.0.1").orElse(null);
        String baseUrl = PyCommonUtil.getBaseUrl(ipConfig);

        boolean isSimulated = (requestToken != null && (requestToken.startsWith("SIM-") || requestToken.startsWith("PAPER-")))
                || (code != null && (code.startsWith("SIM-") || code.startsWith("PAPER-")));

        JSONObject loginResult;
        try {
            if ("ZERODHA".equals(broker)) {
                String reqToken = requestToken != null ? requestToken : code;
                if (reqToken == null || reqToken.isBlank()) {
                    return ResponseEntity.badRequest().body(renderErrorHtml(broker, effectiveClientId, "Zerodha callback did not provide request_token."));
                }
                loginResult = zerodhaClient.login(baseUrl, effectiveClientId, apiKey, apiSecret, reqToken);
            } else if ("UPSTOX".equals(broker)) {
                String authCode = code != null ? code : requestToken;
                if (authCode == null || authCode.isBlank()) {
                    return ResponseEntity.badRequest().body(renderErrorHtml(broker, effectiveClientId, "Upstox callback did not provide authorization code."));
                }
                String redirectUri = "http://localhost:" + serverPort + "/api/v1/oauth/callback/UPSTOX";
                loginResult = upstoxClient.login(baseUrl, effectiveClientId, apiKey, apiSecret, authCode, redirectUri);
            } else if ("GOODWILL".equals(broker) || "GOODWELL".equals(broker)) {
                if (paperTradingEnabled && isSimulated) {
                    loginResult = new JSONObject().put("status", true).put("message", "SUCCESS")
                            .put("accessToken", "PAPER-SIM-GW-" + System.currentTimeMillis()).put("userId", effectiveClientId);
                } else {
                    String mpin = secret != null ? secret.getPassword() : "";
                    loginResult = goodwillClient.login(baseUrl, effectiveClientId, apiKey, apiSecret, mpin);
                }
            } else if ("PROFITMART".equals(broker)) {
                if (paperTradingEnabled && isSimulated) {
                    loginResult = new JSONObject().put("stat", "Ok").put("status", true)
                            .put("susertoken", "PAPER-SIM-PM-" + System.currentTimeMillis())
                            .put("accessToken", "PAPER-SIM-PM-" + System.currentTimeMillis())
                            .put("access_token", "PAPER-SIM-PM-" + System.currentTimeMillis());
                } else {
                    String authCode = code != null ? code : requestToken;
                    String password = secret != null ? secret.getPassword() : "";
                    if (authCode != null && !authCode.isBlank()) {
                        loginResult = profitmartClient.login(baseUrl, effectiveClientId, authCode, apiKey);
                    } else {
                        String twoFa = secret != null ? (secret.getTwoFa() != null ? secret.getTwoFa() : secret.getTotpSecret()) : "";
                        loginResult = profitmartClient.loginWithCredentials(baseUrl, effectiveClientId, password, twoFa, apiKey, apiSecret, "EasyTrade");
                    }
                }
            } else if ("ANGELONE".equals(broker)) {
                if (paperTradingEnabled && isSimulated) {
                    loginResult = new JSONObject().put("status", true).put("message", "SUCCESS")
                            .put("jwtToken", "PAPER-SIM-JWT-ANGEL-" + System.currentTimeMillis())
                            .put("refreshToken", "PAPER-SIM-REFRESH-ANGEL-" + System.currentTimeMillis())
                            .put("feedToken", "PAPER-SIM-FEED-ANGEL-" + System.currentTimeMillis());
                } else {
                    String mpin = secret != null ? secret.getPassword() : "";
                    String totpKey = secret != null ? secret.getTotpSecret() : "";
                    String totp = (totpKey != null && !totpKey.isBlank()) ? totpUtil.generate(totpKey) : "123456";
                    loginResult = angelOneClient.login(baseUrl, effectiveClientId, mpin, totp, apiKey);
                }
            } else if ("MOTILAL".equals(broker)) {
                if (paperTradingEnabled && isSimulated) {
                    loginResult = new JSONObject().put("status", "SUCCESS").put("message", "SUCCESS")
                            .put("errorcode", "")
                            .put("AuthToken", "PAPER-SIM-AUTH-MO-" + System.currentTimeMillis())
                            .put("AccessToken", "PAPER-SIM-TOKEN-MO-" + System.currentTimeMillis());
                } else {
                    String mpin = secret != null ? secret.getPassword() : "";
                    String totpKey = secret != null ? secret.getTotpSecret() : "";
                    String totp = (totpKey != null && !totpKey.isBlank()) ? totpUtil.generate(totpKey) : "123456";
                    String hashedPassword = profileLoader.generateMotilalPasswordHash(mpin, apiKey);
                    String twoFa = secret != null && secret.getTwoFa() != null ? secret.getTwoFa() : "1990-01-01";
                    JSONObject loginResp = motilalClient.login(baseUrl, effectiveClientId, hashedPassword, twoFa, totp, apiKey, apiSecret, "");
                    String authToken = loginResp.optString("AuthToken", loginResp.optString("authtoken", ""));
                    loginResult = motilalClient.getAccessToken(baseUrl, authToken, apiKey, apiSecret, "");
                }
            } else {
                loginResult = new JSONObject().put("status", true).put("accessToken", "TOKEN-" + System.currentTimeMillis());
            }

            if (loginResult == null || (!loginResult.optBoolean("status", true) && !"Ok".equalsIgnoreCase(loginResult.optString("stat", "")) && !"SUCCESS".equalsIgnoreCase(loginResult.optString("status", "")))) {
                String errorMsg = loginResult != null ? loginResult.optString("message", loginResult.optString("emsg", "Authentication rejected by broker")) : "No response from broker";
                account.setLastLoginStatus("FAILED");
                account.setLastLoginError(errorMsg);
                account.setLastLoginAttempt(LocalDateTime.now());
                pyBrokerAccountRepository.save(account);
                return ResponseEntity.status(401).body(renderErrorHtml(broker, effectiveClientId, errorMsg));
            }

            // Successfully authenticated with official API
            PyBrokerToken token = account.getToken();
            if (token == null) {
                token = tokenSecretManager.createToken(loginResult, account.getBrokerType());
                token.setBrokerAccount(account);
                account.setToken(token);
            } else {
                tokenSecretManager.updateToken(token, loginResult, account.getBrokerType());
            }
            account.setLastLoginStatus("SUCCESS");
            account.setLastLoginError(null);
            account.setLastLoginAttempt(LocalDateTime.now());
            pyBrokerAccountRepository.save(account);

            log.info("OAuth connection SUCCESS | broker={} clientId={}", broker, effectiveClientId);
            return ResponseEntity.ok(renderSuccessHtml(broker, effectiveClientId));

        } catch (Exception e) {
            log.error("OAuth token exchange failed | broker={} clientId={} error={}", broker, effectiveClientId, e.getMessage(), e);
            account.setLastLoginStatus("FAILED");
            account.setLastLoginError(e.getMessage());
            account.setLastLoginAttempt(LocalDateTime.now());
            pyBrokerAccountRepository.save(account);
            return ResponseEntity.status(401).body(renderErrorHtml(broker, effectiveClientId, e.getMessage()));
        }
    }

    // ── HTML RENDERERS ────────────────────────────────────────────────────────
    private String renderConnectGatewayHtml(String broker, String clientId, String liveLoginUrl, String simCallbackUrl) {
        return "<!DOCTYPE html>\n" +
                "<html>\n" +
                "<head>\n" +
                "  <meta charset=\"UTF-8\">\n" +
                "  <title>Connect " + broker + " - Panchayagnam Trading</title>\n" +
                "  <style>\n" +
                "    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 24px; display: flex; align-items: center; justify-content: center; min-height: 100vh; box-sizing: border-box; }\n" +
                "    .card { background: #1e293b; border: 1px solid #334155; border-radius: 16px; padding: 32px; max-width: 480px; width: 100%; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); text-align: center; }\n" +
                "    .badge { display: inline-block; padding: 4px 12px; background: #0284c7; color: white; border-radius: 9999px; font-size: 12px; font-weight: 600; text-transform: uppercase; margin-bottom: 16px; }\n" +
                "    h2 { margin: 0 0 10px 0; font-size: 22px; }\n" +
                "    p { color: #94a3b8; font-size: 14px; line-height: 1.5; margin: 0 0 24px 0; }\n" +
                "    .btn { display: block; width: 100%; box-sizing: border-box; padding: 12px 20px; border-radius: 10px; font-weight: 600; text-decoration: none; margin-bottom: 12px; transition: all 0.2s; font-size: 14px; cursor: pointer; text-align: center; }\n" +
                "    .btn-sim { background: #10b981; color: #042f2e; border: none; }\n" +
                "    .btn-sim:hover { background: #34d399; }\n" +
                "    .btn-live { background: #334155; color: #f8fafc; border: 1px solid #475569; }\n" +
                "    .btn-live:hover { background: #475569; }\n" +
                "    .note { font-size: 12px; color: #64748b; margin-top: 16px; }\n" +
                "  </style>\n" +
                "</head>\n" +
                "<body>\n" +
                "  <div class=\"card\">\n" +
                "    <div class=\"badge\">" + broker + " Authentication</div>\n" +
                "    <h2>Connect " + broker + " Account</h2>\n" +
                "    <p>Authenticating client account <b>" + clientId + "</b>. In Paper Trading mode, choose your connection method:</p>\n" +
                "    <a class=\"btn btn-sim\" href=\"" + simCallbackUrl + "\">⚡ 1-Click Auto Authenticate (Paper Testing)</a>\n" +
                "    <a class=\"btn btn-live\" href=\"" + liveLoginUrl + "\">🌐 Proceed to Official " + broker + " Login</a>\n" +
                "    <div class=\"note\">Paper trading mode is enabled. No real orders or financial charges will occur.</div>\n" +
                "  </div>\n" +
                "</body>\n" +
                "</html>";
    }

    private String renderSuccessHtml(String broker, String clientId) {
        return "<!DOCTYPE html>\n" +
                "<html>\n" +
                "<head>\n" +
                "  <meta charset=\"UTF-8\">\n" +
                "  <title>Connected Successfully</title>\n" +
                "  <style>\n" +
                "    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 24px; display: flex; align-items: center; justify-content: center; min-height: 100vh; }\n" +
                "    .card { background: #1e293b; border: 1px solid #10b981; border-radius: 16px; padding: 32px; max-width: 440px; text-align: center; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); }\n" +
                "    .icon { width: 56px; height: 56px; background: #064e3b; color: #34d399; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 28px; margin: 0 auto 16px auto; font-weight: bold; }\n" +
                "    h2 { margin: 0 0 8px 0; font-size: 20px; color: #34d399; }\n" +
                "    p { color: #94a3b8; font-size: 14px; line-height: 1.5; margin: 0 0 20px 0; }\n" +
                "  </style>\n" +
                "</head>\n" +
                "<body>\n" +
                "  <div class=\"card\">\n" +
                "    <div class=\"icon\">✓</div>\n" +
                "    <h2>" + broker + " Connected!</h2>\n" +
                "    <p>Client account <b>" + clientId + "</b> is now authenticated and connected. Returning to dashboard...</p>\n" +
                "  </div>\n" +
                "  <script>\n" +
                "    try {\n" +
                "      if (window.opener) {\n" +
                "        window.opener.postMessage({ type: 'BROKER_CONNECTED', broker: '" + broker + "', clientId: '" + clientId + "' }, '*');\n" +
                "        setTimeout(function() { window.close(); }, 1000);\n" +
                "      } else {\n" +
                "        setTimeout(function() { window.location.href = 'http://localhost:8080/#/accounts'; }, 1500);\n" +
                "      }\n" +
                "    } catch (e) {\n" +
                "      window.close();\n" +
                "    }\n" +
                "  </script>\n" +
                "</body>\n" +
                "</html>";
    }

    private String renderErrorHtml(String broker, String clientId, String errorMsg) {
        return "<!DOCTYPE html>\n" +
                "<html>\n" +
                "<head>\n" +
                "  <meta charset=\"UTF-8\">\n" +
                "  <title>Connection Failed</title>\n" +
                "  <style>\n" +
                "    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 24px; display: flex; align-items: center; justify-content: center; min-height: 100vh; }\n" +
                "    .card { background: #1e293b; border: 1px solid #ef4444; border-radius: 16px; padding: 32px; max-width: 440px; text-align: center; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); }\n" +
                "    .icon { width: 56px; height: 56px; background: #450a0a; color: #f87171; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 28px; margin: 0 auto 16px auto; font-weight: bold; }\n" +
                "    h2 { margin: 0 0 8px 0; font-size: 20px; color: #f87171; }\n" +
                "    p { color: #94a3b8; font-size: 14px; line-height: 1.5; margin: 0 0 20px 0; }\n" +
                "    button { background: #ef4444; color: white; border: none; padding: 10px 24px; border-radius: 8px; font-weight: 600; cursor: pointer; }\n" +
                "    button:hover { background: #dc2626; }\n" +
                "  </style>\n" +
                "</head>\n" +
                "<body>\n" +
                "  <div class=\"card\">\n" +
                "    <div class=\"icon\">✕</div>\n" +
                "    <h2>" + broker + " Authentication Failed</h2>\n" +
                "    <p>" + errorMsg + "</p>\n" +
                "    <button onclick=\"window.close()\">Close</button>\n" +
                "  </div>\n" +
                "  <script>\n" +
                "    try {\n" +
                "      if (window.opener) {\n" +
                "        window.opener.postMessage({ type: 'BROKER_AUTH_FAILED', broker: '" + broker + "', clientId: '" + clientId + "', error: '" + errorMsg + "' }, '*');\n" +
                "      }\n" +
                "    } catch (e) {}\n" +
                "  </script>\n" +
                "</body>\n" +
                "</html>";
    }
}
