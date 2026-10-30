package com.py.trading.service;

import com.py.crypto.CryptoService;
import com.py.crypto.EncryptedStringConverter;
import com.py.easytrade.dto.IndividualOrderRequest;
import com.py.trading.entity.OrderRequestIdempotencyEntity;
import com.py.trading.exception.IdempotencyConflictException;
import com.py.trading.repository.OrderRequestIdempotencyRepository;
import org.json.JSONObject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;

import java.util.Optional;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("h2")
@Import({OrderIdempotencyService.class, CryptoService.class, EncryptedStringConverter.class})
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
        "app.crypto.broker-encryption-key=MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDE=",
        "app.crypto.allow-legacy-plaintext=true"
})
public class OrderIdempotencyTest {

    @Autowired
    private OrderIdempotencyService idempotencyService;

    @Autowired
    private OrderRequestIdempotencyRepository repository;

    private Long userId = 101L;
    private Long accountId = 202L;

    @BeforeEach
    void setUp() {
        repository.deleteAll();
    }

    @Test
    @DisplayName("Same Key & Same Request: Returns cached response on second call without duplicate execution")
    void testSameKeySameRequestReturnsCached() {
        String key = "KEY-IDEM-001";
        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(accountId);
        request.setTradingSymbol("INFY-EQ");
        request.setExchange("NSE");
        request.setQuantity(10);
        request.setOrderType("LIMIT");
        request.setPrice(1500.0);
        request.setProductType("DELIVERY");

        AtomicInteger executionCount = new AtomicInteger(0);

        // First Call
        OrderIdempotencyService.IdempotentResult res1 = idempotencyService.execute(
                userId, accountId, key, request, "BUY", () -> {
                    executionCount.incrementAndGet();
                    JSONObject json = new JSONObject();
                    json.put("status", "SUCCESS");
                    json.put("orderId", "SIM-INFY-1001");
                    return json;
                }
        );

        assertFalse(res1.isReplayed());
        assertEquals(1, executionCount.get());
        assertEquals("SIM-INFY-1001", res1.getPayload().getString("orderId"));

        // Second Call with exact same key and request parameters
        OrderIdempotencyService.IdempotentResult res2 = idempotencyService.execute(
                userId, accountId, key, request, "BUY", () -> {
                    executionCount.incrementAndGet();
                    JSONObject json = new JSONObject();
                    json.put("status", "SUCCESS");
                    json.put("orderId", "SIM-INFY-SECOND-CALL");
                    return json;
                }
        );

        assertTrue(res2.isReplayed());
        assertEquals(1, executionCount.get()); // Action was NOT executed again!
        assertEquals("SIM-INFY-1001", res2.getPayload().getString("orderId"));
    }

    @Test
    @DisplayName("Same Key with Different Payload: Throws IdempotencyConflictException (409)")
    void testSameKeyDifferentPayloadThrowsConflict() {
        String key = "KEY-IDEM-002";
        IndividualOrderRequest req1 = new IndividualOrderRequest();
        req1.setAccId(accountId);
        req1.setTradingSymbol("SBIN-EQ");
        req1.setExchange("NSE");
        req1.setQuantity(50);
        req1.setOrderType("LIMIT");
        req1.setPrice(800.0);

        // First call
        idempotencyService.execute(userId, accountId, key, req1, "BUY", () -> {
            JSONObject json = new JSONObject();
            json.put("status", "SUCCESS");
            json.put("orderId", "SIM-SBIN-1001");
            return json;
        });

        // Second call with DIFFERENT quantity (100 instead of 50)
        IndividualOrderRequest req2 = new IndividualOrderRequest();
        req2.setAccId(accountId);
        req2.setTradingSymbol("SBIN-EQ");
        req2.setExchange("NSE");
        req2.setQuantity(100); // Mismatched payload
        req2.setOrderType("LIMIT");
        req2.setPrice(800.0);

        IdempotencyConflictException ex = assertThrows(IdempotencyConflictException.class, () ->
                idempotencyService.execute(userId, accountId, key, req2, "BUY", () -> {
                    JSONObject json = new JSONObject();
                    json.put("status", "SUCCESS");
                    return json;
                })
        );

        assertEquals(409, ex.getStatusCode());
        assertTrue(ex.getMessage().contains("already used for a different order request"));
    }

    @Test
    @DisplayName("Persistence Across Repository Reload: Idempotency entity survives and reflects COMPLETED state")
    void testPersistenceAcrossDatabaseReload() {
        String key = "KEY-IDEM-003";
        IndividualOrderRequest req = new IndividualOrderRequest();
        req.setAccId(accountId);
        req.setTradingSymbol("WIPRO-EQ");
        req.setExchange("NSE");
        req.setQuantity(25);
        req.setOrderType("LIMIT");
        req.setPrice(550.0);

        idempotencyService.execute(userId, accountId, key, req, "BUY", () -> {
            JSONObject json = new JSONObject();
            json.put("status", "SUCCESS");
            json.put("orderId", "SIM-WIPRO-999");
            return json;
        });

        // Fetch fresh record from DB
        Optional<OrderRequestIdempotencyEntity> entityOpt =
                repository.findByPyUserIdAndDematAccountIdAndIdempotencyKey(userId, accountId, key);

        assertTrue(entityOpt.isPresent());
        OrderRequestIdempotencyEntity entity = entityOpt.get();
        assertEquals("COMPLETED", entity.getStatus());
        assertEquals("SIM-WIPRO-999", entity.getOrderId());
        assertEquals(200, entity.getHttpStatusCode());
        assertNotNull(entity.getResponsePayload());
        assertTrue(entity.getResponsePayload().contains("SIM-WIPRO-999"));
    }

    @Test
    @DisplayName("Concurrent Duplicate Submissions: Exactly one execution occurs across parallel threads")
    void testConcurrentDuplicateSubmissions() throws InterruptedException {
        String key = "KEY-IDEM-CONCURRENT-001";
        IndividualOrderRequest req = new IndividualOrderRequest();
        req.setAccId(accountId);
        req.setTradingSymbol("ITC-EQ");
        req.setExchange("NSE");
        req.setQuantity(100);
        req.setOrderType("LIMIT");
        req.setPrice(450.0);

        int threadCount = 5;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch finishLatch = new CountDownLatch(threadCount);

        AtomicInteger executionCounter = new AtomicInteger(0);
        AtomicInteger successCounter = new AtomicInteger(0);

        for (int i = 0; i < threadCount; i++) {
            executor.submit(() -> {
                try {
                    startLatch.await();
                    OrderIdempotencyService.IdempotentResult result = idempotencyService.execute(
                            userId, accountId, key, req, "BUY", () -> {
                                executionCounter.incrementAndGet();
                                try {
                                    Thread.sleep(50); // simulate brief processing
                                } catch (InterruptedException ignored) {}
                                JSONObject json = new JSONObject();
                                json.put("status", "SUCCESS");
                                json.put("orderId", "SIM-ITC-CONCURRENT");
                                return json;
                            }
                    );
                    if (result != null && result.getStatusCode() == 200) {
                        successCounter.incrementAndGet();
                    }
                } catch (IdempotencyConflictException ice) {
                    // Expected for concurrent in-progress threads
                } catch (Exception ignored) {
                } finally {
                    finishLatch.countDown();
                }
            });
        }

        startLatch.countDown(); // Start all threads at once
        assertTrue(finishLatch.await(5, TimeUnit.SECONDS));
        executor.shutdown();

        // Concurrency guarantee: supplier must be called at most once
        assertEquals(1, executionCounter.get(), "Order execution action must only execute once");
        assertTrue(successCounter.get() >= 1, "At least the primary thread succeeded");
    }
}
