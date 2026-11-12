package com.py.common.util;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

class TwilioOtpServiceTest {

    @Test
    @DisplayName("Format 10-digit Indian mobile number with +91 prefix")
    void testFormatPhoneNumber_10Digits() {
        String result = TwilioOtpService.formatPhoneNumber("9876543210");
        assertEquals("+919876543210", result);
    }

    @Test
    @DisplayName("Format 12-digit Indian mobile number starting with 91")
    void testFormatPhoneNumber_12DigitsWith91() {
        String result = TwilioOtpService.formatPhoneNumber("919876543210");
        assertEquals("+919876543210", result);
    }

    @Test
    @DisplayName("Format phone number already in E.164 format")
    void testFormatPhoneNumber_AlreadyE164() {
        String result = TwilioOtpService.formatPhoneNumber("+919876543210");
        assertEquals("+919876543210", result);
    }

    @Test
    @DisplayName("Format US phone number with country code +1")
    void testFormatPhoneNumber_USNumber() {
        String result = TwilioOtpService.formatPhoneNumber("+12025550199");
        assertEquals("+12025550199", result);
    }

    @Test
    @DisplayName("Clean spaces, hyphens, and brackets from phone number")
    void testFormatPhoneNumber_WithSpecialCharacters() {
        String result = TwilioOtpService.formatPhoneNumber("(987) 654-3210");
        assertEquals("+919876543210", result);
    }

    @Test
    @DisplayName("Return null for invalid phone numbers (null, empty, too short)")
    void testFormatPhoneNumber_InvalidNumbers() {
        assertNull(TwilioOtpService.formatPhoneNumber(null));
        assertNull(TwilioOtpService.formatPhoneNumber(""));
        assertNull(TwilioOtpService.formatPhoneNumber("12345"));
    }

    @Test
    @DisplayName("Throw IllegalStateException when Twilio service is disabled")
    void testSendOtp_ServiceDisabled() {
        TwilioOtpService service = new TwilioOtpService();
        ReflectionTestUtils.setField(service, "twilioEnabled", false);
        ReflectionTestUtils.setField(service, "twoFactorEnabledConfig", false);
        ReflectionTestUtils.setField(service, "runtimeTwoFactorEnabled", false);
        ReflectionTestUtils.setField(service, "fast2SmsEnabled", false);
        ReflectionTestUtils.setField(service, "runtimeFast2SmsEnabled", false);
        ReflectionTestUtils.setField(service, "runtimeFast2SmsApiKey", "");
        ReflectionTestUtils.setField(service, "runtimeTwoFactorApiKey", "");
        ReflectionTestUtils.setField(service, "fromNumber", "+1234567890");

        IllegalStateException ex = assertThrows(IllegalStateException.class, () -> {
            service.sendOtpV2("9876543210", "Registration");
        });

        assertTrue(ex.getMessage().contains("SMS service is currently unavailable"));
    }

    @Test
    @DisplayName("Throw IllegalArgumentException for invalid phone number format")
    void testSendOtp_InvalidPhoneNumber() {
        TwilioOtpService service = new TwilioOtpService();
        ReflectionTestUtils.setField(service, "twilioEnabled", true);
        ReflectionTestUtils.setField(service, "twoFactorEnabledConfig", false);
        ReflectionTestUtils.setField(service, "fast2SmsEnabled", false);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () -> {
            service.sendOtpV2("123", "Registration");
        });

        assertTrue(ex.getMessage().contains("Invalid phone number format"));
    }

    @Test
    @DisplayName("Throw IllegalStateException when sender fromNumber is not configured")
    void testSendOtp_SenderNotConfigured() {
        TwilioOtpService service = new TwilioOtpService();
        ReflectionTestUtils.setField(service, "twilioEnabled", true);
        ReflectionTestUtils.setField(service, "twoFactorEnabledConfig", false);
        ReflectionTestUtils.setField(service, "runtimeTwoFactorEnabled", false);
        ReflectionTestUtils.setField(service, "fast2SmsEnabled", false);
        ReflectionTestUtils.setField(service, "runtimeFast2SmsEnabled", false);
        ReflectionTestUtils.setField(service, "runtimeFast2SmsApiKey", "");
        ReflectionTestUtils.setField(service, "runtimeTwoFactorApiKey", "");
        ReflectionTestUtils.setField(service, "fromNumber", "");
        ReflectionTestUtils.setField(service, "serviceSid", "");

        IllegalStateException ex = assertThrows(IllegalStateException.class, () -> {
            service.sendOtpV2("9876543210", "Registration");
        });

        assertTrue(ex.getMessage().contains("SMS service configuration is incomplete"));
    }

    @Test
    @DisplayName("Verify OTP returns false for non-existent or blank OTP")
    void testVerifyOtp_NonExistentOrBlank() {
        TwilioOtpService service = new TwilioOtpService();
        assertFalse(service.verifyOtpV2("9876543210", ""));
        assertFalse(service.verifyOtpV2("9876543210", null));
        assertFalse(service.verifyOtpV2(null, "123456"));
        assertFalse(service.verifyOtpV2("9876543210", "999999"));
    }

    @Test
    @DisplayName("Do not swallow Fast2SMS failures into Demo Trial OTP when 2Factor key is unconfigured")
    void testSendOtp_Fast2SmsFailureDoesNotFallbackToDemoWhenTwoFactorUnconfigured() {
        TwilioOtpService service = new TwilioOtpService();
        ReflectionTestUtils.setField(service, "fast2SmsEnabled", true);
        ReflectionTestUtils.setField(service, "runtimeFast2SmsEnabled", true);
        ReflectionTestUtils.setField(service, "runtimeFast2SmsApiKey", "\"test-fast2sms-key\"");
        ReflectionTestUtils.setField(service, "fast2SmsUrl", "http://127.0.0.1:1/fast2sms-unreachable");
        ReflectionTestUtils.setField(service, "twoFactorEnabledConfig", true);
        ReflectionTestUtils.setField(service, "runtimeTwoFactorEnabled", true);
        ReflectionTestUtils.setField(service, "runtimeTwoFactorApiKey", "");
        ReflectionTestUtils.setField(service, "twilioEnabled", false);
        ReflectionTestUtils.setField(service, "demoOtpEnabled", true);
        ReflectionTestUtils.setField(service, "demoOtpCode", "955338");

        assertEquals("test-fast2sms-key", service.getFast2SmsApiKey());
        assertEquals("FAST2SMS", service.getActiveProviderLabel());

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                service.sendOtpV2("9876543210", "Registration"));
        assertTrue(ex.getMessage().contains("Fast2SMS"));
    }
}
