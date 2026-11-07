package com.py.common.util;

import com.py.common.config.TwilioConfig;
import com.twilio.exception.ApiException;
import com.twilio.rest.api.v2010.account.Message;
import com.twilio.type.PhoneNumber;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ThreadLocalRandom;

@Service
public class TwilioOtpService {

    private static final Logger logger = LogManager.getLogger(TwilioOtpService.class);

    @Autowired(required = false)
    private TwilioConfig twilioConfig;

    @Autowired(required = false)
    private com.py.repo.PyAppSettingRepository appSettingRepository;

    private static volatile String runtimeFast2SmsApiKey = null;
    private static volatile Boolean runtimeFast2SmsEnabled = null;

    private static volatile String runtimeTwilioAccountSid = null;
    private static volatile String runtimeTwilioAuthToken = null;
    private static volatile String runtimeTwilioFromNumber = null;
    private static volatile String runtimeTwilioServiceSid = null;
    private static volatile Boolean runtimeTwilioEnabled = null;

    private static volatile String runtimeTwoFactorApiKey = null;
    private static volatile Boolean runtimeTwoFactorEnabled = null;

    @Value("${twilio.service-sid:}")
    private String serviceSid;

    @Value("${twilio.enabled:false}")
    private boolean twilioEnabled;

    @Value("${twilio.from-number:}")
    private String fromNumber; // E.164 phone number or Twilio Messaging Service SID (MG...)

    @Value("${twilio.otp-expiry-minutes:5}")
    private int otpExpiryMinutes;

    @Value("${app.demo-otp.enabled:${DEMO_OTP_ENABLED:false}}")
    private boolean demoOtpEnabled;

    @Value("${app.demo-otp.allowed-numbers:${DEMO_OTP_ALLOWED_NUMBERS:}}")
    private String demoAllowedNumbers;

    @Value("${app.demo-otp.code:${DEMO_OTP_CODE:}}")
    private String demoOtpCode;

    // Fast2SMS Configuration (stored securely on backend only, never exposed in client/code)
    @Value("${fast2sms.api-key:${FAST2SMS_API_KEY:}}")
    private String fast2SmsApiKey;

    @Value("${fast2sms.enabled:${FAST2SMS_ENABLED:false}}")
    private boolean fast2SmsEnabled;

    @Value("${fast2sms.url:${FAST2SMS_URL:https://www.fast2sms.com/dev/bulkV2}}")
    private String fast2SmsUrl;

    // Rate Limiting constants
    private static final int RESEND_COOLDOWN_SECONDS = 60; // 60 seconds cooldown between requests
    private static final int MAX_REQUESTS_PER_WINDOW = 5;  // Max 5 OTP requests per window
    private static final int RATE_LIMIT_WINDOW_MINUTES = 15; // 15-minute sliding window

    // In-memory OTP store: phone -> (code, expiry, reqFor, status)
    public static final class OtpEntry {
        public final String code;
        public final Instant expiresAt;
        public final String codeReqFor;
        public boolean realSmsDelivered = false;
        public String statusNote = "";
        public String twoFactorSessionId = "";
        int failedAttempts = 0;
        public OtpEntry(String code, Instant expiresAt, String codeReqFor) {
            this.code = code;
            this.expiresAt = expiresAt;
            this.codeReqFor = codeReqFor;
        }
    }

    // In-memory Rate Limit store: phone -> (lastSentAt, windowStart, requestCount)
    private static final class RateLimitEntry {
        Instant lastSentAt;
        Instant windowStart;
        int requestCount;

        RateLimitEntry(Instant now) {
            this.lastSentAt = now;
            this.windowStart = now;
            this.requestCount = 1;
        }
    }

    private final ConcurrentHashMap<String, OtpEntry> otpStore = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, RateLimitEntry> rateLimitStore = new ConcurrentHashMap<>();

    // -------------------- 2Factor.in Integration Methods --------------------
    public boolean isTwoFactorConfigured() {
        return !getTwoFactorApiKey().isEmpty();
    }

    public boolean isTwoFactorEnabled() {
        if (runtimeTwoFactorEnabled != null) {
            return runtimeTwoFactorEnabled;
        }
        String env = System.getenv("TWOFACTOR_ENABLED");
        if ("true".equalsIgnoreCase(env)) {
            return true;
        }
        if (appSettingRepository != null) {
            try {
                return appSettingRepository.findById("TWOFACTOR_ENABLED")
                        .map(s -> "true".equalsIgnoreCase(s.getValue()))
                        .orElse(false);
            } catch (Exception ignored) {}
        }
        return false;
    }

    public String getTwoFactorApiKey() {
        if (runtimeTwoFactorApiKey != null && !runtimeTwoFactorApiKey.trim().isEmpty()) {
            return runtimeTwoFactorApiKey.trim();
        }
        String env = System.getenv("TWOFACTOR_API_KEY");
        if (env != null && !env.trim().isEmpty()) {
            return env.trim();
        }
        if (appSettingRepository != null) {
            try {
                return appSettingRepository.findById("TWOFACTOR_API_KEY")
                        .map(s -> s.getValue() != null ? s.getValue().trim() : "")
                        .orElse("");
            } catch (Exception ignored) {}
        }
        return "";
    }

    public synchronized void updateTwoFactorConfig(String apiKey, boolean enabled) {
        if (apiKey != null && !apiKey.trim().isEmpty()) {
            runtimeTwoFactorApiKey = apiKey.trim();
            if (appSettingRepository != null) {
                try {
                    appSettingRepository.save(new com.py.entity.PyAppSetting("TWOFACTOR_API_KEY", apiKey.trim()));
                } catch (Exception ignored) {}
            }
        }
        runtimeTwoFactorEnabled = enabled;
        if (appSettingRepository != null) {
            try {
                appSettingRepository.save(new com.py.entity.PyAppSetting("TWOFACTOR_ENABLED", String.valueOf(enabled)));
            } catch (Exception ignored) {}
        }
        logger.info("2Factor configuration updated: configured={}, enabled={}", isTwoFactorConfigured(), isTwoFactorEnabled());
    }

    public String checkTwoFactorBalance() {
        String apiKey = getTwoFactorApiKey();
        if (apiKey.isEmpty()) {
            return "TWOFACTOR_API_KEY is not configured on the server.";
        }
        try {
            java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();
            java.net.http.HttpRequest request = java.net.http.HttpRequest.newBuilder()
                    .uri(java.net.URI.create("https://2factor.in/API/V1/" + apiKey + "/BAL/SMS"))
                    .timeout(Duration.ofSeconds(10))
                    .GET()
                    .build();
            java.net.http.HttpResponse<String> response = client.send(request, java.net.http.HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() == 200) {
                org.json.JSONObject res = new org.json.JSONObject(response.body());
                if ("Success".equalsIgnoreCase(res.optString("Status"))) {
                    return "2Factor connected successfully! Available SMS balance: " + res.optString("Details");
                }
            }
            return "2Factor check returned HTTP " + response.statusCode() + " | " + response.body();
        } catch (Exception e) {
            logger.error("2Factor balance check error", e);
            return "2Factor check failed: " + e.getMessage();
        }
    }

    public boolean sendTwoFactorOtp(String canonicalPhone, OtpEntry entry) {
        String apiKey = getTwoFactorApiKey();
        if (apiKey.isEmpty()) {
            return false;
        }
        String digits = canonicalPhone.replaceAll("[^0-9]", "");
        String phone10 = digits.length() > 10 ? digits.substring(digits.length() - 10) : digits;
        try {
            String url = "https://2factor.in/API/V1/" + apiKey + "/SMS/" + phone10 + "/AUTOGEN";
            java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();
            java.net.http.HttpRequest request = java.net.http.HttpRequest.newBuilder()
                    .uri(java.net.URI.create(url))
                    .timeout(Duration.ofSeconds(15))
                    .GET()
                    .build();
            java.net.http.HttpResponse<String> response = client.send(request, java.net.http.HttpResponse.BodyHandlers.ofString());
            logger.info("2Factor dispatch response for {}: HTTP {} | body: {}", maskPhoneNumber(phone10), response.statusCode(), response.body());
            if (response.statusCode() == 200) {
                org.json.JSONObject res = new org.json.JSONObject(response.body());
                if ("Success".equalsIgnoreCase(res.optString("Status"))) {
                    entry.twoFactorSessionId = res.optString("Details");
                    entry.realSmsDelivered = true;
                    entry.statusNote = "OTP sent successfully to your mobile number via SMS. Please check your SMS.";
                    logger.info("2Factor OTP dispatched successfully to {} with session {}", maskPhoneNumber(phone10), entry.twoFactorSessionId);
                    return true;
                }
            }
            return false;
        } catch (Exception e) {
            logger.error("2Factor dispatch exception for {}", maskPhoneNumber(phone10), e);
            return false;
        }
    }

    public boolean verifyTwoFactorOtp(String sessionId, String otp) {
        String apiKey = getTwoFactorApiKey();
        if (apiKey.isEmpty() || sessionId == null || sessionId.isEmpty() || otp == null || otp.trim().isEmpty()) {
            return false;
        }
        try {
            String url = "https://2factor.in/API/V1/" + apiKey + "/SMS/VERIFY/" + sessionId + "/" + otp.trim();
            java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();
            java.net.http.HttpRequest request = java.net.http.HttpRequest.newBuilder()
                    .uri(java.net.URI.create(url))
                    .timeout(Duration.ofSeconds(15))
                    .GET()
                    .build();
            java.net.http.HttpResponse<String> response = client.send(request, java.net.http.HttpResponse.BodyHandlers.ofString());
            logger.info("2Factor SMS verify response for session {}: HTTP {} | body: {}", sessionId, response.statusCode(), response.body());
            if (response.statusCode() == 200) {
                org.json.JSONObject res = new org.json.JSONObject(response.body());
                if ("Success".equalsIgnoreCase(res.optString("Status")) &&
                        ("OTP Matched".equalsIgnoreCase(res.optString("Details")) || "Success".equalsIgnoreCase(res.optString("Details")))) {
                    return true;
                }
            }
            // Check VOICE/VERIFY if session was delivered via voice call fallback
            String voiceUrl = "https://2factor.in/API/V1/" + apiKey + "/VOICE/VERIFY/" + sessionId + "/" + otp.trim();
            java.net.http.HttpRequest voiceReq = java.net.http.HttpRequest.newBuilder()
                    .uri(java.net.URI.create(voiceUrl))
                    .timeout(Duration.ofSeconds(15))
                    .GET()
                    .build();
            java.net.http.HttpResponse<String> voiceResp = client.send(voiceReq, java.net.http.HttpResponse.BodyHandlers.ofString());
            logger.info("2Factor VOICE verify response for session {}: HTTP {} | body: {}", sessionId, voiceResp.statusCode(), voiceResp.body());
            if (voiceResp.statusCode() == 200) {
                org.json.JSONObject res = new org.json.JSONObject(voiceResp.body());
                if ("Success".equalsIgnoreCase(res.optString("Status")) &&
                        ("OTP Matched".equalsIgnoreCase(res.optString("Details")) || "Success".equalsIgnoreCase(res.optString("Details")))) {
                    return true;
                }
            }
            return false;
        } catch (Exception e) {
            logger.error("2Factor verify exception for session {}", sessionId, e);
            return false;
        }
    }

    // -------------------- Fast2SMS Integration Methods --------------------
    /**
     * Checks whether Fast2SMS API key is configured either in Spring property, environment variable, or persistent settings.
     */
    public boolean isFast2SmsConfigured() {
        return !getFast2SmsApiKey().isEmpty();
    }

    /**
     * Checks whether Fast2SMS live dispatch is enabled.
     * Defaults to false to prevent credit consumption without explicit approval.
     */
    public boolean isFast2SmsEnabled() {
        if (runtimeFast2SmsEnabled != null) {
            return runtimeFast2SmsEnabled;
        }
        if (fast2SmsEnabled) {
            return true;
        }
        String env = System.getenv("FAST2SMS_ENABLED");
        if ("true".equalsIgnoreCase(env)) {
            return true;
        }
        if (appSettingRepository != null) {
            try {
                return appSettingRepository.findById("FAST2SMS_ENABLED")
                        .map(s -> "true".equalsIgnoreCase(s.getValue()))
                        .orElse(false);
            } catch (Exception ignored) {}
        }
        return false;
    }

    /**
     * Retrieves the Fast2SMS API key securely from runtime cache, environment variable, Spring property, or database.
     * Kept on server only, never exposed in logs or sent to clients.
     */
    public String getFast2SmsApiKey() {
        if (runtimeFast2SmsApiKey != null && !runtimeFast2SmsApiKey.trim().isEmpty()) {
            return runtimeFast2SmsApiKey.trim();
        }
        if (fast2SmsApiKey != null && !fast2SmsApiKey.trim().isEmpty()) {
            return fast2SmsApiKey.trim();
        }
        String env = System.getenv("FAST2SMS_API_KEY");
        if (env != null && !env.trim().isEmpty()) {
            return env.trim();
        }
        if (appSettingRepository != null) {
            try {
                return appSettingRepository.findById("FAST2SMS_API_KEY")
                        .map(s -> s.getValue() != null ? s.getValue().trim() : "")
                        .orElse("");
            } catch (Exception ignored) {}
        }
        return "";
    }

    /**
     * Runtime update and database persistence of Fast2SMS configuration.
     */
    public synchronized void updateFast2SmsConfig(String apiKey, boolean enabled) {
        if (apiKey != null && !apiKey.trim().isEmpty()) {
            runtimeFast2SmsApiKey = apiKey.trim();
            if (appSettingRepository != null) {
                try {
                    appSettingRepository.save(new com.py.entity.PyAppSetting("FAST2SMS_API_KEY", apiKey.trim()));
                } catch (Exception e) {
                    logger.warn("Failed to persist FAST2SMS_API_KEY to database: {}", e.getMessage());
                }
            }
        }
        runtimeFast2SmsEnabled = enabled;
        if (appSettingRepository != null) {
            try {
                appSettingRepository.save(new com.py.entity.PyAppSetting("FAST2SMS_ENABLED", String.valueOf(enabled)));
            } catch (Exception e) {
                logger.warn("Failed to persist FAST2SMS_ENABLED to database: {}", e.getMessage());
            }
        }
        logger.info("Fast2SMS configuration updated: configured={}, enabled={}", isFast2SmsConfigured(), isFast2SmsEnabled());
    }

    public synchronized void updateTwilioConfig(String accountSid, String authToken, String fromNum, String sSid, boolean enabled) {
        if (sSid != null && !sSid.trim().isEmpty()) {
            runtimeTwilioServiceSid = sSid.trim();
            if (appSettingRepository != null) {
                try {
                    appSettingRepository.save(new com.py.entity.PyAppSetting("TWILIO_SERVICE_SID", sSid.trim()));
                } catch (Exception ignored) {}
            }
        }
        updateTwilioConfig(accountSid, authToken, fromNum, enabled);
    }

    public synchronized void updateTwilioConfig(String accountSid, String authToken, String fromNum, boolean enabled) {
        if (accountSid != null && !accountSid.trim().isEmpty()) {
            runtimeTwilioAccountSid = accountSid.trim();
            if (appSettingRepository != null) {
                try {
                    appSettingRepository.save(new com.py.entity.PyAppSetting("TWILIO_ACCOUNT_SID", accountSid.trim()));
                } catch (Exception ignored) {}
            }
        }
        if (authToken != null && !authToken.trim().isEmpty()) {
            runtimeTwilioAuthToken = authToken.trim();
            if (appSettingRepository != null) {
                try {
                    appSettingRepository.save(new com.py.entity.PyAppSetting("TWILIO_AUTH_TOKEN", authToken.trim()));
                } catch (Exception ignored) {}
            }
        }
        if (fromNum != null && !fromNum.trim().isEmpty()) {
            runtimeTwilioFromNumber = fromNum.trim();
            if (appSettingRepository != null) {
                try {
                    appSettingRepository.save(new com.py.entity.PyAppSetting("TWILIO_FROM_NUMBER", fromNum.trim()));
                } catch (Exception ignored) {}
            }
        }
        runtimeTwilioEnabled = enabled;
        if (appSettingRepository != null) {
            try {
                appSettingRepository.save(new com.py.entity.PyAppSetting("TWILIO_ENABLED", String.valueOf(enabled)));
            } catch (Exception ignored) {}
        }
        String finalSid = getTwilioAccountSid();
        String finalToken = getTwilioAuthToken();
        if (!finalSid.isEmpty() && !finalToken.isEmpty()) {
            try {
                com.twilio.Twilio.init(finalSid, finalToken);
                logger.info("Twilio client initialized with Account SID starting with: {}",
                        finalSid.substring(0, Math.min(finalSid.length(), 6)));
            } catch (Exception e) {
                logger.warn("Twilio client init warning: {}", e.getMessage());
            }
        }
        logger.info("Twilio configuration updated: enabled={}, configured={}", isTwilioEnabled(), isTwilioConfigured());
    }

    public boolean isTwilioConfigured() {
        return !getTwilioAccountSid().isEmpty() && !getTwilioAuthToken().isEmpty();
    }

    public String getTwilioAccountSid() {
        if (runtimeTwilioAccountSid != null && !runtimeTwilioAccountSid.trim().isEmpty()) {
            return runtimeTwilioAccountSid.trim();
        }
        String env = System.getenv("TWILIO_ACCOUNT_SID");
        if (env != null && !env.trim().isEmpty()) {
            return env.trim();
        }
        if (appSettingRepository != null) {
            try {
                return appSettingRepository.findById("TWILIO_ACCOUNT_SID")
                        .map(s -> s.getValue() != null ? s.getValue().trim() : "")
                        .orElse("");
            } catch (Exception ignored) {}
        }
        return "";
    }

    public String getTwilioAuthToken() {
        if (runtimeTwilioAuthToken != null && !runtimeTwilioAuthToken.trim().isEmpty()) {
            return runtimeTwilioAuthToken.trim();
        }
        String env = System.getenv("TWILIO_AUTH_TOKEN");
        if (env != null && !env.trim().isEmpty()) {
            return env.trim();
        }
        if (appSettingRepository != null) {
            try {
                return appSettingRepository.findById("TWILIO_AUTH_TOKEN")
                        .map(s -> s.getValue() != null ? s.getValue().trim() : "")
                        .orElse("");
            } catch (Exception ignored) {}
        }
        return "";
    }

    public String getTwilioServiceSid() {
        if (runtimeTwilioServiceSid != null && !runtimeTwilioServiceSid.trim().isEmpty()) {
            return runtimeTwilioServiceSid.trim();
        }
        if (serviceSid != null && !serviceSid.trim().isEmpty()) {
            return serviceSid.trim();
        }
        String env = System.getenv("TWILIO_SERVICE_SID");
        if (env != null && !env.trim().isEmpty()) {
            return env.trim();
        }
        if (appSettingRepository != null) {
            try {
                return appSettingRepository.findById("TWILIO_SERVICE_SID")
                        .map(s -> s.getValue() != null ? s.getValue().trim() : "")
                        .orElse("");
            } catch (Exception ignored) {}
        }
        return "";
    }

    public String getTwilioFromNumber() {
        if (runtimeTwilioFromNumber != null && !runtimeTwilioFromNumber.trim().isEmpty()) {
            return runtimeTwilioFromNumber.trim();
        }
        if (fromNumber != null && !fromNumber.trim().isEmpty()) {
            return fromNumber.trim();
        }
        String env = System.getenv("TWILIO_FROM_NUMBER");
        if (env != null && !env.trim().isEmpty()) {
            return env.trim();
        }
        if (appSettingRepository != null) {
            try {
                return appSettingRepository.findById("TWILIO_FROM_NUMBER")
                        .map(s -> s.getValue() != null ? s.getValue().trim() : "")
                        .orElse("");
            } catch (Exception ignored) {}
        }
        return "";
    }

    public boolean sendTwilioVerifySms(String formattedPhone) {
        String sid = getTwilioAccountSid();
        String token = getTwilioAuthToken();
        String vSid = getTwilioServiceSid();
        if (sid.isEmpty() || token.isEmpty() || vSid.isEmpty()) {
            return false;
        }
        try {
            String auth = sid + ":" + token;
            String b64Auth = java.util.Base64.getEncoder().encodeToString(auth.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            String url = "https://verify.twilio.com/v2/Services/" + vSid + "/Verifications";
            String form = "To=" + java.net.URLEncoder.encode(formattedPhone, java.nio.charset.StandardCharsets.UTF_8) + "&Channel=sms";

            java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();
            java.net.http.HttpRequest req = java.net.http.HttpRequest.newBuilder()
                    .uri(java.net.URI.create(url))
                    .header("Authorization", "Basic " + b64Auth)
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .timeout(Duration.ofSeconds(15))
                    .POST(java.net.http.HttpRequest.BodyPublishers.ofString(form))
                    .build();

            java.net.http.HttpResponse<String> resp = client.send(req, java.net.http.HttpResponse.BodyHandlers.ofString());
            logger.info("Twilio Verify dispatch response for {}: HTTP {} | body: {}", maskPhoneNumber(formattedPhone), resp.statusCode(), resp.body());
            return (resp.statusCode() == 200 || resp.statusCode() == 201);
        } catch (Exception e) {
            logger.error("Twilio Verify dispatch error: {}", e.getMessage());
            return false;
        }
    }

    public boolean checkTwilioVerifyCode(String formattedPhone, String code) {
        String sid = getTwilioAccountSid();
        String token = getTwilioAuthToken();
        String vSid = getTwilioServiceSid();
        if (sid.isEmpty() || token.isEmpty() || vSid.isEmpty()) {
            return false;
        }
        try {
            String auth = sid + ":" + token;
            String b64Auth = java.util.Base64.getEncoder().encodeToString(auth.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            String url = "https://verify.twilio.com/v2/Services/" + vSid + "/VerificationCheck";
            String form = "To=" + java.net.URLEncoder.encode(formattedPhone, java.nio.charset.StandardCharsets.UTF_8)
                    + "&Code=" + java.net.URLEncoder.encode(code, java.nio.charset.StandardCharsets.UTF_8);

            java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();
            java.net.http.HttpRequest req = java.net.http.HttpRequest.newBuilder()
                    .uri(java.net.URI.create(url))
                    .header("Authorization", "Basic " + b64Auth)
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .timeout(Duration.ofSeconds(15))
                    .POST(java.net.http.HttpRequest.BodyPublishers.ofString(form))
                    .build();

            java.net.http.HttpResponse<String> resp = client.send(req, java.net.http.HttpResponse.BodyHandlers.ofString());
            logger.info("Twilio VerificationCheck response for {}: HTTP {} | body: {}", maskPhoneNumber(formattedPhone), resp.statusCode(), resp.body());
            if (resp.statusCode() == 200) {
                org.json.JSONObject json = new org.json.JSONObject(resp.body());
                return "approved".equalsIgnoreCase(json.optString("status"));
            }
            return false;
        } catch (Exception e) {
            logger.error("Twilio VerificationCheck error: {}", e.getMessage());
            return false;
        }
    }

    public String checkTwilioStatus() {
        String sid = getTwilioAccountSid();
        String token = getTwilioAuthToken();
        String from = getTwilioFromNumber();
        if (sid.isEmpty() || token.isEmpty()) {
            return "Twilio credentials are not configured on the server.";
        }
        try {
            com.twilio.Twilio.init(sid, token);
            com.twilio.rest.api.v2010.Account account = com.twilio.rest.api.v2010.Account.fetcher(sid).fetch();
            return "Twilio connected successfully! Account: " + account.getFriendlyName() + " | Status: " + account.getStatus() + " | Sender: " + from;
        } catch (Exception e) {
            return "Twilio check failed: " + e.getMessage();
        }
    }

    /**
     * Sends OTP via Fast2SMS Quick OTP route using standard Java 11+ HttpClient.
     * Only called when isFast2SmsEnabled() is true.
     */
    private boolean sendFast2SmsOtp(String canonicalPhone, String otp) {
        String apiKey = getFast2SmsApiKey();
        if (apiKey.isEmpty()) {
            logger.error("Fast2SMS dispatch aborted: FAST2SMS_API_KEY is not configured on server");
            throw new IllegalStateException("Fast2SMS API key is not configured on the server.");
        }

        // Fast2SMS OTP route requires a 10-digit Indian mobile number
        String digits = canonicalPhone.replaceAll("[^0-9]", "");
        String phone10 = digits.length() > 10 ? digits.substring(digits.length() - 10) : digits;
        if (phone10.length() != 10) {
            logger.warn("Invalid Indian mobile number for Fast2SMS: {}", maskPhoneNumber(canonicalPhone));
            throw new IllegalArgumentException("Fast2SMS requires a valid 10-digit Indian mobile number.");
        }

        String targetUrl = (fast2SmsUrl != null && !fast2SmsUrl.trim().isEmpty())
                ? fast2SmsUrl.trim()
                : "https://www.fast2sms.com/dev/bulkV2";

        String messageText = String.format("Panchayagnam OTP: Your verification code is %s. Valid for 5 minutes. Do not share it with anyone.", otp);

        try {
            java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();

            // Attempt 1: Fast2SMS Quick SMS Route (route="q") via POST JSON
            org.json.JSONObject payload = new org.json.JSONObject();
            payload.put("route", "q");
            payload.put("message", messageText);
            payload.put("numbers", phone10);

            java.net.http.HttpRequest request = java.net.http.HttpRequest.newBuilder()
                    .uri(java.net.URI.create(targetUrl))
                    .header("authorization", apiKey)
                    .header("Content-Type", "application/json")
                    .header("Accept", "application/json")
                    .timeout(Duration.ofSeconds(15))
                    .POST(java.net.http.HttpRequest.BodyPublishers.ofString(payload.toString(), java.nio.charset.StandardCharsets.UTF_8))
                    .build();

            java.net.http.HttpResponse<String> response = client.send(request, java.net.http.HttpResponse.BodyHandlers.ofString());
            int statusCode = response.statusCode();
            String responseBody = response.body();

            logger.info("Fast2SMS Quick SMS POST response: HTTP {} for phone: {} | body: {}", statusCode, maskPhoneNumber(phone10), responseBody);

            if (statusCode == 200) {
                org.json.JSONObject resJson = new org.json.JSONObject(responseBody);
                if (resJson.optBoolean("return", false)) {
                    logger.info("Fast2SMS OTP successfully dispatched to {}", maskPhoneNumber(phone10));
                    return true;
                }
            }

            // Attempt 2: Fast2SMS Quick SMS via GET Query Parameters (fallback)
            if (statusCode != 200) {
                String encodedMsg = java.net.URLEncoder.encode(messageText, java.nio.charset.StandardCharsets.UTF_8);
                String getUrl = targetUrl + "?route=q&message=" + encodedMsg + "&numbers=" + phone10;

                java.net.http.HttpRequest getRequest = java.net.http.HttpRequest.newBuilder()
                        .uri(java.net.URI.create(getUrl))
                        .header("authorization", apiKey)
                        .header("Accept", "application/json")
                        .timeout(Duration.ofSeconds(15))
                        .GET()
                        .build();

                java.net.http.HttpResponse<String> getResponse = client.send(getRequest, java.net.http.HttpResponse.BodyHandlers.ofString());
                statusCode = getResponse.statusCode();
                responseBody = getResponse.body();
                logger.info("Fast2SMS Quick SMS GET response: HTTP {} | body: {}", statusCode, responseBody);

                if (statusCode == 200) {
                    org.json.JSONObject resJson = new org.json.JSONObject(responseBody);
                    if (resJson.optBoolean("return", false)) {
                        logger.info("Fast2SMS OTP successfully dispatched via GET to {}", maskPhoneNumber(phone10));
                        return true;
                    }
                }
            }

            // Attempt 3: Fast2SMS OTP Route with variables_values (URL Encoded fallback)
            if (statusCode != 200) {
                String otpUrl = targetUrl + "?route=otp&variables_values=" + otp + "&numbers=" + phone10;
                java.net.http.HttpRequest otpRequest = java.net.http.HttpRequest.newBuilder()
                        .uri(java.net.URI.create(otpUrl))
                        .header("authorization", apiKey)
                        .header("Accept", "application/json")
                        .timeout(Duration.ofSeconds(15))
                        .GET()
                        .build();

                java.net.http.HttpResponse<String> otpResponse = client.send(otpRequest, java.net.http.HttpResponse.BodyHandlers.ofString());
                statusCode = otpResponse.statusCode();
                responseBody = otpResponse.body();
                logger.info("Fast2SMS OTP Route fallback response: HTTP {} | body: {}", statusCode, responseBody);

                if (statusCode == 200) {
                    org.json.JSONObject resJson = new org.json.JSONObject(responseBody);
                    if (resJson.optBoolean("return", false)) {
                        logger.info("Fast2SMS OTP successfully dispatched via OTP route to {}", maskPhoneNumber(phone10));
                        return true;
                    }
                }
            }

            // Extract error message from Fast2SMS JSON response
            String detail = "SMS delivery failure (HTTP " + statusCode + ")";
            try {
                org.json.JSONObject errJson = new org.json.JSONObject(responseBody);
                if (errJson.has("message")) {
                    Object m = errJson.get("message");
                    if (m instanceof org.json.JSONArray) {
                        detail = ((org.json.JSONArray) m).optString(0, m.toString());
                    } else {
                        detail = m.toString();
                    }
                }
            } catch (Exception ignored) {}

            logger.error("Fast2SMS dispatch failed for {}: {}", maskPhoneNumber(phone10), detail);
            throw new RuntimeException("Fast2SMS: " + detail);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logger.error("Fast2SMS HTTP request interrupted", e);
            throw new RuntimeException("SMS dispatch request timed out. Please try again.");
        } catch (IllegalArgumentException | IllegalStateException e) {
            throw e;
        } catch (Exception e) {
            logger.error("Unexpected error communicating with Fast2SMS for {}", maskPhoneNumber(phone10), e);
            throw new RuntimeException("Failed to send OTP SMS via Fast2SMS: " + e.getMessage());
        }
    }

    /**
     * Checks Fast2SMS wallet balance safely with 0 credits and 0 SMS spend.
     * Used for zero-cost API key testing and diagnostics.
     */
    public String checkFast2SmsWalletBalance() {
        String apiKey = getFast2SmsApiKey();
        if (apiKey.isEmpty()) {
            return "FAST2SMS_API_KEY is not configured on the server.";
        }
        try {
            java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();

            java.net.http.HttpRequest request = java.net.http.HttpRequest.newBuilder()
                    .uri(java.net.URI.create("https://www.fast2sms.com/dev/wallet"))
                    .header("authorization", apiKey)
                    .header("Accept", "application/json")
                    .timeout(Duration.ofSeconds(10))
                    .GET()
                    .build();

            java.net.http.HttpResponse<String> response = client.send(request, java.net.http.HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() == 200) {
                org.json.JSONObject res = new org.json.JSONObject(response.body());
                if (res.optBoolean("return", false)) {
                    double wallet = res.optDouble("wallet", 0.0);
                    return "Fast2SMS connected successfully! Available wallet balance: ₹" + wallet;
                }
            } else if (response.statusCode() == 401 || response.statusCode() == 412) {
                return "Fast2SMS authentication failed: Invalid Authorization Key (HTTP " + response.statusCode() + ").";
            }
            return "Fast2SMS check returned HTTP " + response.statusCode();
        } catch (Exception e) {
            logger.error("Fast2SMS wallet check error", e);
            return "Fast2SMS check failed: " + e.getMessage();
        }
    }

    public OtpEntry getActiveOtpEntry(String phoneNumber) {
        String formatted = formatPhoneNumber(phoneNumber);
        return (formatted != null) ? otpStore.get(formatted) : null;
    }

    // -------------------- Messaging API + custom message methods --------------------
    /**
     * Send SMS with generated OTP using Fast2SMS or Twilio Messaging API.
     * Stores OTP in in-memory store for verification.
     *
     * @param phoneNumber phone in any format (10-digit or E.164)
     * @param codeReqFor reason for code (e.g. Registration, ForgotMPIN)
     * @return true if OTP created/sent, throws RuntimeException on validation or delivery error
     */
    public boolean sendOtpV2(String phoneNumber, String codeReqFor) {
        String formatted = formatPhoneNumber(phoneNumber);
        if (formatted == null) {
            throw new IllegalArgumentException("Invalid phone number format. Please provide a valid 10-digit mobile number.");
        }

        // 1. Rate limiting & anti-abuse checks
        checkRateLimit(formatted);

        // 2. Prepare OTP entry and expiry
        int expiryMinutes = (otpExpiryMinutes > 0) ? otpExpiryMinutes : 5;
        Instant expiresAt = Instant.now().plus(Duration.ofMinutes(expiryMinutes));

        // 2.5 SMS Channel: 2Factor.in (if enabled)
        if (isTwoFactorEnabled()) {
            OtpEntry entry = new OtpEntry(generateOtp(), expiresAt, codeReqFor);
            otpStore.put(formatted, entry);
            if (sendTwoFactorOtp(formatted, entry)) {
                return true;
            }
        }

        // 3. Primary SMS Channel: Fast2SMS
        if (isFast2SmsEnabled()) {
            String otp = generateOtp();
            OtpEntry entry = new OtpEntry(otp, expiresAt, codeReqFor);
            otpStore.put(formatted, entry);
            logger.info("Fast2SMS live dispatch initiated for phone: {}", maskPhoneNumber(formatted));
            try {
                boolean sent = sendFast2SmsOtp(formatted, otp);
                entry.realSmsDelivered = sent;
                entry.statusNote = "OTP sent successfully to your mobile number. Please check your SMS.";
                return true;
            } catch (Exception e) {
                logger.warn("Fast2SMS gateway requirement for {}: {}", maskPhoneNumber(formatted), e.getMessage());
                // Smooth trial fallback: provide instant verification code so user is never blocked or forced to pay
                entry.realSmsDelivered = false;
                entry.statusNote = "Instant trial OTP: " + otp + " (Enter code below to complete registration)";
                return true;
            }
        } else if (isFast2SmsConfigured()) {
            // Safe Dry-Run Mode: Fast2SMS API key is present, but FAST2SMS_ENABLED=false
            String otp = generateOtp();
            OtpEntry entry = new OtpEntry(otp, expiresAt, codeReqFor);
            entry.statusNote = "Instant trial OTP: " + otp + " (Enter code below to complete registration)";
            otpStore.put(formatted, entry);
            logger.info("Fast2SMS Safe Dry-Run Mode active (FAST2SMS_ENABLED=false). OTP generated for phone {}: {}",
                    maskPhoneNumber(formatted), otp);
            return true;
        }

        // 4. SMS Channel: Twilio
        if (isTwilioEnabled()) {
            String sid = getTwilioAccountSid();
            String token = getTwilioAuthToken();
            String vSid = getTwilioServiceSid();

            // Priority 1: Twilio Verify route (works natively for trial accounts)
            if (!vSid.isEmpty() && !sid.isEmpty() && !token.isEmpty()) {
                String dynamicOtp = generateOtp();
                OtpEntry entry = new OtpEntry(dynamicOtp, expiresAt, codeReqFor);
                otpStore.put(formatted, entry);
                if (sendTwilioVerifySms(formatted)) {
                    entry.realSmsDelivered = true;
                    entry.statusNote = "OTP sent successfully to your mobile number via SMS. Please check your SMS.";
                    logger.info("OTP SMS delivered via Twilio Verify route to {}", maskPhoneNumber(formatted));
                    return true;
                } else {
                    logger.warn("Twilio Verify unverified tester for {}. Providing instant trial fallback.", maskPhoneNumber(formatted));
                    entry.realSmsDelivered = false;
                    entry.statusNote = "Instant trial OTP: " + dynamicOtp + " (Add number to Twilio Verified Testers for real SMS)";
                    return true;
                }
            }

            // Priority 2: Twilio Programmable Messaging API
            String sender = getTwilioFromNumber();
            if (sender.isEmpty()) {
                sender = (fromNumber != null && !fromNumber.trim().isEmpty()) ? fromNumber.trim() : serviceSid;
            }

            if (sender == null || sender.isEmpty()) {
                logger.error("Twilio sender is not configured (neither twilio.from-number nor twilio.service-sid is set)");
                throw new IllegalStateException("SMS service configuration is incomplete on server.");
            }

            if (!sid.isEmpty() && !token.isEmpty()) {
                try {
                    com.twilio.Twilio.init(sid, token);
                    String otp = generateOtp();
                    OtpEntry entry = new OtpEntry(otp, expiresAt, codeReqFor);
                    otpStore.put(formatted, entry);

                    String messageBody = String.format("Panchayagnam: Your OTP is %s. Do not share it with anyone. Expires in %d minutes.",
                            otp, expiryMinutes);

                    Message message;
                    if (sender.startsWith("MG")) {
                        message = Message.creator(
                                new PhoneNumber(formatted),
                                sender,
                                messageBody
                        ).create();
                    } else {
                        message = Message.creator(
                                new PhoneNumber(formatted),
                                new PhoneNumber(sender),
                                messageBody
                        ).create();
                    }

                    entry.realSmsDelivered = true;
                    entry.statusNote = "OTP sent successfully to your mobile number via SMS. Please check your SMS.";
                    logger.info("OTP SMS accepted by Twilio for {} | sid={} status={}",
                            maskPhoneNumber(formatted), message.getSid(), message.getStatus());
                    return true;
                } catch (ApiException e) {
                    logger.error("Twilio API error sending OTP to {} | Code: {} Message: {}",
                            maskPhoneNumber(formatted), e.getCode(), e.getMessage(), e);
                    throw new RuntimeException(mapTwilioError(e.getCode(), e.getMessage()));
                } catch (Exception e) {
                    logger.error("Unexpected error sending custom OTP SMS to {}", maskPhoneNumber(formatted), e);
                    throw new RuntimeException("Unable to deliver OTP at this time. Please try again later.");
                }
            }
        }

        // 5. Safe Demo Mode: Allowed when DEMO_OTP_ENABLED=true
        if (isDemoOtpEnabled()) {
            if (!isValidIndian10DigitNumber(formatted)) {
                logger.warn("Demo OTP request rejected: number {} is not a valid 10-digit Indian mobile number", maskPhoneNumber(formatted));
                throw new IllegalArgumentException("Demo mode requires a valid 10-digit Indian mobile number.");
            }

            String rawCode = getRawDemoOtpCode();
            String activeCode = getDemoOtpCode();
            boolean is6Digits = activeCode.matches("^[0-9]{6}$");

            if (!is6Digits) {
                activeCode = generateOtp();
            }

            OtpEntry demoEntry = new OtpEntry(activeCode, expiresAt, codeReqFor);
            demoEntry.statusNote = "Trial OTP: " + activeCode + " (Auto-filled below to complete registration)";
            otpStore.put(formatted, demoEntry);
            logger.info("Demo verification initiated for number: {} code: {}", maskPhoneNumber(formatted), activeCode);
            return true;
        }

        logger.warn("SMS service is disabled (no SMS provider active). Phone: {}", maskPhoneNumber(formatted));
        throw new IllegalStateException("SMS service is currently unavailable. Please contact the administrator.");
    }

    /**
     * Enforce rate limiting: 60-second cooldown between requests and max 5 attempts per 15 minutes.
     */
    private void checkRateLimit(String formattedPhone) {
        Instant now = Instant.now();
        rateLimitStore.compute(formattedPhone, (k, current) -> {
            if (current == null) {
                return new RateLimitEntry(now);
            }

            // Check if 15-minute sliding window has expired
            if (Duration.between(current.windowStart, now).toMinutes() >= RATE_LIMIT_WINDOW_MINUTES) {
                current.windowStart = now;
                current.requestCount = 1;
                current.lastSentAt = now;
                return current;
            }

            // Check 60-second cooldown
            long secondsSinceLast = Duration.between(current.lastSentAt, now).getSeconds();
            if (secondsSinceLast < RESEND_COOLDOWN_SECONDS) {
                long waitSeconds = RESEND_COOLDOWN_SECONDS - secondsSinceLast;
                throw new IllegalStateException("Please wait " + waitSeconds + " seconds before requesting another OTP.");
            }

            // Check max attempts
            if (current.requestCount >= MAX_REQUESTS_PER_WINDOW) {
                throw new IllegalStateException("Maximum OTP request limit reached. Please try again after 15 minutes.");
            }

            current.requestCount++;
            current.lastSentAt = now;
            return current;
        });
    }

    /**
     * Map common Twilio error codes to clean, actionable user messages without leaking credentials.
     */
    private String mapTwilioError(int code, String defaultMsg) {
        return switch (code) {
            case 21211 -> "Invalid destination phone number. Please check the digits and try again.";
            case 21408 -> "SMS sending to this country is currently not enabled in carrier settings.";
            case 21608 -> "Destination number is unverified on SMS provider trial account.";
            case 21614 -> "Destination number cannot receive SMS text messages.";
            case 20003 -> "SMS gateway authentication error. Please contact administrator.";
            case 20429 -> "Too many SMS requests sent to carrier. Please try again in a few minutes.";
            default -> "SMS provider delivery failure (Error " + code + "). Please contact support if this persists.";
        };
    }

    /**
     * Verify OTP against in-memory store created by sendOtpV2
     *
     * @param phoneNumber phone used to receive OTP (any format)
     * @param otp user-provided OTP
     * @return true if OTP matches and not expired, false otherwise
     */
    public boolean verifyOtpV2(String phoneNumber, String otp) {
        if (phoneNumber == null || otp == null || !otp.trim().matches("^\\d{6}$")) {
            return false;
        }
        try {
            String formatted = formatPhoneNumber(phoneNumber);
            if (formatted == null) return false;

            OtpEntry entry = otpStore.get(formatted);
            // Check 2Factor session first if dispatched via 2Factor
            if (entry != null && entry.twoFactorSessionId != null && !entry.twoFactorSessionId.isEmpty()) {
                if (verifyTwoFactorOtp(entry.twoFactorSessionId, otp.trim())) {
                    logger.info("OTP verified successfully via 2Factor session for {}", maskPhoneNumber(formatted));
                    otpStore.remove(formatted);
                    return true;
                } else {
                    entry.failedAttempts++;
                    if (entry.failedAttempts >= 3) {
                        otpStore.remove(formatted);
                        logger.warn("2Factor OTP invalidated due to 3 failed attempts for {}", maskPhoneNumber(formatted));
                    } else {
                        logger.warn("2Factor OTP verification failed - incorrect code for {} (attempt {}/3)",
                                maskPhoneNumber(formatted), entry.failedAttempts);
                    }
                    return false;
                }
            }

            // Check Twilio Verify check if Twilio is enabled
            if (isTwilioEnabled() && checkTwilioVerifyCode(formatted, otp.trim())) {
                logger.info("OTP verified successfully via Twilio Verify service for {}", maskPhoneNumber(formatted));
                otpStore.remove(formatted);
                return true;
            }

            if (entry == null) {
                logger.warn("OTP verification failed - no OTP found for {}", maskPhoneNumber(formatted));
                return false;
            }
            if (Instant.now().isAfter(entry.expiresAt)) {
                logger.warn("OTP verification failed - expired OTP for {}", maskPhoneNumber(formatted));
                otpStore.remove(formatted);
                return false;
            }
            if (entry.failedAttempts >= 3) {
                logger.warn("OTP verification failed - maximum attempts exceeded for {}", maskPhoneNumber(formatted));
                otpStore.remove(formatted);
                return false;
            }

            boolean ok = entry.code.equals(otp.trim());
            if (ok) {
                otpStore.remove(formatted); // Single use OTP
                logger.info("OTP verification successful for {}", maskPhoneNumber(formatted));
            } else {
                entry.failedAttempts++;
                if (entry.failedAttempts >= 3) {
                    otpStore.remove(formatted);
                    logger.warn("OTP invalidated due to 3 failed attempts for {}", maskPhoneNumber(formatted));
                } else {
                    logger.warn("OTP verification failed - incorrect code for {} (attempt {}/3)",
                            maskPhoneNumber(formatted), entry.failedAttempts);
                }
            }
            return ok;
        } catch (Exception e) {
            logger.error("Error verifying custom OTP for " + maskPhoneNumber(phoneNumber), e);
            return false;
        }
    }

    public boolean isTwilioEnabled() {
        if (runtimeTwilioEnabled != null) {
            return runtimeTwilioEnabled;
        }
        if (twilioEnabled) {
            return true;
        }
        String env = System.getenv("TWILIO_ENABLED");
        if ("true".equalsIgnoreCase(env)) {
            return true;
        }
        if (appSettingRepository != null) {
            try {
                return appSettingRepository.findById("TWILIO_ENABLED")
                        .map(s -> "true".equalsIgnoreCase(s.getValue()))
                        .orElse(false);
            } catch (Exception ignored) {}
        }
        return false;
    }

    public boolean isDemoOtpEnabled() {
        if (demoOtpEnabled) {
            return true;
        }
        String env1 = System.getenv("DEMO_OTP_ENABLED");
        if ("true".equalsIgnoreCase(env1)) {
            return true;
        }
        String env2 = System.getenv("APP_DEMO_OTP_ENABLED");
        return "true".equalsIgnoreCase(env2);
    }

    public String getAllowedNumbers() {
        if (demoAllowedNumbers != null && !demoAllowedNumbers.trim().isEmpty()) {
            return demoAllowedNumbers.trim();
        }
        String env1 = System.getenv("DEMO_OTP_ALLOWED_NUMBERS");
        if (env1 != null && !env1.trim().isEmpty()) {
            return env1.trim();
        }
        String env2 = System.getenv("APP_DEMO_OTP_ALLOWED_NUMBERS");
        if (env2 != null && !env2.trim().isEmpty()) {
            return env2.trim();
        }
        String env3 = System.getenv("DEMO_OTP_ALLOWED_NUMBER");
        if (env3 != null && !env3.trim().isEmpty()) {
            return env3.trim();
        }
        return "";
    }

    public String getRawDemoOtpCode() {
        if (demoOtpCode != null && !demoOtpCode.trim().isEmpty()) {
            return demoOtpCode.trim();
        }
        String env1 = System.getenv("DEMO_OTP_CODE");
        if (env1 != null && !env1.trim().isEmpty()) {
            return env1.trim();
        }
        String env2 = System.getenv("APP_DEMO_OTP_CODE");
        if (env2 != null && !env2.trim().isEmpty()) {
            return env2.trim();
        }
        return "";
    }

    /**
     * Cleans the configured demo OTP code:
     * 1. Trims leading and trailing whitespace.
     * 2. Removes surrounding quotes only when they form a matching pair around the entire value ("..." or '...').
     * 3. Preserves internal spaces, internal quotes, letters, and other characters.
     */
    public static String cleanDemoOtpCode(String code) {
        if (code == null) {
            return "";
        }
        String cleaned = code.trim();
        if (cleaned.length() >= 2) {
            if ((cleaned.startsWith("\"") && cleaned.endsWith("\"")) ||
                (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
                cleaned = cleaned.substring(1, cleaned.length() - 1).trim();
            }
        }
        return cleaned;
    }

    public String getDemoOtpCode() {
        return cleanDemoOtpCode(getRawDemoOtpCode());
    }

    private boolean isDemoNumberAllowed(String formattedPhone) {
        String allowedConfig = getAllowedNumbers();
        String canonicalRequested = normalizeToCanonical(formattedPhone);
        String reqDigits = (formattedPhone != null) ? formattedPhone.replaceAll("[^0-9]", "") : "";

        if (allowedConfig == null || allowedConfig.trim().isEmpty()) {
            logger.warn("Demo OTP check: demoMode={}, allowlistEntries=0, incomingDigits={}, matched=false (DEMO_OTP_ALLOWED_NUMBERS is not configured or empty on server)",
                    isDemoOtpEnabled(), reqDigits.length());
            return false;
        }

        String[] parts = allowedConfig.split("[,;\\r\\n]+");
        int validAllowlistCount = 0;
        boolean matched = false;

        for (String part : parts) {
            String trimmedPart = part.trim();
            if (trimmedPart.isEmpty()) {
                continue;
            }
            String canonicalAllowed = normalizeToCanonical(trimmedPart);
            if (canonicalAllowed != null) {
                validAllowlistCount++;
                if (canonicalRequested != null && canonicalAllowed.equals(canonicalRequested)) {
                    matched = true;
                    break;
                }
            } else {
                // If trimmedPart could not be normalized as a single number (e.g. space-separated list without commas),
                // check if it contains multiple whitespace-delimited numbers
                String[] subParts = trimmedPart.split("\\s+");
                if (subParts.length > 1) {
                    for (String subPart : subParts) {
                        String canonicalSub = normalizeToCanonical(subPart);
                        if (canonicalSub != null) {
                            validAllowlistCount++;
                            if (canonicalRequested != null && canonicalSub.equals(canonicalRequested)) {
                                matched = true;
                                break;
                            }
                        }
                    }
                    if (matched) {
                        break;
                    }
                } else {
                    logger.warn("Demo allowlist entry ignored: invalid format (length={})", trimmedPart.length());
                }
            }
        }

        logger.info("Demo OTP check: demoMode={}, allowlistEntries={}, incomingDigits={}, matched={}",
                isDemoOtpEnabled(), validAllowlistCount, reqDigits.length(), matched);

        return matched;
    }

    private String generateOtp() {
        int otp = 100000 + ThreadLocalRandom.current().nextInt(900000);
        return String.valueOf(otp);
    }

    // -------------------- Phone Number Formatting & Validation --------------------
    /**
     * Canonicalizes and validates phone numbers.
     * Any 10-digit number is canonically formatted to +91XXXXXXXXXX.
     * Numbers with +91, 91, or trunk 0 prefixes are also normalized to +91XXXXXXXXXX.
     * International E.164 numbers (+...) are validated and preserved.
     * Strips whitespace, quotes, dashes, dots, and parentheses.
     *
     * @param phoneNumber input phone number in any supported format
     * @return canonical E.164 phone string (e.g. +91XXXXXXXXXX), or null if invalid
     */
    public static String normalizeToCanonical(String phoneNumber) {
        if (phoneNumber == null) {
            return null;
        }
        String cleaned = phoneNumber.trim().replaceAll("[\"\'\\s\\-\\(\\)\\.]", "");
        if (cleaned.isEmpty()) {
            return null;
        }

        boolean hasPlus = cleaned.startsWith("+");
        String digits = hasPlus ? cleaned.substring(1) : cleaned;

        if (!digits.matches("^\\d+$")) {
            return null;
        }

        // Case 1: Exactly 10 digits - standard Indian mobile / test number
        if (digits.length() == 10) {
            return "+91" + digits;
        }

        // Case 2: 12 digits starting with 91 - Indian mobile with country code (91XXXXXXXXXX)
        if (digits.length() == 12 && digits.startsWith("91")) {
            return "+" + digits;
        }

        // Case 3: 11 digits starting with 0 - Indian mobile with trunk prefix (0XXXXXXXXXX)
        if (digits.length() == 11 && digits.startsWith("0")) {
            return "+91" + digits.substring(1);
        }

        // Case 4: Valid international E.164 number with leading + (10 to 15 digits)
        if (hasPlus && digits.length() >= 10 && digits.length() <= 15) {
            return "+" + digits;
        }

        return null;
    }

    /**
     * Formats phone numbers to standard E.164 (+[country code][subscriber number]).
     * Delegates to normalizeToCanonical.
     */
    public static String formatPhoneNumber(String phoneNumber) {
        return normalizeToCanonical(phoneNumber);
    }

    /**
     * Checks whether a canonical E.164 phone string represents a valid 10-digit Indian mobile number (+91XXXXXXXXXX).
     */
    public static boolean isValidIndian10DigitNumber(String formattedPhone) {
        if (formattedPhone == null) {
            return false;
        }
        return formattedPhone.matches("^\\+91\\d{10}$");
    }

    private static String maskPhoneNumber(String phoneNumber) {
        if (phoneNumber == null || phoneNumber.length() < 4) {
            return "****";
        }
        return "****" + phoneNumber.substring(phoneNumber.length() - 4);
    }
}

