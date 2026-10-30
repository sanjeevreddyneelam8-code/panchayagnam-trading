package com.py.trading.service;

import com.py.common.enums.BrokerType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.UUID;

/**
 * Service to manage server-side paper trading safeguards.
 * When enabled (default for dev/local/test), orders are simulated and
 * will NEVER reach live broker APIs.
 */
@Service
public class PaperTradingService {

    private static final Logger log = LoggerFactory.getLogger(PaperTradingService.class);

    @Value("${trading.paper-trading.enabled:true}")
    private boolean paperTradingEnabled;

    @Value("${trading.live-trading.enabled:false}")
    private boolean liveTradingEnabled;

    /**
     * Returns true if paper trading is active.
     */
    public boolean isPaperTradingEnabled() {
        return paperTradingEnabled;
    }

    /**
     * Returns true if live trading is explicitly permitted.
     */
    public boolean isLiveTradingEnabled() {
        return liveTradingEnabled;
    }

    /**
     * Generates a distinct simulated order ID that cannot be confused with live broker order IDs.
     * Format: PAPER-SIM-<BROKER>-<TIMESTAMP>-<UUID4>
     */
    public String generateSimulatedOrderId(BrokerType brokerType) {
        String shortId = UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        long timestamp = System.currentTimeMillis();
        String broker = (brokerType != null) ? brokerType.name() : "BROKER";
        String orderId = String.format("PAPER-SIM-%s-%d-%s", broker, timestamp, shortId);
        log.warn("🛡️ [PAPER TRADING - SIMULATED ORDER] Simulated order generated | broker={} orderId={}", broker, orderId);
        return orderId;
    }

    /**
     * Asserts that live orders cannot execute if paper trading is enabled or live trading is not explicitly authorized.
     */
    public void validateLiveOrderAllowed() {
        if (paperTradingEnabled) {
            log.error("CRITICAL: Live order blocked because paper-trading mode is ENABLED!");
            throw new IllegalStateException("Accidental live trade blocked: paper-trading mode is enabled");
        }
        if (!liveTradingEnabled) {
            log.error("CRITICAL: Live order blocked because live trading is not enabled in configuration (trading.live-trading.enabled=false)!");
            throw new IllegalStateException("Live trade blocked: live trading is not enabled in configuration (trading.live-trading.enabled=false)");
        }
    }
}
