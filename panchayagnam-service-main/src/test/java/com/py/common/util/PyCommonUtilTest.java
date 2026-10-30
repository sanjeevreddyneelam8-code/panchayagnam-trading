package com.py.common.util;

import com.py.common.dto.ApiResponse;
import com.py.common.enums.BrokerType;
import com.py.demataccount.dto.DematAccountAddRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class PyCommonUtilTest {

    private PyCommonUtil pyCommonUtil;

    @BeforeEach
    void setUp() {
        pyCommonUtil = new PyCommonUtil();
    }

    @Test
    @DisplayName("Dhan validation succeeds without apiKey when clientId, mpin, totp, ip and pyUserId are provided")
    void testDhanValidationSuccessWithoutApiKey() {
        DematAccountAddRequest request = new DematAccountAddRequest();
        request.setBrokerType(BrokerType.DHAN);
        request.setClientId("1100345678");
        request.setMpin("123456");
        request.setTotpReferenceKey("JBSWY3DPEHPK3PXP");
        request.setIp("192.168.1.100");
        request.setPyUserId(101L);
        request.setApiKey(""); // Dhan does not require an API key in UI

        ApiResponse<?> response = pyCommonUtil.validateAccountRequest(request);

        assertNotNull(response);
        assertEquals("SUCCESS", response.getStatus());
        assertEquals("Validation passed", response.getMessage());
    }

    @Test
    @DisplayName("Dhan validation fails if PIN / MPIN is missing")
    void testDhanValidationFailsWithoutMpin() {
        DematAccountAddRequest request = new DematAccountAddRequest();
        request.setBrokerType(BrokerType.DHAN);
        request.setClientId("1100345678");
        request.setMpin("");
        request.setTotpReferenceKey("JBSWY3DPEHPK3PXP");
        request.setIp("192.168.1.100");
        request.setPyUserId(101L);

        ApiResponse<?> response = pyCommonUtil.validateAccountRequest(request);

        assertNotNull(response);
        assertEquals("ERROR", response.getStatus());
        assertTrue(response.getMessage().contains("PIN / MPIN is required"));
    }

    @Test
    @DisplayName("Dhan validation fails if TOTP Key is missing")
    void testDhanValidationFailsWithoutTotpKey() {
        DematAccountAddRequest request = new DematAccountAddRequest();
        request.setBrokerType(BrokerType.DHAN);
        request.setClientId("1100345678");
        request.setMpin("123456");
        request.setTotpReferenceKey("");
        request.setIp("192.168.1.100");
        request.setPyUserId(101L);

        ApiResponse<?> response = pyCommonUtil.validateAccountRequest(request);

        assertNotNull(response);
        assertEquals("ERROR", response.getStatus());
        assertTrue(response.getMessage().contains("TOTP Key is required"));
    }

    @Test
    @DisplayName("Angel One validation still strictly requires apiKey")
    void testAngelOneRequiresApiKey() {
        DematAccountAddRequest request = new DematAccountAddRequest();
        request.setBrokerType(BrokerType.ANGELONE);
        request.setClientId("A12345");
        request.setMpin("1234");
        request.setTotpReferenceKey("JBSWY3DPEHPK3PXP");
        request.setIp("192.168.1.100");
        request.setPyUserId(101L);
        request.setApiKey("");

        ApiResponse<?> response = pyCommonUtil.validateAccountRequest(request);

        assertNotNull(response);
        assertEquals("ERROR", response.getStatus());
        assertTrue(response.getMessage().contains("API Key is required for ANGELONE"));
    }

    @Test
    @DisplayName("Motilal validation still strictly requires apiKey")
    void testMotilalRequiresApiKey() {
        DematAccountAddRequest request = new DematAccountAddRequest();
        request.setBrokerType(BrokerType.MOTILAL);
        request.setClientId("M12345");
        request.setMpin("password123");
        request.setTotpReferenceKey("JBSWY3DPEHPK3PXP");
        request.setIp("192.168.1.100");
        request.setPyUserId(101L);
        request.setApiKey("");

        ApiResponse<?> response = pyCommonUtil.validateAccountRequest(request);

        assertNotNull(response);
        assertEquals("ERROR", response.getStatus());
        assertTrue(response.getMessage().contains("API Key is required for MOTILAL"));
    }
}
