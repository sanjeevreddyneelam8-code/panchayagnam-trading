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

    // In-memory OTP store: phone -> (code, expiry, reqFor)
    private static final class OtpEntry {
        final String code;
        final Instant expiresAt;
        final String codeReqFor;
        int failedAttempts = 0;
        OtpEntry(String code, Instant expiresAt, String codeReqFor) {
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

        try {
            org.json.JSONObject payload = new org.json.JSONObject();
            payload.put("route", "otp");
            payload.put("variables_values", otp);
            payload.put("numbers", phone10);

            java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();

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

            logger.info("Fast2SMS response status: {} for phone: {}", statusCode, maskPhoneNumber(phone10));

            if (statusCode == 200) {
                org.json.JSONObject resJson = new org.json.JSONObject(responseBody);
                boolean isSuccess = resJson.optBoolean("return", false);
                if (isSuccess) {
                    logger.info("Fast2SMS OTP successfully dispatched to {}", maskPhoneNumber(phone10));
                    return true;
                } else {
                    String msg = resJson.optString("message", "Fast2SMS gateway rejected the dispatch request");
                    logger.error("Fast2SMS delivery failure for {}: {}", maskPhoneNumber(phone10), msg);
                    throw new RuntimeException("SMS gateway delivery failure: " + msg);
                }
            } else if (statusCode == 401 || statusCode == 412) {
                logger.error("Fast2SMS authorization failed (HTTP {}). Please verify FAST2SMS_API_KEY environment variable.", statusCode);
                throw new IllegalStateException("Fast2SMS authorization failed. Please check server FAST2SMS_API_KEY.");
            } else {
                logger.error("Fast2SMS returned HTTP {}: {}", statusCode, responseBody);
                throw new RuntimeException("SMS gateway temporarily unavailable (HTTP " + statusCode + "). Please try again later.");
            }
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

        // 3. Primary SMS Channel: Fast2SMS
        if (isFast2SmsEnabled()) {
            // Live SMS via Fast2SMS
            String otp = generateOtp();
            otpStore.put(formatted, new OtpEntry(otp, expiresAt, codeReqFor));
            logger.info("Fast2SMS live dispatch initiated for phone: {}", maskPhoneNumber(formatted));
            return sendFast2SmsOtp(formatted, otp);
        } else if (isFast2SmsConfigured()) {
            // Safe Dry-Run Mode: Fast2SMS API key is present, but FAST2SMS_ENABLED=false
            // Generates OTP, stores in memory for verification, logs zero-cost confirmation (Requirement 8)
            String otp = generateOtp();
            otpStore.put(formatted, new OtpEntry(otp, expiresAt, codeReqFor));
            logger.info("Fast2SMS Safe Dry-Run Mode active (FAST2SMS_ENABLED=false). No money or credits spent. OTP generated for phone {}: {}",
                    maskPhoneNumber(formatted), otp);
            return true;
        }

        // 4. Secondary SMS Channel: Twilio
        if (twilioEnabled) {
            String sender = (fromNumber != null && !fromNumber.trim().isEmpty()) ? fromNumber.trim() : serviceSid;
            if (sender == null || sender.isEmpty()) {
                logger.error("Twilio sender is not configured (neither twilio.from-number nor twilio.service-sid is set)");
                throw new IllegalStateException("SMS service configuration is incomplete on server.");
            }

            try {
                String otp = generateOtp();
                otpStore.put(formatted, new OtpEntry(otp, expiresAt, codeReqFor));

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
                logger.error("Demo OTP configuration rejected: DEMO_OTP_CODE must be exactly 6 numeric digits.");
                throw new IllegalStateException("Demo service configuration error: DEMO_OTP_CODE must be exactly 6 numeric digits.");
            }

            otpStore.put(formatted, new OtpEntry(activeCode, expiresAt, codeReqFor));
            logger.info("Demo verification initiated for number: {}", maskPhoneNumber(formatted));
            return true;
        }

        // 6. Safe Default Fallback: Generate real OTP stored in memory (zero external cost)
        String otp = generateOtp();
        otpStore.put(formatted, new OtpEntry(otp, expiresAt, codeReqFor));
        logger.info("Safe fallback OTP generated for number: {}", maskPhoneNumber(formatted));
        return true;
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
        return twilioEnabled;
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

