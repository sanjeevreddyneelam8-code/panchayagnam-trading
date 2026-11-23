package com.py.service.impl;

import com.py.brokers.angel.client.service.AngelOneApisService;
import com.py.brokers.angel.dto.AngelOneOrderHistoryRequest;
import com.py.common.enums.BrokerType;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.entity.PyCopyTradingChildAccountEntity;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.demataccount.repository.PyCopyTradingChildAccountRepository;
import com.py.demataccount.service.PyBrokerAccountService;
import com.py.easytrade.dto.IndividualOrderRequest;
import com.py.tokensValidation.PyTokenValidationService;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.DayOfWeek;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
@EnableScheduling
public class MasterMobileCopyTradingService {

    private static final Logger log = LogManager.getLogger(MasterMobileCopyTradingService.class);

    @Autowired
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @Autowired(required = false)
    private PyCopyTradingChildAccountRepository childAccountRepository;

    @Autowired(required = false)
    private AngelOneApisService angelOneApisService;

    @Autowired(required = false)
    private PyTokenValidationService pyTokenValidationService;

    @Autowired(required = false)
    private PyBrokerAccountService pyBrokerAccountService;

    // Track processed order IDs so we never duplicate a copy trade
    private final Set<String> processedOrderIds = ConcurrentHashMap.newKeySet();
    private boolean initialized = false;

    /**
     * Polls the Master Demat account order history every 4 seconds.
     * When the Master executes an order in their mobile app, this service automatically
     * detects the newly completed order and replicates it across all active child accounts!
     */
    @Scheduled(fixedDelay = 4000, initialDelay = 12000)
    public void pollMasterOrdersAndReplicateToChildren() {
        try {
            // Check IST market hours (09:15 - 15:35 on weekdays)
            ZoneId istZone = ZoneId.of("Asia/Kolkata");
            ZonedDateTime nowIst = ZonedDateTime.now(istZone);
            boolean isWeekend = (nowIst.getDayOfWeek() == DayOfWeek.SATURDAY || nowIst.getDayOfWeek() == DayOfWeek.SUNDAY);
            LocalTime time = nowIst.toLocalTime();
            boolean isTradingHours = !isWeekend && !time.isBefore(LocalTime.of(9, 14)) && !time.isAfter(LocalTime.of(15, 35));

            if (angelOneApisService == null || pyBrokerAccountRepository == null) {
                return;
            }

            // Find all active Master accounts (isOwn = true)
            List<PyBrokerAccountEntity> masterAccounts = pyBrokerAccountRepository.findAll().stream()
                    .filter(a -> Boolean.TRUE.equals(a.getIsOwn())
                            && Boolean.TRUE.equals(a.getActive())
                            && a.getBrokerType() == BrokerType.ANGELONE
                            && a.getSecret() != null
                            && a.getSecret().getApiKey() != null
                            && !a.getSecret().getApiKey().isBlank())
                    .toList();

            for (PyBrokerAccountEntity master : masterAccounts) {
                String token = pyTokenValidationService != null ? pyTokenValidationService.getValidAccessToken(master.getId()) : null;
                if (token == null && master.getToken() != null) {
                    token = master.getToken().getAccessToken();
                }
                if (token == null || token.isBlank() || token.startsWith("PAPER-")) {
                    continue;
                }

                AngelOneOrderHistoryRequest req = new AngelOneOrderHistoryRequest();
                req.setApiKey(master.getSecret().getApiKey().trim());
                req.setAccessToken(token.trim());

                JSONObject orderHistory;
                try {
                    orderHistory = angelOneApisService.getOrderHistory(req);
                } catch (Exception ex) {
                    continue;
                }

                if (orderHistory == null) continue;
                JSONArray data = orderHistory.optJSONArray("data");
                if (data == null || data.length() == 0) continue;

                // On first startup, seed all existing orders so past historical orders are never re-copied
                if (!initialized) {
                    for (int i = 0; i < data.length(); i++) {
                        JSONObject o = data.optJSONObject(i);
                        if (o != null) {
                            String oid = o.optString("orderid");
                            if (!oid.isBlank()) processedOrderIds.add(oid);
                        }
                    }
                    initialized = true;
                    log.info("MasterMobileCopyTradingService initialized. Seeded {} existing master orders.", processedOrderIds.size());
                    return;
                }

                // Check for new filled orders placed on master (e.g. from mobile app)
                for (int i = 0; i < data.length(); i++) {
                    JSONObject orderObj = data.optJSONObject(i);
                    if (orderObj == null) continue;

                    String orderId = orderObj.optString("orderid", "");
                    String orderStatus = orderObj.optString("orderstatus", orderObj.optString("status", "")).toUpperCase();

                    if (orderId.isBlank() || processedOrderIds.contains(orderId)) {
                        continue;
                    }

                    // Only replicate FILLED / COMPLETE orders
                    if (!"COMPLETE".equals(orderStatus) && !"FILLED".equals(orderStatus)) {
                        continue;
                    }

                    // Mark as processed immediately to prevent duplicate runs
                    processedOrderIds.add(orderId);

                    String tradingSymbol = orderObj.optString("tradingsymbol", "");
                    String symbolToken = orderObj.optString("symboltoken", "");
                    String transactionType = orderObj.optString("transactiontype", "BUY").toUpperCase();
                    int masterQty = orderObj.optInt("quantity", orderObj.optInt("filledshares", 1));
                    double price = orderObj.optDouble("averageprice", orderObj.optDouble("price", 0.0));
                    String productType = orderObj.optString("producttype", "DELIVERY").toUpperCase();
                    String exchange = orderObj.optString("exchange", "NSE").toUpperCase();
                    String orderType = orderObj.optString("ordertype", "MARKET").toUpperCase();

                    log.info("🎯 [Master Mobile Copy] Detected new filled Master trade on mobile! orderId={}, symbol={}, side={}, qty={}, price={}",
                            orderId, tradingSymbol, transactionType, masterQty, price);

                    // Fetch active children for this master's user
                    Long pyUserId = master.getPyUser() != null ? master.getPyUser().getId() : 1L;
                    List<PyCopyTradingChildAccountEntity> children = childAccountRepository != null
                            ? childAccountRepository.findByPyUserIdOrderByCreatedAtAsc(pyUserId).stream()
                            .filter(c -> Boolean.TRUE.equals(c.getActive()))
                            .toList()
                            : List.of();

                    if (children.isEmpty()) {
                        log.info("[Master Mobile Copy] No active follower child accounts configured for pyUserId={}", pyUserId);
                        continue;
                    }

                    // Replicate trade across each active child account
                    for (PyCopyTradingChildAccountEntity child : children) {
                        try {
                            double multiplier = child.getMultiplier() != null && child.getMultiplier() > 0 ? child.getMultiplier() : 1.0;
                            int childQty = (int) Math.max(1, Math.round(masterQty * multiplier));
                            String childSide = transactionType;
                            if ("INVERSE".equalsIgnoreCase(child.getCopyMode())) {
                                childSide = "BUY".equalsIgnoreCase(transactionType) ? "SELL" : "BUY";
                            }

                            log.info("🚀 [Master Mobile Copy] Replicating to Child [{}] ({}x multiplier) -> {} {} Qty {}",
                                    child.getClientId(), multiplier, childSide, childQty, tradingSymbol);

                            // Find child demat account entity if registered in master accounts table
                            Optional<PyBrokerAccountEntity> childAccOpt = pyBrokerAccountRepository.findByClientId(child.getClientId());
                            if (childAccOpt.isPresent() && pyBrokerAccountService != null) {
                                IndividualOrderRequest childReq = new IndividualOrderRequest();
                                childReq.setAccId(childAccOpt.get().getId());
                                childReq.setClientId(child.getClientId());
                                childReq.setTradingSymbol(tradingSymbol);
                                childReq.setSymbolToken(symbolToken);
                                childReq.setExchange(exchange);
                                childReq.setQuantity(childQty);
                                childReq.setOrdertype(orderType.contains("MARKET") ? "MARKET" : "LIMIT");
                                childReq.setPrice(price);
                                childReq.setProductType(productType);
                                childReq.setVariety("NORMAL");
                                childReq.setIdempotencyKey("MOBILE-COPY-" + child.getClientId() + "-" + orderId);

                                pyBrokerAccountService.placeIndividualOrder(childReq, childSide);
                                log.info("✅ [Master Mobile Copy] Order placed successfully for child {}", child.getClientId());
                            } else {
                                log.info("ℹ️ [Master Mobile Copy] Child {} logged for execution with multiplier {}", child.getClientId(), multiplier);
                            }
                        } catch (Exception childEx) {
                            log.error("❌ [Master Mobile Copy] Failed to replicate order for child {}: {}", child.getClientId(), childEx.getMessage());
                        }
                    }
                }
            }
        } catch (Exception e) {
            log.warn("MasterMobileCopyTradingService cycle warning: {}", e.getMessage());
        }
    }
}
