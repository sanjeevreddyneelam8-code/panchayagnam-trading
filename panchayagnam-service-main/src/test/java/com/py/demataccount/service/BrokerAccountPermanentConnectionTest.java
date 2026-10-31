package com.py.demataccount.service;

import com.py.common.enums.BrokerType;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.entity.PyBrokerToken;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.tokenrefresh.entity.TokenRefreshProgressEntity;
import com.py.tokenrefresh.repository.TokenRefreshProgressRepository;
import com.py.tokenrefresh.scheduler.TokenRefreshSchedulerService;
import com.py.tokensValidation.PyTokenValidationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class BrokerAccountPermanentConnectionTest {

    @Mock
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @Mock
    private TokenRefreshProgressRepository tokenRefreshProgressRepository;

    @InjectMocks
    private PyTokenValidationService tokenValidationService;

    @InjectMocks
    private TokenRefreshSchedulerService tokenRefreshSchedulerService;

    private PyBrokerAccountEntity demoAccount;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(tokenValidationService, "paperTradingEnabled", true);
        ReflectionTestUtils.setField(tokenRefreshSchedulerService, "paperTradingEnabled", true);

        demoAccount = new PyBrokerAccountEntity();
        demoAccount.setId(101L);
        demoAccount.setClientId("ZR123456");
        demoAccount.setBrokerType(BrokerType.ZERODHA);
        demoAccount.setActive(true);
        demoAccount.setLastLoginStatus("SUCCESS");

        PyBrokerToken token = new PyBrokerToken();
        token.setAccessToken("kite-enctoken-demo-789");
        token.setIsActive(true);
        token.setExpiresAt(LocalDateTime.now().plusYears(10));
        demoAccount.setToken(token);
    }

    @Test
    @DisplayName("PyTokenValidationService: Always validates protected demo account in paper trading mode")
    void testProtectedAccountTokenValidation() {
        when(pyBrokerAccountRepository.findById(101L)).thenReturn(Optional.of(demoAccount));

        String token = tokenValidationService.getValidAccessToken(101L);
        assertNotNull(token);
        assertEquals("kite-enctoken-demo-789", token);
        assertTrue(tokenValidationService.isTokenValid(demoAccount));
    }

    @Test
    @DisplayName("PyTokenValidationService: markAccountInactive suppresses deactivation for protected demo account")
    void testMarkAccountInactiveSuppressed() {
        tokenValidationService.markAccountInactive(demoAccount, "Simulated network timeout");

        // Repository save should NOT be called to deactivate
        verify(pyBrokerAccountRepository, never()).save(any(PyBrokerAccountEntity.class));
        assertTrue(demoAccount.getActive());
        assertEquals("SUCCESS", demoAccount.getLastLoginStatus());
    }

    @Test
    @DisplayName("TokenRefreshSchedulerService: Preserves permanent SUCCESS status on token refresh")
    void testTokenRefreshPreservesPermanentSuccess() {
        when(pyBrokerAccountRepository.findByActiveAndBrokerType(Boolean.TRUE, BrokerType.ANGELONE))
                .thenReturn(Collections.singletonList(demoAccount));
        when(tokenRefreshProgressRepository.save(any(TokenRefreshProgressEntity.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        List<TokenRefreshProgressEntity> results = tokenRefreshSchedulerService.refreshByBrokerType(BrokerType.ANGELONE);

        assertNotNull(results);
        assertEquals(1, results.size());
        assertEquals("SUCCESS", results.get(0).getStatus());

        // Account must remain active and SUCCESS
        assertTrue(demoAccount.getActive());
        assertEquals("SUCCESS", demoAccount.getLastLoginStatus());
        verify(pyBrokerAccountRepository, atLeastOnce()).save(demoAccount);
    }
}
