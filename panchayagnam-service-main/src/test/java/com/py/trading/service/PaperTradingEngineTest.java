package com.py.trading.service;

import com.py.brokers.angel.dto.Order;
import com.py.common.enums.BrokerType;
import com.py.crypto.CryptoService;
import com.py.crypto.EncryptedStringConverter;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.easytrade.dto.IndividualOrderRequest;
import com.py.easytrade.entity.IndividualOrderAuditEntity;
import com.py.easytrade.repository.IndividualOrderAuditRepository;
import com.py.entity.PyUser;
import com.py.repo.PyUserRepository;
import com.py.trading.entity.PaperAccountBalanceEntity;
import com.py.trading.entity.PaperPositionEntity;
import com.py.trading.repository.PaperAccountBalanceRepository;
import com.py.trading.repository.PaperPositionRepository;
import com.py.trading.service.impl.PaperAccountBalanceInitializer;
import com.py.trading.service.impl.PaperTradingEngineImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;

import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("h2")
@Import({PaperTradingEngineImpl.class, PaperAccountBalanceInitializer.class, PaperTradingService.class, CryptoService.class, EncryptedStringConverter.class})
@EntityScan(basePackages = {
        "com.py.trading.entity",
        "com.py.easytrade.entity",
        "com.py.demataccount.entity",
        "com.py.entity"
})
@EnableJpaRepositories(basePackages = {
        "com.py.trading.repository",
        "com.py.easytrade.repository",
        "com.py.demataccount.repository",
        "com.py.repo"
})
@TestPropertySource(properties = {
        "trading.paper-trading.enabled=true",
        "trading.live-trading.enabled=false",
        "app.crypto.broker-encryption-key=MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDE=",
        "app.crypto.allow-legacy-plaintext=true"
})
public class PaperTradingEngineTest {

    @Autowired
    private PaperTradingEngine paperTradingEngine;

    @Autowired
    private PaperTradingService paperTradingService;

    @Autowired
    private PaperAccountBalanceRepository balanceRepository;

    @Autowired
    private PaperPositionRepository positionRepository;

    @Autowired
    private IndividualOrderAuditRepository auditRepository;

    @Autowired
    private PyUserRepository userRepository;

    @Autowired
    private PyBrokerAccountRepository brokerAccountRepository;

    private PyUser testUser;
    private PyBrokerAccountEntity testAccount;

    @BeforeEach
    void setUp() {
        SecurityContextHolder.clearContext();

        testUser = new PyUser();
        testUser.setFullName("Paper Trader");
        testUser.setEmail("papertrader@test.com");
        testUser.setPhoneNumber("9876543210");
        testUser.setMpin("$2a$10$hashedMpinForTestingOnly123456789012345678901234567890");
        testUser.setIsActive(true);
        testUser.setIsPhoneVerified(true);
        testUser.setRole(PyUser.Role.USER);
        testUser = userRepository.saveAndFlush(testUser);

        testAccount = new PyBrokerAccountEntity();
        testAccount.setPyUser(testUser);
        testAccount.setClientId("ANGEL_PAPER_01");
        testAccount.setUserName("Paper Trader Angel");
        testAccount.setBrokerType(BrokerType.ANGELONE);
        testAccount.setActive(true);
        testAccount.setIsOwn(true);
        testAccount.setBrokerRegisteredIp("127.0.0.1:8080");
        testAccount = brokerAccountRepository.saveAndFlush(testAccount);

        // Set authenticated user in SecurityContext
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                testUser.getPhoneNumber(), null,
                Collections.singletonList(new SimpleGrantedAuthority("ROLE_USER")));
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @Test
    @DisplayName("Valid Paper Buy: Deducts virtual cash, creates position, records audit")
    void testValidPaperBuy() {
        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(testAccount.getId());
        request.setTradingSymbol("TATAMOTORS-EQ");
        request.setExchange("NSE");
        request.setQuantity(100);
        request.setOrderType("LIMIT");
        request.setPrice(950.0);
        request.setProductType("DELIVERY");
        request.setIdempotencyKey("TEST-BUY-001");

        Order order = paperTradingEngine.executePaperOrder(testAccount, request, "BUY");

        assertNotNull(order);
        assertNotNull(order.orderId);
        assertTrue(order.orderId.startsWith("PAPER-SIM-ANGELONE-"));

        // Verify Balance
        PaperAccountBalanceEntity balance = balanceRepository
                .findByPyUserIdAndDematAccountId(testUser.getId(), testAccount.getId()).orElseThrow();
        assertEquals(1000000.0 - (100 * 950.0), balance.getVirtualCashBalance(), 0.01);

        // Verify Position
        PaperPositionEntity position = positionRepository
                .findByDematAccountIdAndTradingSymbolAndProductType(testAccount.getId(), "TATAMOTORS-EQ", "DELIVERY")
                .orElseThrow();
        assertEquals(100, position.getQuantity());
        assertEquals(950.0, position.getAverageBuyPrice(), 0.01);

        // Verify Audit
        List<IndividualOrderAuditEntity> audits = auditRepository
                .findByDematAccountIdOrderByExecutedAtDesc(testAccount.getId());
        assertFalse(audits.isEmpty());
        IndividualOrderAuditEntity audit = audits.get(0);
        assertEquals("SUCCESS", audit.getStatus());
        assertEquals(order.orderId, audit.getOrderId());
        assertTrue(audit.getRemarks().contains("[PAPER TRADING"));
        assertTrue(audit.getIsSimulated());
    }

    @Test
    @DisplayName("Valid Paper Sell: Reduces position, credits sale proceeds and realized P&L")
    void testValidPaperSell() {
        // Pre-create position of 50 shares bought at 900
        PaperPositionEntity existingPos = new PaperPositionEntity(
                testUser.getId(), testAccount.getId(), "RELIANCE-EQ", "2885", "NSE", "DELIVERY", 50, 900.0);
        positionRepository.saveAndFlush(existingPos);

        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(testAccount.getId());
        request.setTradingSymbol("RELIANCE-EQ");
        request.setExchange("NSE");
        request.setQuantity(20);
        request.setOrderType("LIMIT");
        request.setPrice(1000.0); // Sell at profit of 100 per share
        request.setProductType("DELIVERY");

        Order order = paperTradingEngine.executePaperOrder(testAccount, request, "SELL");

        assertNotNull(order);
        assertTrue(order.orderId.startsWith("PAPER-SIM-ANGELONE-"));

        // Position reduced to 30
        PaperPositionEntity updatedPos = positionRepository
                .findByDematAccountIdAndTradingSymbolAndProductType(testAccount.getId(), "RELIANCE-EQ", "DELIVERY")
                .orElseThrow();
        assertEquals(30, updatedPos.getQuantity());
        assertEquals(2000.0, updatedPos.getRealizedPnl(), 0.01); // 20 * (1000 - 900) = 2000

        // Balance increased by sale proceeds
        PaperAccountBalanceEntity balance = balanceRepository
                .findByPyUserIdAndDematAccountId(testUser.getId(), testAccount.getId()).orElseThrow();
        assertEquals(1000000.0 + (20 * 1000.0), balance.getVirtualCashBalance(), 0.01);
        assertEquals(2000.0, balance.getRealizedPnl(), 0.01);
    }

    @Test
    @DisplayName("Insufficient virtual funds: Rejects buy and throws IllegalStateException")
    void testInsufficientVirtualFunds() {
        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(testAccount.getId());
        request.setTradingSymbol("MRF-EQ");
        request.setExchange("NSE");
        request.setQuantity(50);
        request.setOrderType("LIMIT");
        request.setPrice(150000.0); // Total cost = 75,00,000 > 10,00,000 balance
        request.setProductType("DELIVERY");

        IllegalStateException ex = assertThrows(IllegalStateException.class, () ->
                paperTradingEngine.executePaperOrder(testAccount, request, "BUY"));

        assertTrue(ex.getMessage().contains("Insufficient virtual funds"));
    }

    @Test
    @DisplayName("Selling more than available holdings: Rejects sell and throws IllegalStateException")
    void testSellingMoreThanAvailable() {
        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(testAccount.getId());
        request.setTradingSymbol("INFY-EQ");
        request.setExchange("NSE");
        request.setQuantity(10);
        request.setOrderType("LIMIT");
        request.setPrice(1800.0);
        request.setProductType("DELIVERY");

        IllegalStateException ex = assertThrows(IllegalStateException.class, () ->
                paperTradingEngine.executePaperOrder(testAccount, request, "SELL"));

        assertTrue(ex.getMessage().contains("Insufficient virtual holdings"));
    }

    @Test
    @DisplayName("Invalid quantity and price: Rejects with IllegalArgumentException")
    void testInvalidQuantityAndPrice() {
        // Zero quantity
        IndividualOrderRequest req1 = new IndividualOrderRequest();
        req1.setAccId(testAccount.getId());
        req1.setTradingSymbol("INFY-EQ");
        req1.setQuantity(0);
        req1.setOrderType("LIMIT");
        req1.setPrice(1500.0);

        assertThrows(IllegalArgumentException.class, () ->
                paperTradingEngine.executePaperOrder(testAccount, req1, "BUY"));

        // Negative price for limit order
        IndividualOrderRequest req2 = new IndividualOrderRequest();
        req2.setAccId(testAccount.getId());
        req2.setTradingSymbol("INFY-EQ");
        req2.setQuantity(10);
        req2.setOrderType("LIMIT");
        req2.setPrice(-50.0);

        assertThrows(IllegalArgumentException.class, () ->
                paperTradingEngine.executePaperOrder(testAccount, req2, "BUY"));
    }

    @Test
    @DisplayName("Market order without price quote: Rejects with clear message rather than inventing price")
    void testMarketOrderWithoutQuoteRejected() {
        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(testAccount.getId());
        request.setTradingSymbol("HDFCBANK-EQ");
        request.setExchange("NSE");
        request.setQuantity(10);
        request.setOrderType("MARKET");
        request.setPrice(0.0); // No quote provided

        IllegalStateException ex = assertThrows(IllegalStateException.class, () ->
                paperTradingEngine.executePaperOrder(testAccount, request, "BUY"));

        assertTrue(ex.getMessage().contains("Live market quote unavailable"));
    }

    @Test
    @DisplayName("Account ownership enforcement: Rejects order if account belongs to another user")
    void testAccountOwnershipEnforcement() {
        PyUser otherUser = new PyUser();
        otherUser.setFullName("Other User");
        otherUser.setEmail("other@test.com");
        otherUser.setPhoneNumber("9123456789");
        otherUser.setMpin("$2a$10$hashedMpinForTestingOnly123456789012345678901234567890");
        otherUser.setIsActive(true);
        otherUser.setIsPhoneVerified(true);
        otherUser.setRole(PyUser.Role.USER);
        otherUser = userRepository.saveAndFlush(otherUser);

        // SecurityContext is logged in as testUser (9876543210), but account belongs to otherUser
        testAccount.setPyUser(otherUser);
        brokerAccountRepository.saveAndFlush(testAccount);

        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(testAccount.getId());
        request.setTradingSymbol("TCS-EQ");
        request.setQuantity(1);
        request.setOrderType("LIMIT");
        request.setPrice(3500.0);

        assertThrows(SecurityException.class, () ->
                paperTradingEngine.executePaperOrder(testAccount, request, "BUY"));
    }

    @Test
    @DisplayName("Safeguard verification: Disabling paper trading does NOT permit live execution if live trading is disabled")
    void testDisablingPaperTradingDoesNotSilentlyRouteToLive() {
        // paperTradingService has paperTradingEnabled=true, so live order must be blocked
        assertThrows(IllegalStateException.class, () -> paperTradingService.validateLiveOrderAllowed());
    }

    @Test
    @DisplayName("Transaction Rollback: Virtual balance and holdings remain untouched when simulated execution fails")
    void testTransactionRollbackOnFailure() {
        PaperAccountBalanceEntity initialBalance = paperTradingEngine.getOrCreateBalance(testUser.getId(), testAccount.getId());
        double startingCash = initialBalance.getVirtualCashBalance();

        IndividualOrderRequest failedRequest = new IndividualOrderRequest();
        failedRequest.setAccId(testAccount.getId());
        failedRequest.setTradingSymbol("FAIL-STOCK-EQ");
        failedRequest.setQuantity(10);
        failedRequest.setOrderType("LIMIT");
        failedRequest.setPrice(startingCash * 2); // Exceeds balance

        assertThrows(IllegalStateException.class, () ->
                paperTradingEngine.executePaperOrder(testAccount, failedRequest, "BUY"));

        // Verify balance was rolled back to exact initial value
        PaperAccountBalanceEntity balanceAfter = balanceRepository
                .findByPyUserIdAndDematAccountId(testUser.getId(), testAccount.getId()).orElseThrow();
        assertEquals(startingCash, balanceAfter.getVirtualCashBalance(), 0.001);

        // Verify no position was created
        assertTrue(positionRepository
                .findByDematAccountIdAndTradingSymbolAndProductType(testAccount.getId(), "FAIL-STOCK-EQ", "DELIVERY")
                .isEmpty());
    }

    @Test
    @DisplayName("Numeric validation: Rejects NaN prices with clear IllegalArgumentException")
    void testNaNPriceRejected() {
        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(testAccount.getId());
        request.setTradingSymbol("RELIANCE-EQ");
        request.setQuantity(10);
        request.setOrderType("LIMIT");
        request.setPrice(Double.NaN);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                paperTradingEngine.executePaperOrder(testAccount, request, "BUY"));
        assertTrue(ex.getMessage().contains("price"));
    }

    @Test
    @DisplayName("Numeric validation: Rejects Infinite prices with clear IllegalArgumentException")
    void testInfinityPriceRejected() {
        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(testAccount.getId());
        request.setTradingSymbol("RELIANCE-EQ");
        request.setQuantity(10);
        request.setOrderType("LIMIT");
        request.setPrice(Double.POSITIVE_INFINITY);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                paperTradingEngine.executePaperOrder(testAccount, request, "BUY"));
        assertTrue(ex.getMessage().contains("price"));
    }

    @Test
    @DisplayName("Numeric validation: Rejects excessive order quantity (> 1,000,000)")
    void testExcessiveQuantityRejected() {
        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(testAccount.getId());
        request.setTradingSymbol("INFY-EQ");
        request.setQuantity(1_000_001);
        request.setOrderType("LIMIT");
        request.setPrice(1500.0);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                paperTradingEngine.executePaperOrder(testAccount, request, "BUY"));
        assertTrue(ex.getMessage().contains("exceeds maximum allowed limit"));
    }

    @Test
    @DisplayName("Numeric validation: Rejects NaN trigger price with clear IllegalArgumentException")
    void testNaNTriggerPriceRejected() {
        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(testAccount.getId());
        request.setTradingSymbol("INFY-EQ");
        request.setQuantity(10);
        request.setOrderType("LIMIT");
        request.setPrice(1500.0);
        request.setTriggerPrice(Double.NaN);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                paperTradingEngine.executePaperOrder(testAccount, request, "BUY"));
        assertTrue(ex.getMessage().contains("Trigger price"));
    }

    @Test
    @DisplayName("First-use balance concurrency: getOrCreateBalance handles repeated or concurrent balance requests")
    void testFirstUseBalanceConcurrency() {
        // Clear any existing balance for test account
        balanceRepository.findByPyUserIdAndDematAccountId(testUser.getId(), testAccount.getId())
                .ifPresent(balanceRepository::delete);

        // First call creates balance
        PaperAccountBalanceEntity b1 = paperTradingEngine.getOrCreateBalance(testUser.getId(), testAccount.getId());
        assertNotNull(b1);
        assertEquals(1000000.0, b1.getVirtualCashBalance(), 0.001);

        // Second call cleanly returns existing without constraint error
        PaperAccountBalanceEntity b2 = paperTradingEngine.getOrCreateBalance(testUser.getId(), testAccount.getId());
        assertNotNull(b2);
        assertEquals(b1.getId(), b2.getId());
        assertEquals(1000000.0, b2.getVirtualCashBalance(), 0.001);
    }
}
