package com.py.demataccount.service;

import com.py.brokers.angel.dto.CancelOrderRequest;
import com.py.brokers.angel.dto.ModifyOrderRequest;
import com.py.brokers.angel.dto.Order;
import com.py.common.enums.BrokerType;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.entity.PyBrokerSecret;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.demataccount.service.impl.PyBrokerAccountServiceImpl;
import com.py.dto.ConvertPositionRequest;
import com.py.easytrade.entity.IndividualOrderAuditEntity;
import com.py.easytrade.repository.IndividualOrderAuditRepository;
import com.py.tokensValidation.PyTokenValidationService;
import com.py.trading.entity.PaperPositionEntity;
import com.py.trading.service.PaperTradingEngine;
import com.py.trading.service.PaperTradingService;
import com.py.utils.AngelOneMicroserviceClient;
import com.py.utils.DhanMicroserviceClient;
import com.py.utils.MotilalMicroserviceClient;
import com.py.utils.ProfitmartMicroserviceClient;
import org.json.JSONObject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Collections;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class PyBrokerAccountModifyCancelSafetyTest {

    @Mock
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @Mock
    private IndividualOrderAuditRepository individualOrderAuditRepository;

    @Mock
    private PaperTradingService paperTradingService;

    @Mock
    private PaperTradingEngine paperTradingEngine;

    @Mock
    private PyTokenValidationService pyTokenValidationService;

    @Mock
    private AngelOneMicroserviceClient angelOneClient;

    @Mock
    private MotilalMicroserviceClient motilalClient;

    @Mock
    private DhanMicroserviceClient dhanClient;

    @Mock
    private ProfitmartMicroserviceClient profitmartClient;

    @InjectMocks
    private PyBrokerAccountServiceImpl service;

    private PyBrokerAccountEntity account;
    private PyBrokerSecret secret;

    @BeforeEach
    void setUp() {
        account = new PyBrokerAccountEntity();
        account.setId(501L);
        account.setClientId("ANGEL_501");
        account.setUserName("TestUser");
        account.setBrokerType(BrokerType.ANGELONE);

        secret = new PyBrokerSecret();
        secret.setApiKey("test-api-key");
        account.setSecret(secret);

        lenient().when(pyBrokerAccountRepository.findById(501L)).thenReturn(Optional.of(account));
    }

    @Test
    @DisplayName("Modify: Filled simulated order cannot be modified")
    void testModifySimulatedFilledOrderThrows() {
        when(paperTradingService.isPaperTradingEnabled()).thenReturn(true);

        IndividualOrderAuditEntity audit = new IndividualOrderAuditEntity();
        audit.setOrderId("PAPER-SIM-001");
        audit.setDematAccountId(501L);
        audit.setStatus("SUCCESS");
        when(individualOrderAuditRepository.findFirstByOrderIdOrderByExecutedAtDesc("PAPER-SIM-001"))
                .thenReturn(Optional.of(audit));

        ModifyOrderRequest req = new ModifyOrderRequest();
        req.setAccId(501L);
        req.setOrderId("PAPER-SIM-001");
        req.setPrice(100.0);
        req.setQuantity(5);

        IllegalStateException ex = assertThrows(IllegalStateException.class, () -> service.modifyIndividualOrder(req));
        assertTrue(ex.getMessage().contains("already executed / filled"));
        verifyNoInteractions(angelOneClient);
    }

    @Test
    @DisplayName("Cancel: Filled simulated order cannot be cancelled")
    void testCancelSimulatedFilledOrderThrows() {
        when(paperTradingService.isPaperTradingEnabled()).thenReturn(true);

        IndividualOrderAuditEntity audit = new IndividualOrderAuditEntity();
        audit.setOrderId("PAPER-SIM-002");
        audit.setDematAccountId(501L);
        audit.setStatus("SUCCESS");
        when(individualOrderAuditRepository.findFirstByOrderIdOrderByExecutedAtDesc("PAPER-SIM-002"))
                .thenReturn(Optional.of(audit));

        CancelOrderRequest req = new CancelOrderRequest();
        req.setAccId(501L);
        req.setOrderId("PAPER-SIM-002");

        IllegalStateException ex = assertThrows(IllegalStateException.class, () -> service.cancelIndividualOrder(req));
        assertTrue(ex.getMessage().contains("already executed / filled"));
        verifyNoInteractions(angelOneClient);
    }

    @Test
    @DisplayName("Cancel: Cancelled simulated order cannot be cancelled again")
    void testCancelSimulatedAlreadyCancelledOrderThrows() {
        when(paperTradingService.isPaperTradingEnabled()).thenReturn(true);

        IndividualOrderAuditEntity audit = new IndividualOrderAuditEntity();
        audit.setOrderId("PAPER-SIM-003");
        audit.setDematAccountId(501L);
        audit.setStatus("CANCELLED");
        when(individualOrderAuditRepository.findFirstByOrderIdOrderByExecutedAtDesc("PAPER-SIM-003"))
                .thenReturn(Optional.of(audit));

        CancelOrderRequest req = new CancelOrderRequest();
        req.setAccId(501L);
        req.setOrderId("PAPER-SIM-003");

        IllegalStateException ex = assertThrows(IllegalStateException.class, () -> service.cancelIndividualOrder(req));
        assertTrue(ex.getMessage().contains("already cancelled"));
        verifyNoInteractions(angelOneClient);
    }

    @Test
    @DisplayName("Modify: OPEN simulated order updates simulated state without calling broker")
    void testModifySimulatedOpenOrderSucceeds() {
        when(paperTradingService.isPaperTradingEnabled()).thenReturn(true);

        IndividualOrderAuditEntity audit = new IndividualOrderAuditEntity();
        audit.setOrderId("PAPER-SIM-OPEN");
        audit.setDematAccountId(501L);
        audit.setStatus("OPEN");
        audit.setPrice(100.0);
        audit.setQuantity(10);
        when(individualOrderAuditRepository.findFirstByOrderIdOrderByExecutedAtDesc("PAPER-SIM-OPEN"))
                .thenReturn(Optional.of(audit));

        ModifyOrderRequest req = new ModifyOrderRequest();
        req.setAccId(501L);
        req.setOrderId("PAPER-SIM-OPEN");
        req.setPrice(105.0);
        req.setQuantity(15);

        Order result = service.modifyIndividualOrder(req);

        assertNotNull(result);
        assertEquals("PAPER-SIM-OPEN", result.orderId);
        assertEquals(105.0, audit.getPrice());
        assertEquals(15, audit.getQuantity());
        verify(individualOrderAuditRepository, atLeastOnce()).save(audit);
        verifyNoInteractions(angelOneClient);
    }

    @Test
    @DisplayName("Cancel: OPEN simulated order transitions to CANCELLED without calling broker")
    void testCancelSimulatedOpenOrderSucceeds() {
        when(paperTradingService.isPaperTradingEnabled()).thenReturn(true);

        IndividualOrderAuditEntity audit = new IndividualOrderAuditEntity();
        audit.setOrderId("PAPER-SIM-OPEN2");
        audit.setDematAccountId(501L);
        audit.setStatus("OPEN");
        when(individualOrderAuditRepository.findFirstByOrderIdOrderByExecutedAtDesc("PAPER-SIM-OPEN2"))
                .thenReturn(Optional.of(audit));

        CancelOrderRequest req = new CancelOrderRequest();
        req.setAccId(501L);
        req.setOrderId("PAPER-SIM-OPEN2");

        Order result = service.cancelIndividualOrder(req);

        assertNotNull(result);
        assertEquals("PAPER-SIM-OPEN2", result.orderId);
        assertEquals("CANCELLED", audit.getStatus());
        verify(individualOrderAuditRepository, atLeastOnce()).save(audit);
        verifyNoInteractions(angelOneClient);
    }

    @Test
    @DisplayName("Modify: Cross-account simulated order access throws SecurityException")
    void testModifyCrossAccountSimulatedOrderThrows() {
        when(paperTradingService.isPaperTradingEnabled()).thenReturn(true);

        IndividualOrderAuditEntity audit = new IndividualOrderAuditEntity();
        audit.setOrderId("PAPER-SIM-OTHER");
        audit.setDematAccountId(999L); // Different account!
        when(individualOrderAuditRepository.findFirstByOrderIdOrderByExecutedAtDesc("PAPER-SIM-OTHER"))
                .thenReturn(Optional.of(audit));

        ModifyOrderRequest req = new ModifyOrderRequest();
        req.setAccId(501L);
        req.setOrderId("PAPER-SIM-OTHER");

        assertThrows(SecurityException.class, () -> service.modifyIndividualOrder(req));
        verifyNoInteractions(angelOneClient);
    }

    @Test
    @DisplayName("Live Safeguard: When paper trading disabled and live trading disabled, modify is blocked")
    void testModifyLiveTradingDisabledBlocksExecution() {
        when(paperTradingService.isPaperTradingEnabled()).thenReturn(false);
        doThrow(new IllegalStateException("Live trading is currently DISABLED"))
                .when(paperTradingService).validateLiveOrderAllowed();

        ModifyOrderRequest req = new ModifyOrderRequest();
        req.setAccId(501L);
        req.setOrderId("LIVE-ORDER-001");

        IllegalStateException ex = assertThrows(IllegalStateException.class, () -> service.modifyIndividualOrder(req));
        assertTrue(ex.getMessage().contains("Live trading is currently DISABLED"));
        verifyNoInteractions(angelOneClient);
        verifyNoInteractions(pyTokenValidationService);
    }

    @Test
    @DisplayName("Live Safeguard: When paper trading disabled and live trading disabled, cancel is blocked")
    void testCancelLiveTradingDisabledBlocksExecution() {
        when(paperTradingService.isPaperTradingEnabled()).thenReturn(false);
        doThrow(new IllegalStateException("Live trading is currently DISABLED"))
                .when(paperTradingService).validateLiveOrderAllowed();

        CancelOrderRequest req = new CancelOrderRequest();
        req.setAccId(501L);
        req.setOrderId("LIVE-ORDER-002");

        IllegalStateException ex = assertThrows(IllegalStateException.class, () -> service.cancelIndividualOrder(req));
        assertTrue(ex.getMessage().contains("Live trading is currently DISABLED"));
        verifyNoInteractions(angelOneClient);
        verifyNoInteractions(pyTokenValidationService);
    }

    @Test
    @DisplayName("Paper Trading: Position conversion is blocked in paper trading mode")
    void testConvertPositionBlockedInPaperMode() {
        when(paperTradingService.isPaperTradingEnabled()).thenReturn(true);

        ConvertPositionRequest req = new ConvertPositionRequest();
        req.setAccId(501L);

        assertThrows(UnsupportedOperationException.class, () -> service.convertPosition(501L, req));
        verifyNoInteractions(angelOneClient);
    }

    @Test
    @DisplayName("Paper Trading: Get positions returns virtual paper positions without touching broker")
    void testGetPositionsReturnsPaperPositions() {
        when(paperTradingService.isPaperTradingEnabled()).thenReturn(true);

        PaperPositionEntity pos = new PaperPositionEntity();
        pos.setTradingSymbol("INFY-EQ");
        pos.setSymbolToken("1594");
        pos.setExchange("NSE");
        pos.setProductType("DELIVERY");
        pos.setQuantity(25);
        pos.setAverageBuyPrice(1500.0);
        pos.setLastSimulatedPrice(1510.0);
        pos.setRealizedPnl(0.0);

        when(paperTradingEngine.getPositions(501L)).thenReturn(Collections.singletonList(pos));

        JSONObject result = service.getPositions(501L);

        assertNotNull(result);
        assertTrue(result.getBoolean("status"));
        assertEquals(1, result.getJSONArray("data").length());
        JSONObject item = result.getJSONArray("data").getJSONObject(0);
        assertEquals("INFY-EQ", item.getString("tradingsymbol"));
        assertEquals(25, item.getInt("netqty"));
        assertEquals(1500.0, item.getDouble("buyavgprice"));
        verifyNoInteractions(angelOneClient);
        verifyNoInteractions(pyTokenValidationService);
    }
}
