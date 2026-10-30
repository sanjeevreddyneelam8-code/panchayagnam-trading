package com.py.goodwill.service;

import com.py.goodwill.dto.*;
import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

/**
 * Service for official Goodwill Giga API (Interactive Trading API).
 * Official Documentation: https://gwcindia.in / Goodwill Giga Developer API
 */
@Service
public class GoodwillApiService {

    private static final Logger log = LoggerFactory.getLogger(GoodwillApiService.class);

    private static final String GOODWILL_BASE_URL = "https://giga.gwcindia.in/interactive";
    private static final String SESSION_URL = GOODWILL_BASE_URL + "/user/session";
    private static final String LIMITS_URL = GOODWILL_BASE_URL + "/user/limits";
    private static final String ORDERS_URL = GOODWILL_BASE_URL + "/orders";
    private static final String POSITIONS_URL = GOODWILL_BASE_URL + "/portfolio/positions";
    private static final String HOLDINGS_URL = GOODWILL_BASE_URL + "/portfolio/holdings";

    @org.springframework.beans.factory.annotation.Value("${trading.paper-trading.enabled:true}")
    private boolean paperTradingEnabled;

    @Autowired
    private RestTemplate restTemplate;

    private HttpHeaders buildGoodwillHeaders(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("Accept", "application/json");
        if (accessToken != null && !accessToken.isBlank()) {
            headers.set("Authorization", accessToken);
        }
        return headers;
    }

    // ─── LOGIN / SESSION ─────────────────────────────────────────────────────
    public JSONObject login(GoodwillLoginRequest request) {
        log.info("Goodwill login attempt | clientId={}", request.getClientId());

        if (paperTradingEnabled && (
                (request.getApiKey() != null && request.getApiKey().startsWith("SIM-")) ||
                (request.getApiSecret() != null && request.getApiSecret().startsWith("SIM-")) ||
                (request.getClientId() != null && (request.getClientId().startsWith("SIM-") || request.getClientId().startsWith("GW"))))) {
            log.info("🛡️ [PAPER TRADING] Simulated Goodwill login for clientId={}", request.getClientId());
            JSONObject successObj = new JSONObject();
            successObj.put("status", true);
            successObj.put("message", "SUCCESS");
            successObj.put("accessToken", "PAPER-SIM-GW-" + System.currentTimeMillis());
            successObj.put("userId", request.getClientId());
            return successObj;
        }

        JSONObject body = new JSONObject();
        body.put("secretKey", request.getApiSecret());
        body.put("appKey", request.getApiKey());
        body.put("source", "WEBAPI");

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);

        HttpEntity<String> entity = new HttpEntity<>(body.toString(), headers);

        try {
            ResponseEntity<String> response = restTemplate.postForEntity(SESSION_URL, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject result = json.optJSONObject("result");
            if (result != null && result.has("token")) {
                String token = result.getString("token");
                JSONObject successObj = new JSONObject();
                successObj.put("status", true);
                successObj.put("message", "SUCCESS");
                successObj.put("accessToken", token);
                successObj.put("userId", result.optString("userID", request.getClientId()));
                log.info("Goodwill login SUCCESS | clientId={}", request.getClientId());
                return successObj;
            } else {
                throw new RuntimeException("Goodwill login failed: " + json.optString("description", "no token in response"));
            }
        } catch (Exception e) {
            log.error("Goodwill login error for clientId={}: {}", request.getClientId(), e.getMessage());
            throw new RuntimeException("Goodwill login failed: " + e.getMessage(), e);
        }
    }

    // ─── LIMITS / RMS ────────────────────────────────────────────────────────
    public JSONObject getLimits(GoodwillBaseRequest request) {
        log.info("Goodwill fetch limits | clientId={}", request.getClientId());
        HttpHeaders headers = buildGoodwillHeaders(request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(LIMITS_URL, HttpMethod.GET, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject result = json.optJSONObject("result");
            double cash = 0.0;
            if (result != null) {
                cash = result.optDouble("RMSLimit", result.optDouble("Balance", 0.0));
            }
            JSONObject out = new JSONObject();
            out.put("status", true);
            out.put("availablecash", String.valueOf(cash));
            out.put("data", result);
            return out;
        } catch (Exception e) {
            log.warn("Goodwill limits fetch error | clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject fallback = new JSONObject();
            fallback.put("status", false);
            fallback.put("availablecash", "0.0");
            fallback.put("error", e.getMessage());
            return fallback;
        }
    }

    // ─── PLACE ORDER ─────────────────────────────────────────────────────────
    public JSONObject placeOrder(GoodwillPlaceOrderRequest request) {
        log.info("Goodwill place order | clientId={} segment={} side={}",
                request.getClientId(), request.getExchangeSegment(), request.getOrderSide());

        HttpHeaders headers = buildGoodwillHeaders(request.getAccessToken());
        JSONObject body = new JSONObject();
        body.put("exchangeSegment", request.getExchangeSegment());
        body.put("exchangeInstrumentID", request.getExchangeInstrumentId());
        body.put("productType", request.getProductType());
        body.put("orderType", request.getOrderType());
        body.put("orderSide", request.getOrderSide());
        body.put("timeInForce", request.getTimeInForce() != null ? request.getTimeInForce() : "DAY");
        body.put("disclosedQuantity", request.getDisclosedQuantity() != null ? request.getDisclosedQuantity() : 0);
        body.put("orderQuantity", request.getOrderQuantity());
        body.put("limitPrice", request.getLimitPrice() != null ? request.getLimitPrice() : 0.0);
        body.put("stopPrice", request.getStopPrice() != null ? request.getStopPrice() : 0.0);
        body.put("orderUniqueIdentifier", request.getOrderUniqueIdentifier() != null ? request.getOrderUniqueIdentifier() : "PY-ORDER");

        HttpEntity<String> entity = new HttpEntity<>(body.toString(), headers);

        try {
            ResponseEntity<String> response = restTemplate.postForEntity(ORDERS_URL, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject result = json.optJSONObject("result");
            String orderId = result != null ? result.optString("AppOrderID", "") : "";
            JSONObject out = new JSONObject();
            out.put("status", true);
            out.put("orderId", orderId);
            out.put("message", "Goodwill order placed successfully");
            return out;
        } catch (Exception e) {
            log.error("Goodwill place order error | clientId={}: {}", request.getClientId(), e.getMessage());
            throw new RuntimeException("Goodwill place order failed: " + e.getMessage(), e);
        }
    }

    // ─── MODIFY ORDER ────────────────────────────────────────────────────────
    public JSONObject modifyOrder(GoodwillModifyOrderRequest request) {
        log.info("Goodwill modify order | clientId={} appOrderId={}", request.getClientId(), request.getAppOrderId());
        HttpHeaders headers = buildGoodwillHeaders(request.getAccessToken());

        JSONObject body = new JSONObject();
        body.put("appOrderID", request.getAppOrderId());
        if (request.getModifiedProductType() != null) body.put("modifiedProductType", request.getModifiedProductType());
        if (request.getModifiedOrderType() != null) body.put("modifiedOrderType", request.getModifiedOrderType());
        if (request.getModifiedOrderQuantity() != null) body.put("modifiedOrderQuantity", request.getModifiedOrderQuantity());
        if (request.getModifiedDisclosedQuantity() != null) body.put("modifiedDisclosedQuantity", request.getModifiedDisclosedQuantity());
        if (request.getModifiedLimitPrice() != null) body.put("modifiedLimitPrice", request.getModifiedLimitPrice());
        if (request.getModifiedStopPrice() != null) body.put("modifiedStopPrice", request.getModifiedStopPrice());
        if (request.getModifiedTimeInForce() != null) body.put("modifiedTimeInForce", request.getModifiedTimeInForce());

        HttpEntity<String> entity = new HttpEntity<>(body.toString(), headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(ORDERS_URL, HttpMethod.PUT, entity, String.class);
            return new JSONObject(response.getBody());
        } catch (Exception e) {
            log.error("Goodwill modify order error | appOrderId={}: {}", request.getAppOrderId(), e.getMessage());
            throw new RuntimeException("Goodwill modify order failed: " + e.getMessage(), e);
        }
    }

    // ─── CANCEL ORDER ────────────────────────────────────────────────────────
    public JSONObject cancelOrder(GoodwillCancelOrderRequest request) {
        log.info("Goodwill cancel order | clientId={} appOrderId={}", request.getClientId(), request.getAppOrderId());
        String url = ORDERS_URL + "?appOrderID=" + request.getAppOrderId();

        HttpHeaders headers = buildGoodwillHeaders(request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.DELETE, entity, String.class);
            return new JSONObject(response.getBody());
        } catch (Exception e) {
            log.error("Goodwill cancel order error | appOrderId={}: {}", request.getAppOrderId(), e.getMessage());
            throw new RuntimeException("Goodwill cancel order failed: " + e.getMessage(), e);
        }
    }

    // ─── POSITIONS ───────────────────────────────────────────────────────────
    public JSONObject getPositions(GoodwillBaseRequest request) {
        log.info("Goodwill get positions | clientId={}", request.getClientId());
        HttpHeaders headers = buildGoodwillHeaders(request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(POSITIONS_URL, HttpMethod.GET, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject result = json.optJSONObject("result");
            JSONArray positionList = result != null ? result.optJSONArray("positionList") : new JSONArray();

            JSONObject out = new JSONObject();
            out.put("status", true);
            out.put("message", "SUCCESS");
            out.put("data", positionList != null ? positionList : new JSONArray());
            return out;
        } catch (Exception e) {
            log.warn("Goodwill positions fetch error | clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject out = new JSONObject();
            out.put("status", false);
            out.put("message", e.getMessage());
            out.put("data", new JSONArray());
            return out;
        }
    }

    // ─── HOLDINGS ────────────────────────────────────────────────────────────
    public JSONObject getHoldings(GoodwillBaseRequest request) {
        log.info("Goodwill get holdings | clientId={}", request.getClientId());
        HttpHeaders headers = buildGoodwillHeaders(request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(HOLDINGS_URL, HttpMethod.GET, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject result = json.optJSONObject("result");
            JSONArray holdingsList = result != null ? result.optJSONArray("holdingList") : new JSONArray();

            JSONObject out = new JSONObject();
            out.put("status", true);
            out.put("message", "SUCCESS");
            out.put("data", holdingsList != null ? holdingsList : new JSONArray());
            return out;
        } catch (Exception e) {
            log.warn("Goodwill holdings fetch error | clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject out = new JSONObject();
            out.put("status", false);
            out.put("message", e.getMessage());
            out.put("data", new JSONArray());
            return out;
        }
    }

    // ─── ORDER HISTORY ───────────────────────────────────────────────────────
    public JSONObject getOrderBook(GoodwillBaseRequest request) {
        log.info("Goodwill get orders | clientId={}", request.getClientId());
        HttpHeaders headers = buildGoodwillHeaders(request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(ORDERS_URL, HttpMethod.GET, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject result = json.optJSONObject("result");
            JSONArray orderList = result != null ? result.optJSONArray("orderList") : new JSONArray();

            JSONObject out = new JSONObject();
            out.put("status", true);
            out.put("message", "SUCCESS");
            out.put("data", orderList != null ? orderList : new JSONArray());
            return out;
        } catch (Exception e) {
            log.warn("Goodwill orders fetch error | clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject out = new JSONObject();
            out.put("status", false);
            out.put("message", e.getMessage());
            out.put("data", new JSONArray());
            return out;
        }
    }
}
