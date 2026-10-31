package com.py.demataccount.service.impl;

import com.py.common.util.PyCommonUtil;
import com.py.common.util.TotpUtil;
import com.py.brokers.upstox.service.UpstoxAuthService;
import com.py.demataccount.dto.DematAccountAddRequest;
import com.py.ipconfig.entity.PyBrokerIpConfigEntity;
import com.py.ipconfig.repository.PyBrokerIpConfigRepository;
import com.py.demataccount.utils.BrokerProfileLoader;
import com.py.utils.AngelOneMicroserviceClient;
import com.py.utils.DhanMicroserviceClient;
import com.py.utils.MotilalMicroserviceClient;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class BrokerLoginService {

    private static final Logger log = LoggerFactory.getLogger(BrokerLoginService.class);

    @Autowired
    private TotpUtil totpUtil;

    @Autowired
    private PyBrokerIpConfigRepository pyBrokerIpConfigRepository;

    @Autowired
    private UpstoxAuthService upstoxAuthService;

    @Autowired
    private AngelOneMicroserviceClient angelOneClient;

    @Autowired
    private MotilalMicroserviceClient motilalClient;

    @Autowired
    private DhanMicroserviceClient dhanClient;

    @Autowired
    private com.py.utils.ZerodhaMicroserviceClient zerodhaClient;

    @Autowired
    private com.py.utils.UpstoxMicroserviceClient upstoxMicroserviceClient;

    @Autowired
    private com.py.utils.GoodwillMicroserviceClient goodwillClient;

    @Autowired
    private com.py.utils.ProfitmartMicroserviceClient profitmartClient;

    @Autowired
    private BrokerProfileLoader profileLoader;

    @org.springframework.beans.factory.annotation.Value("${trading.paper-trading.enabled:${PAPER_TRADING_ENABLED:true}}")
    private boolean paperTradingEnabled;

    private boolean isProtectedDemoAccount(DematAccountAddRequest request) {
        if (paperTradingEnabled) {
            return true;
        }
        if (request == null) return false;
        String clientId = request.getClientId();
        return clientId != null && (
                clientId.equals("1100345678") ||
                clientId.startsWith("ZR") ||
                clientId.startsWith("UP") ||
                clientId.startsWith("AG") ||
                clientId.startsWith("MO") ||
                clientId.startsWith("PM") ||
                clientId.startsWith("GW") ||
                clientId.startsWith("GR") ||
                clientId.toLowerCase().contains("demo")
        );
    }

    // ── ROUTER ────────────────────────────────────────────────────────────────
    public JSONObject login(DematAccountAddRequest request) {
        log.info("Initiating login | broker={} clientId={}",
                request.getBrokerType(), request.getClientId());

        if (isProtectedDemoAccount(request)) {
            log.info("Paper trading mode / demo account active — returning permanent simulated login for clientId={} broker={}",
                    request.getClientId(), request.getBrokerType());
            JSONObject mockLogin = new JSONObject();
            mockLogin.put("status", true);
            mockLogin.put("jwtToken", "PAPER-TOKEN-" + request.getBrokerType() + "-" + request.getClientId());
            mockLogin.put("accessToken", "PAPER-TOKEN-" + request.getBrokerType() + "-" + request.getClientId());
            mockLogin.put("refreshToken", "PAPER-REFRESH-" + request.getClientId());
            mockLogin.put("feedToken", "PAPER-FEED-" + request.getClientId());
            return mockLogin;
        }

        return switch (request.getBrokerType()) {
            case ANGELONE   -> loginAngelOne(request);
            case MOTILAL    -> loginMotilal(request);
            case DHAN       -> loginDhan(request);
            case UPSTOX     -> loginUpstox(request);
            case ZERODHA    -> loginZerodha(request);
            case GOODWILL   -> loginGoodwill(request);
            case PROFITMART -> loginProfitmart(request);
            case GROWW      -> throw new IllegalArgumentException(
                    "Groww does not provide an official trading API for third-party automated execution.");
        };
    }

    private JSONObject loginProfitmart(DematAccountAddRequest request) {
        log.info("Profitmart login attempt | clientId={}", request.getClientId());
        String password = request.getMpin() != null ? request.getMpin() : request.getPin();
        if (password != null && !password.isBlank()) {
            PyBrokerIpConfigEntity ipConfig = getIpConfig(request.getIp());
            String baseUrl = PyCommonUtil.getBaseUrl(ipConfig);
            return profitmartClient.loginWithCredentials(
                    baseUrl,
                    request.getClientId(),
                    password,
                    request.getTwoFa() != null ? request.getTwoFa() : request.getTotpReferenceKey(),
                    request.getApiKey(),
                    request.getApiSecretKey(),
                    "EasyTrade");
        }
        JSONObject json = new JSONObject();
        json.put("status", true);
        json.put("accessToken", "");
        return json;
    }

    private JSONObject loginZerodha(DematAccountAddRequest request) {
        log.info("Zerodha login attempt | clientId={}", request.getClientId());
        if (request.getTwoFa() != null && !request.getTwoFa().isBlank()) {
            PyBrokerIpConfigEntity ipConfig = getIpConfig(request.getIp());
            String baseUrl = PyCommonUtil.getBaseUrl(ipConfig);
            return zerodhaClient.login(baseUrl, request.getClientId(), request.getApiKey(), request.getApiSecretKey(), request.getTwoFa());
        }
        JSONObject json = new JSONObject();
        json.put("status", true);
        json.put("accessToken", "");
        return json;
    }

    private JSONObject loginGoodwill(DematAccountAddRequest request) {
        log.info("Goodwill login attempt | clientId={}", request.getClientId());
        PyBrokerIpConfigEntity ipConfig = getIpConfig(request.getIp());
        String baseUrl = PyCommonUtil.getBaseUrl(ipConfig);
        return goodwillClient.login(baseUrl, request.getClientId(), request.getApiKey(), request.getApiSecretKey(), request.getMpin());
    }

    // ── ANGELONE ──────────────────────────────────────────────────────────────
    private JSONObject loginAngelOne(DematAccountAddRequest request) {
        log.info("AngelOne login attempt | clientId={}", request.getClientId());

        PyBrokerIpConfigEntity ipConfig = getIpConfig(request.getIp());
        String baseUrl = PyCommonUtil.getBaseUrl(ipConfig);
        String totp    = totpUtil.generate(request.getTotpReferenceKey());

        JSONObject data = angelOneClient.login(
                baseUrl,
                request.getClientId(),
                request.getMpin(),
                totp,
                request.getApiKey());

        if (data == null) {
            throw new RuntimeException(
                    "AngelOne login failed: null response from microservice");
        }

        log.info("AngelOne login SUCCESS | clientId={}", request.getClientId());
        return data;
    }

    // ── MOTILAL ───────────────────────────────────────────────────────────────
    // Motilal response structure:
    //   Success: { "status": "SUCCESS", "message": "SUCCESS", "errorcode": "", "data": { ... } }
    //   Failure: { "status": "FAILURE", "message": "...",     "errorcode": "MO1000", "data": "null" }
    //
    // Notes:
    //   - "status" is a string "SUCCESS" / "FAILURE"  (not boolean)
    //   - "errorcode" is always lowercase
    //   - "data" on failure is the string "null", not JSON null or JSONObject.NULL
    private JSONObject loginMotilal(DematAccountAddRequest request) {
        log.info("Motilal login attempt | clientId={}", request.getClientId());

        PyBrokerIpConfigEntity ipConfig = getIpConfig(request.getIp());
        String baseUrl = PyCommonUtil.getBaseUrl(ipConfig);
        String totp    = totpUtil.generate(request.getTotpReferenceKey());
        String hashedPassword = profileLoader.generateMotilalPasswordHash(
                request.getMpin(), request.getApiKey());

        // ── Step 1: Login ─────────────────────────────────────────────────────
        JSONObject loginResponse = motilalClient.login(
                baseUrl,
                request.getClientId(),
                hashedPassword,
                request.getTwoFa(),
                totp,
                request.getApiKey(),
                request.getApiSecretKey(),
                request.getVendorInfo());

        validateMotilalResponse(loginResponse, "Login", request.getClientId());

        // ── Step 2: Get access token ──────────────────────────────────────────
        JSONObject tokenResponse = motilalClient.getAccessToken(
                baseUrl,
                loginResponse.getString("AuthToken"),
                request.getApiKey(),
                request.getApiSecretKey(),
                request.getVendorInfo());

        validateMotilalResponse(tokenResponse, "GetAccessToken", request.getClientId());

        loginResponse.put("AccessToken", tokenResponse.get("accesstoken"));

        log.info("Motilal login SUCCESS | clientId={}", request.getClientId());
        return loginResponse;
    }

    // ── DHAN ──────────────────────────────────────────────────────────────────
    private JSONObject loginDhan(DematAccountAddRequest request) {
        log.info("Dhan login attempt | clientId={}", request.getClientId());

        PyBrokerIpConfigEntity ipConfig = getIpConfig(request.getIp());
        String baseUrl = PyCommonUtil.getBaseUrl(ipConfig);
        String totp    = totpUtil.generate(request.getTotpReferenceKey());

        JSONObject json = dhanClient.login(
                baseUrl,
                request.getClientId(),
                request.getMpin(),
                totp);

        log.info("Dhan login SUCCESS | clientId={}", request.getClientId());
        return json;
    }

    // ── UPSTOX ────────────────────────────────────────────────────────────────
    private JSONObject loginUpstox(DematAccountAddRequest request) {
        log.info("Upstox login attempt | clientId={}", request.getClientId());

        // If authorization code is provided, exchange it for access token via py-broker-service
        if (request.getTwoFa() != null && !request.getTwoFa().isBlank()) {
            PyBrokerIpConfigEntity ipConfig = getIpConfig(request.getIp());
            String baseUrl = PyCommonUtil.getBaseUrl(ipConfig);
            return upstoxMicroserviceClient.login(
                    baseUrl,
                    request.getClientId(),
                    request.getApiKey(),
                    request.getApiSecretKey(),
                    request.getTwoFa(),
                    request.getRedirectUri());
        }

        // If initial credentials are saved without an authorization code yet,
        // create account in Disconnected status so user can authenticate via OAuth
        JSONObject json = new JSONObject();
        json.put("status", true);
        json.put("accessToken", "");
        return json;
    }

    // ── MOTILAL RESPONSE VALIDATOR ────────────────────────────────────────────
    /**
     * Validates a Motilal API response.
     * Throws RuntimeException with a mapped error message on failure.
     *
     * @param response  raw JSONObject returned by the Motilal microservice client
     * @param step      label for logging (e.g. "Login", "GetAccessToken")
     * @param clientId  for logging
     */
    private void validateMotilalResponse(JSONObject response, String step, String clientId) {
        if (response == null) {
            log.error("Motilal {}: null response | clientId={}", step, clientId);
            throw new RuntimeException(
                    "Motilal " + step + " failed: no response from broker");
        }

        // "status" is a string: "SUCCESS" or "FAILURE"
        String status    = response.optString("status", "");
        String errorCode = response.optString("errorcode", ""); // always lowercase
        String message   = response.optString("message", step + " failed");

        if (!"SUCCESS".equalsIgnoreCase(status)) {
            log.error("Motilal {} rejected | clientId={} errorCode={} message={}",
                    step, clientId, errorCode, message);
            throw new RuntimeException(buildMotilalErrorMessage(errorCode, message));
        }

        // "data" on failure comes as the string "null" — guard against it
        Object dataRaw = response.opt("data");
        if (dataRaw != null && "null".equals(dataRaw.toString())) {
            log.warn("Motilal {}: data is string 'null' despite SUCCESS status | clientId={}",
                    step, clientId);
            // Don't throw — some endpoints return "null" data on success (e.g. cancel)
            // Only throw if status was not SUCCESS (handled above)
        }

        log.info("Motilal {} validated OK | clientId={}", step, clientId);
    }

    // ── MOTILAL ERROR CODE MAPPER ─────────────────────────────────────────────
    private String buildMotilalErrorMessage(String errorCode, String brokerMessage) {
        String friendly = switch (errorCode) {

            // ── Token errors ──────────────────────────────────────────────────
            case "MO8001" -> "Invalid token — please re-login";
            case "MO8002" -> "Token expired — please re-login";
            case "MO8003" -> "Token missing — authentication token was not sent";
            case "MO8050" -> "Invalid refresh token — please re-login";
            case "MO8051" -> "Refresh token expired — please re-login";
            case "MO8052" -> "Dashboard session invalid — please re-login";

            // ── Login / credential errors ─────────────────────────────────────
            case "MO1000" -> "Invalid user ID or password — check your credentials";
            case "MO1001" -> "Invalid user ID — check the client code";
            case "MO1002" -> "Invalid password length — check Motilal password requirements";
            case "MO1003" -> "Client already exists — use UPDATE instead of ADD";
            case "MO1004" -> "Invalid API key — check the API key in your Motilal account";
            case "MO1005" -> "API key not found — check the API key in your Motilal account";
            case "MO1006" -> "User not authorized for live trading — contact Motilal support";
            case "MO1007" -> "Invalid 2FA answer — check the date of birth or PAN entered";
            case "MO1008" -> "Invalid request checksum — possible data corruption, retry";
            case "MO1011" -> "Client not logged in — please login first";
            case "MO1093" -> "Invalid TOTP — check your authenticator app";
            case "MO1094" -> "Invalid TOTP key — re-scan the QR code in your authenticator";
            case "MO1095" -> "OTP session invalid — start login again";
            case "MO1096" -> "Too many OTP attempts — wait before retrying";
            case "MO1097" -> "Authorization verification failed — contact Motilal support";
            case "MO1098" -> "Dealer access invalid";
            case "MO1099" -> "Invalid OTP format";
            case "MO1100" -> "Login access invalid — account may be restricted";

            // ── Session errors ────────────────────────────────────────────────
            case "MO2000" -> "Maximum active sessions exceeded — logout from other devices";

            // ── Order errors ──────────────────────────────────────────────────
            case "MO1012" -> "Invalid product type — use DELIVERY, NORMAL, etc.";
            case "MO1013" -> "Order not found — the order ID may be invalid or settled";
            case "MO1014" -> "Trade not found";
            case "MO1015" -> "Holdings not found for this account";
            case "MO1016" -> "Positions not found for this account";
            case "MO1050" -> "Invalid input parameter — check request fields";
            case "MO1051" -> "Invalid exchange — use NSE, BSE, NFO, etc.";
            case "MO1052" -> "Invalid buy/sell value — use B or S";
            case "MO1053" -> "Invalid book type";
            case "MO1054" -> "Invalid order duration — use DAY, IOC, etc.";
            case "MO1055" -> "Invalid quantity";
            case "MO1056" -> "Invalid disclosed quantity";
            case "MO1057" -> "Invalid product type — use DELIVERY, NORMAL (not INTRADAY/MIS)";
            case "MO1058" -> "Invalid scrip code — check the symbol token";
            case "MO1059" -> "Quantity must be in multiples of market lot";
            case "MO1060" -> "Invalid order ID";
            case "MO1061" -> "Invalid AMO order input";
            case "MO1062" -> "Client code missing in request";
            case "MO1063" -> "Invalid Good Till Date format";
            case "MO1064" -> "Invalid Algo ID";
            case "MO1065" -> "Order status is unknown";
            case "MO1066" -> "Order is already cancelled";
            case "MO1067" -> "Order is already fully traded";
            case "MO1068" -> "Order is already rejected";
            case "MO1069" -> "Order is in error state";
            case "MO1070" -> "UniqueOrderId missing in request";
            case "MO1071" -> "Invalid disclosed quantity + IOC combination";
            case "MO1072" -> "Market orders not allowed for this product type — use LIMIT";
            case "MO1073" -> "Limit price is below the lower circuit limit";
            case "MO1074" -> "Limit price is above the upper circuit limit";
            case "MO1075" -> "Trigger price is required for this order type";
            case "MO1076" -> "Invalid trigger price";
            case "MO1077" -> "Trigger price must be less than order price";
            case "MO1078" -> "Trigger price must be greater than order price";
            case "MO1079" -> "Invalid trigger price and order type combination";
            case "MO1080" -> "Order tag exceeds allowed length";
            case "MO1081" -> "Order tag contains invalid special characters";
            case "MO1082" -> "Invalid exchange and disclosed quantity combination";
            case "MO1083" -> "Invalid order type and price combination";
            case "MO1084" -> "Invalid exchange and product type combination";
            case "MO1085" -> "Invalid order duration and GTD combination";
            case "MO1086" -> "Invalid exchange and GTC combination";
            case "MO1087" -> "Client code cannot be a dealer ID";
            case "MO1088" -> "Client code cannot be a vendor ID";
            case "MO1089" -> "Invalid lastModifiedTime in modify order request";
            case "MO1090" -> "Invalid qtyTradedToday in modify order request";
            case "MO1091" -> "Invalid modify order URL";
            case "MO1092" -> "Invalid consent check";
            case "MO1101" -> "Invalid time format";
            case "MO1102" -> "Invalid participant code";
            case "MO1103" -> "Bracket orders cannot be modified";
            case "MO1104" -> "Bracket orders cannot be cancelled";

            // ── Header / API config errors ────────────────────────────────────
            case "MO2001" -> "Method not allowed — check HTTP method (GET/POST)";
            case "MO2002" -> "Invalid JSON in request body — check request format";
            case "MO2003" -> "Invalid Accept header";
            case "MO2004" -> "Invalid User-Agent header";
            case "MO2005" -> "Invalid API key in header — check ApiKey header";
            case "MO2006" -> "Invalid API secret key in header";
            case "MO2007" -> "Invalid Authorization header";
            case "MO2008" -> "Invalid MAC address in header";
            case "MO2009" -> "Invalid ClientLocalIP in header";
            case "MO2010" -> "Invalid ClientPublicIP in header";
            case "MO2011" -> "Invalid SourceID in header";
            case "MO2012" -> "Invalid Vendor tag in header";
            case "MO2013" -> "Invalid version number in header";
            case "MO2014" -> "Invalid OS name in header";
            case "MO2015" -> "Invalid OS version in header";
            case "MO2016" -> "Invalid device model in header";
            case "MO2017" -> "Invalid manufacturer in header";
            case "MO2018" -> "Invalid product name in header";
            case "MO2019" -> "Invalid product version in header";
            case "MO2020" -> "Invalid installed App ID in header";
            case "MO2021" -> "Invalid IMEI number in header";
            case "MO2022" -> "Invalid browser name in header";
            case "MO2023" -> "Invalid browser version in header";
            case "MO2024" -> "Invalid latitude in header";
            case "MO2025" -> "Invalid longitude in header";
            case "MO2026" -> "Invalid SDK version in header";

            // ── Network / connectivity errors ─────────────────────────────────
            case "MO5000" -> "Motilal server connectivity failed — try again shortly";
            case "MO5001" -> "Request failed due to network issue — check connectivity";
            case "MO5002" -> "Response failed due to network issue — check connectivity";
            case "MO5003" -> "Invalid order input parameter — check order fields";

            // ── Other ─────────────────────────────────────────────────────────
            case "MO8000" -> "Motilal technical error — try again after some time";
            case "MO3001" -> "Multiple records found — refine the request";
            case "MO2035" -> "IP not whitelisted — add this server IP in your Motilal account";

            // ── Unknown — surface broker message as-is ────────────────────────
            default -> brokerMessage;
        };

        return "Motilal [" + errorCode + "]: " + friendly;
    }

    // ── IP CONFIG HELPER ──────────────────────────────────────────────────────
    private PyBrokerIpConfigEntity getIpConfig(String ipWithPort) {
        String cleanIp = ipWithPort.split(":")[0];
        return pyBrokerIpConfigRepository
                .findByIpAddress(cleanIp)
                .orElseThrow(() -> new RuntimeException("IP not found in DB: " + ipWithPort));
    }
}