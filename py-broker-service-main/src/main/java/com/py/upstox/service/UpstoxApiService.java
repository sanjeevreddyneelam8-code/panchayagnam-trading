package com.py.upstox.service;

import com.py.upstox.dto.*;
import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

/**
 * Service for official Upstox API v2.
 * Official Developer Documentation: https://upstox.com/developer/api-documentation/
 */
@Service
public class UpstoxApiService {

    private static final Logger log = LoggerFactory.getLogger(UpstoxApiService.class);

    private static final String UPSTOX_BASE_URL = "https://api.upstox.com/v2";
    private static final String TOKEN_URL = UPSTOX_BASE_URL + "/login/authorization/token";
    private static final String FUNDS_URL = UPSTOX_BASE_URL + "/user/get-funds-and-margin";
    private static final String PLACE_ORDER_URL = UPSTOX_BASE_URL + "/order/place";
    private static final String MODIFY_ORDER_URL = UPSTOX_BASE_URL + "/order/modify";
    private static final String CANCEL_ORDER_URL = UPSTOX_BASE_URL + "/order/cancel";
    private static final String POSITIONS_URL = UPSTOX_BASE_URL + "/portfolio/short-term-positions";
    private static final String HOLDINGS_URL = UPSTOX_BASE_URL + "/portfolio/long-term-holdings";
    private static final String ORDERS_URL = UPSTOX_BASE_URL + "/order/retrieve-all";

    @Autowired
    private RestTemplate restTemplate;

    private HttpHeaders buildUpstoxHeaders(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Accept", "application/json");
        if (accessToken != null && !accessToken.isBlank()) {
            headers.set("Authorization", "Bearer " + accessToken);
        }
        return headers;
    }

    // ─── LOGIN / CODE EXCHANGE ───────────────────────────────────────────────
    public JSONObject login(UpstoxLoginRequest request) {
        log.info("Upstox OAuth token exchange | clientId={}", request.getClientId());

        if (request.getCode() == null || request.getCode().isBlank()) {
            throw new RuntimeException("Upstox login requires an authorization code from the OAuth callback.");
        }

        // Support simulated paper testing when authorization code has SIM- or PAPER- prefix
        if (request.getCode().startsWith("SIM-") || request.getCode().startsWith("PAPER-")) {
            log.info("🛡️ [PAPER TRADING] Upstox token exchange simulated for clientId={}", request.getClientId());
            JSONObject result = new JSONObject();
            result.put("status", true);
            result.put("message", "SUCCESS");
            result.put("accessToken", "PAPER-UPSTOX-ACCESS-" + System.currentTimeMillis());
            result.put("userId", request.getClientId());
            result.put("userName", "Upstox Trader");
            return result;
        }

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        headers.set("Accept", "application/json");

        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("code", request.getCode());
        body.add("client_id", request.getApiKey());
        body.add("client_secret", request.getApiSecret());
        body.add("redirect_uri", request.getRedirectUri());
        body.add("grant_type", "authorization_code");

        HttpEntity<MultiValueMap<String, String>> entity = new HttpEntity<>(body, headers);

        try {
            ResponseEntity<String> response = restTemplate.postForEntity(TOKEN_URL, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            if (json.has("access_token")) {
                String token = json.getString("access_token");
                JSONObject result = new JSONObject();
                result.put("status", true);
                result.put("message", "SUCCESS");
                result.put("accessToken", token);
                result.put("userId", json.optString("user_id", request.getClientId()));
                result.put("userName", json.optString("user_name", "Upstox User"));
                log.info("Upstox token exchange SUCCESS | userId={}", result.optString("userId"));
                return result;
            } else {
                throw new RuntimeException("Upstox token exchange failed: " + json.optString("message", "no token in response"));
            }
        } catch (Exception e) {
            log.error("Upstox login failed for clientId={}: {}", request.getClientId(), e.getMessage());
            throw new RuntimeException("Upstox login failed: " + e.getMessage(), e);
        }
    }

    // ─── FUNDS / RMS ─────────────────────────────────────────────────────────
    public JSONObject getFunds(UpstoxBaseRequest request) {
        log.info("Upstox fetch funds | clientId={}", request.getClientId());
        HttpHeaders headers = buildUpstoxHeaders(request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(FUNDS_URL, HttpMethod.GET, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject data = json.optJSONObject("data");
            JSONObject equity = data != null ? data.optJSONObject("equity") : null;
            double availableMargin = equity != null ? equity.optDouble("available_margin", 0.0) : 0.0;

            JSONObject result = new JSONObject();
            result.put("status", true);
            result.put("availablecash", String.valueOf(availableMargin));
            result.put("data", data);
            return result;
        } catch (Exception e) {
            log.warn("Upstox funds fetch error for clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject fallback = new JSONObject();
            fallback.put("status", false);
            fallback.put("availablecash", "0.0");
            fallback.put("error", e.getMessage());
            return fallback;
        }
    }

    // ─── PLACE ORDER ─────────────────────────────────────────────────────────
    public JSONObject placeOrder(UpstoxPlaceOrderRequest request) {
        log.info("Upstox place order | clientId={} instrument={} side={}",
                request.getClientId(), request.getInstrumentToken(), request.getTransactionType());

        HttpHeaders headers = buildUpstoxHeaders(request.getAccessToken());
        headers.setContentType(MediaType.APPLICATION_JSON);

        JSONObject body = new JSONObject();
        body.put("quantity", request.getQuantity());
        body.put("product", request.getProduct());
        body.put("validity", request.getValidity() != null ? request.getValidity() : "DAY");
        body.put("price", request.getPrice() != null ? request.getPrice() : 0.0);
        body.put("tag", request.getTag() != null ? request.getTag() : "panchayagnam");
        body.put("instrument_token", request.getInstrumentToken());
        body.put("order_type", request.getOrderType());
        body.put("transaction_type", request.getTransactionType());
        body.put("disclosed_quantity", request.getDisclosedQuantity() != null ? request.getDisclosedQuantity() : 0);
        body.put("trigger_price", request.getTriggerPrice() != null ? request.getTriggerPrice() : 0.0);
        body.put("is_amo", request.getIsAmo() != null && request.getIsAmo());

        HttpEntity<String> entity = new HttpEntity<>(body.toString(), headers);

        try {
            ResponseEntity<String> response = restTemplate.postForEntity(PLACE_ORDER_URL, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject data = json.optJSONObject("data");
            String orderId = data != null ? data.optString("order_id", "") : json.optString("order_id", "");
            JSONObject result = new JSONObject();
            result.put("status", true);
            result.put("orderId", orderId);
            result.put("message", "Upstox order placed successfully");
            return result;
        } catch (Exception e) {
            log.error("Upstox place order error | clientId={}: {}", request.getClientId(), e.getMessage());
            throw new RuntimeException("Upstox place order failed: " + e.getMessage(), e);
        }
    }

    // ─── MODIFY ORDER ────────────────────────────────────────────────────────
    public JSONObject modifyOrder(UpstoxModifyOrderRequest request) {
        log.info("Upstox modify order | clientId={} orderId={}", request.getClientId(), request.getOrderId());

        HttpHeaders headers = buildUpstoxHeaders(request.getAccessToken());
        headers.setContentType(MediaType.APPLICATION_JSON);

        JSONObject body = new JSONObject();
        body.put("order_id", request.getOrderId());
        if (request.getQuantity() != null && request.getQuantity() > 0) {
            body.put("quantity", request.getQuantity());
        }
        if (request.getPrice() != null && request.getPrice() > 0) {
            body.put("price", request.getPrice());
        }
        if (request.getTriggerPrice() != null && request.getTriggerPrice() > 0) {
            body.put("trigger_price", request.getTriggerPrice());
        }
        if (request.getOrderType() != null) {
            body.put("order_type", request.getOrderType());
        }
        if (request.getValidity() != null) {
            body.put("validity", request.getValidity());
        }

        HttpEntity<String> entity = new HttpEntity<>(body.toString(), headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(MODIFY_ORDER_URL, HttpMethod.PUT, entity, String.class);
            return new JSONObject(response.getBody());
        } catch (Exception e) {
            log.error("Upstox modify order error | orderId={}: {}", request.getOrderId(), e.getMessage());
            throw new RuntimeException("Upstox modify order failed: " + e.getMessage(), e);
        }
    }

    // ─── CANCEL ORDER ────────────────────────────────────────────────────────
    public JSONObject cancelOrder(UpstoxCancelOrderRequest request) {
        log.info("Upstox cancel order | clientId={} orderId={}", request.getClientId(), request.getOrderId());
        String url = CANCEL_ORDER_URL + "?order_id=" + request.getOrderId();

        HttpHeaders headers = buildUpstoxHeaders(request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.DELETE, entity, String.class);
            return new JSONObject(response.getBody());
        } catch (Exception e) {
            log.error("Upstox cancel order error | orderId={}: {}", request.getOrderId(), e.getMessage());
            throw new RuntimeException("Upstox cancel order failed: " + e.getMessage(), e);
        }
    }

    // ─── POSITIONS ───────────────────────────────────────────────────────────
    public JSONObject getPositions(UpstoxBaseRequest request) {
        log.info("Upstox get positions | clientId={}", request.getClientId());
        HttpHeaders headers = buildUpstoxHeaders(request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(POSITIONS_URL, HttpMethod.GET, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONArray data = json.optJSONArray("data");

            JSONObject result = new JSONObject();
            result.put("status", true);
            result.put("message", "SUCCESS");
            result.put("data", data != null ? data : new JSONArray());
            return result;
        } catch (Exception e) {
            log.warn("Upstox positions fetch error | clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject result = new JSONObject();
            result.put("status", false);
            result.put("message", e.getMessage());
            result.put("data", new JSONArray());
            return result;
        }
    }

    // ─── HOLDINGS ────────────────────────────────────────────────────────────
    public JSONObject getHoldings(UpstoxBaseRequest request) {
        log.info("Upstox get holdings | clientId={}", request.getClientId());
        HttpHeaders headers = buildUpstoxHeaders(request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(HOLDINGS_URL, HttpMethod.GET, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONArray data = json.optJSONArray("data");

            JSONObject result = new JSONObject();
            result.put("status", true);
            result.put("message", "SUCCESS");
            result.put("data", data != null ? data : new JSONArray());
            return result;
        } catch (Exception e) {
            log.warn("Upstox holdings fetch error | clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject result = new JSONObject();
            result.put("status", false);
            result.put("message", e.getMessage());
            result.put("data", new JSONArray());
            return result;
        }
    }

    // ─── ORDER HISTORY ───────────────────────────────────────────────────────
    public JSONObject getOrderBook(UpstoxBaseRequest request) {
        log.info("Upstox get orders | clientId={}", request.getClientId());
        HttpHeaders headers = buildUpstoxHeaders(request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(ORDERS_URL, HttpMethod.GET, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONArray data = json.optJSONArray("data");

            JSONObject result = new JSONObject();
            result.put("status", true);
            result.put("message", "SUCCESS");
            result.put("data", data != null ? data : new JSONArray());
            return result;
        } catch (Exception e) {
            log.warn("Upstox orders fetch error | clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject result = new JSONObject();
            result.put("status", false);
            result.put("message", e.getMessage());
            result.put("data", new JSONArray());
            return result;
        }
    }
}
