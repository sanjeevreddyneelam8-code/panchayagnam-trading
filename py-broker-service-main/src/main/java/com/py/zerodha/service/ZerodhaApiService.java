package com.py.zerodha.service;

import com.py.zerodha.dto.*;
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

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;

/**
 * Service for official Zerodha Kite Connect v3 API.
 * Official Developer Documentation: https://kite.trade/docs/connect/v3/
 */
@Service
public class ZerodhaApiService {

    private static final Logger log = LoggerFactory.getLogger(ZerodhaApiService.class);

    private static final String KITE_BASE_URL = "https://api.kite.trade";
    private static final String TOKEN_URL = KITE_BASE_URL + "/session/token";
    private static final String MARGINS_URL = KITE_BASE_URL + "/user/margins";
    private static final String ORDERS_URL = KITE_BASE_URL + "/orders/regular";
    private static final String POSITIONS_URL = KITE_BASE_URL + "/portfolio/positions";
    private static final String HOLDINGS_URL = KITE_BASE_URL + "/portfolio/holdings";
    private static final String ALL_ORDERS_URL = KITE_BASE_URL + "/orders";

    @Autowired
    private RestTemplate restTemplate;

    private HttpHeaders buildKiteHeaders(String apiKey, String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.set("X-Kite-Version", "3");
        if (apiKey != null && accessToken != null) {
            headers.set("Authorization", "token " + apiKey + ":" + accessToken);
        }
        return headers;
    }

    private String calculateChecksum(String apiKey, String requestToken, String apiSecret) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            String raw = apiKey + requestToken + apiSecret;
            byte[] digest = md.digest(raw.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (Exception e) {
            throw new RuntimeException("Failed to calculate Kite checksum: " + e.getMessage(), e);
        }
    }

    // ─── LOGIN / TOKEN EXCHANGE ──────────────────────────────────────────────
    public JSONObject login(ZerodhaLoginRequest request) {
        log.info("Zerodha Kite token exchange | clientId={}", request.getClientId());

        if (request.getRequestToken() == null || request.getRequestToken().isBlank()) {
            throw new RuntimeException("Zerodha login requires a valid request_token from Kite redirect.");
        }

        // Support simulated paper testing when request token has SIM- or PAPER- prefix
        if (request.getRequestToken().startsWith("SIM-") || request.getRequestToken().startsWith("PAPER-")) {
            log.info("🛡️ [PAPER TRADING] Kite token exchange simulated for clientId={}", request.getClientId());
            JSONObject result = new JSONObject();
            result.put("status", true);
            result.put("message", "SUCCESS");
            result.put("accessToken", "PAPER-KITE-ACCESS-" + System.currentTimeMillis());
            result.put("userId", request.getClientId());
            result.put("userName", "Zerodha Trader");
            return result;
        }

        if (request.getApiKey() == null || request.getApiSecret() == null) {
            throw new RuntimeException("Kite API Key and API Secret are required.");
        }

        String checksum = calculateChecksum(request.getApiKey(), request.getRequestToken(), request.getApiSecret());

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        headers.set("X-Kite-Version", "3");

        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("api_key", request.getApiKey());
        body.add("request_token", request.getRequestToken());
        body.add("checksum", checksum);

        HttpEntity<MultiValueMap<String, String>> entity = new HttpEntity<>(body, headers);

        try {
            ResponseEntity<String> response = restTemplate.postForEntity(TOKEN_URL, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject data = json.optJSONObject("data");
            if (data != null && data.has("access_token")) {
                String token = data.getString("access_token");
                JSONObject result = new JSONObject();
                result.put("status", true);
                result.put("message", "SUCCESS");
                result.put("accessToken", token);
                result.put("userId", data.optString("user_id"));
                result.put("userName", data.optString("user_name"));
                log.info("Zerodha Kite token exchange SUCCESS | userId={}", data.optString("user_id"));
                return result;
            } else {
                throw new RuntimeException("Kite token exchange failed: " + json.optString("message", "no token in response"));
            }
        } catch (Exception e) {
            log.error("Zerodha login failed for clientId={}: {}", request.getClientId(), e.getMessage());
            throw new RuntimeException("Zerodha Kite login failed: " + e.getMessage(), e);
        }
    }

    // ─── MARGINS / RMS ───────────────────────────────────────────────────────
    public JSONObject getMargins(ZerodhaBaseRequest request) {
        log.info("Zerodha fetch margins | clientId={}", request.getClientId());
        HttpHeaders headers = buildKiteHeaders(request.getApiKey(), request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(MARGINS_URL, HttpMethod.GET, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject data = json.optJSONObject("data");
            if (data != null) {
                JSONObject equity = data.optJSONObject("equity");
                double availableCash = equity != null ? equity.optDouble("net", 0.0) : 0.0;
                JSONObject result = new JSONObject();
                result.put("status", true);
                result.put("availablecash", String.valueOf(availableCash));
                result.put("data", data);
                return result;
            }
            return json;
        } catch (Exception e) {
            log.warn("Zerodha margins fetch failed for clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject fallback = new JSONObject();
            fallback.put("status", false);
            fallback.put("availablecash", "0.0");
            fallback.put("error", e.getMessage());
            return fallback;
        }
    }

    // ─── PLACE ORDER ─────────────────────────────────────────────────────────
    public JSONObject placeOrder(ZerodhaPlaceOrderRequest request) {
        log.info("Zerodha place order | clientId={} symbol={} side={}",
                request.getClientId(), request.getTradingsymbol(), request.getTransactionType());

        HttpHeaders headers = buildKiteHeaders(request.getApiKey(), request.getAccessToken());
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("exchange", request.getExchange());
        body.add("tradingsymbol", request.getTradingsymbol());
        body.add("transaction_type", request.getTransactionType());
        body.add("order_type", request.getOrderType());
        body.add("quantity", String.valueOf(request.getQuantity()));
        body.add("product", request.getProduct());
        body.add("validity", request.getValidity() != null ? request.getValidity() : "DAY");
        if (request.getPrice() != null && request.getPrice() > 0) {
            body.add("price", String.valueOf(request.getPrice()));
        }
        if (request.getTriggerPrice() != null && request.getTriggerPrice() > 0) {
            body.add("trigger_price", String.valueOf(request.getTriggerPrice()));
        }
        if (request.getTag() != null && !request.getTag().isBlank()) {
            body.add("tag", request.getTag());
        }

        HttpEntity<MultiValueMap<String, String>> entity = new HttpEntity<>(body, headers);

        try {
            ResponseEntity<String> response = restTemplate.postForEntity(ORDERS_URL, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject data = json.optJSONObject("data");
            String orderId = data != null ? data.optString("order_id", "") : json.optString("order_id", "");
            JSONObject result = new JSONObject();
            result.put("status", true);
            result.put("orderId", orderId);
            result.put("message", "Order placed successfully");
            return result;
        } catch (Exception e) {
            log.error("Zerodha place order error | clientId={}: {}", request.getClientId(), e.getMessage());
            throw new RuntimeException("Zerodha place order failed: " + e.getMessage(), e);
        }
    }

    // ─── MODIFY ORDER ────────────────────────────────────────────────────────
    public JSONObject modifyOrder(ZerodhaModifyOrderRequest request) {
        log.info("Zerodha modify order | clientId={} orderId={}", request.getClientId(), request.getOrderId());
        String url = ORDERS_URL + "/" + request.getOrderId();

        HttpHeaders headers = buildKiteHeaders(request.getApiKey(), request.getAccessToken());
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        if (request.getQuantity() != null && request.getQuantity() > 0) {
            body.add("quantity", String.valueOf(request.getQuantity()));
        }
        if (request.getPrice() != null && request.getPrice() > 0) {
            body.add("price", String.valueOf(request.getPrice()));
        }
        if (request.getTriggerPrice() != null && request.getTriggerPrice() > 0) {
            body.add("trigger_price", String.valueOf(request.getTriggerPrice()));
        }
        if (request.getOrderType() != null) {
            body.add("order_type", request.getOrderType());
        }
        if (request.getValidity() != null) {
            body.add("validity", request.getValidity());
        }

        HttpEntity<MultiValueMap<String, String>> entity = new HttpEntity<>(body, headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.PUT, entity, String.class);
            return new JSONObject(response.getBody());
        } catch (Exception e) {
            log.error("Zerodha modify order error | orderId={}: {}", request.getOrderId(), e.getMessage());
            throw new RuntimeException("Zerodha modify order failed: " + e.getMessage(), e);
        }
    }

    // ─── CANCEL ORDER ────────────────────────────────────────────────────────
    public JSONObject cancelOrder(ZerodhaCancelOrderRequest request) {
        log.info("Zerodha cancel order | clientId={} orderId={}", request.getClientId(), request.getOrderId());
        String url = ORDERS_URL + "/" + request.getOrderId();
        if (request.getVariety() != null && !request.getVariety().isBlank()) {
            url += "?variety=" + request.getVariety();
        }

        HttpHeaders headers = buildKiteHeaders(request.getApiKey(), request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.DELETE, entity, String.class);
            return new JSONObject(response.getBody());
        } catch (Exception e) {
            log.error("Zerodha cancel order error | orderId={}: {}", request.getOrderId(), e.getMessage());
            throw new RuntimeException("Zerodha cancel order failed: " + e.getMessage(), e);
        }
    }

    // ─── POSITIONS ───────────────────────────────────────────────────────────
    public JSONObject getPositions(ZerodhaBaseRequest request) {
        log.info("Zerodha get positions | clientId={}", request.getClientId());
        HttpHeaders headers = buildKiteHeaders(request.getApiKey(), request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(POSITIONS_URL, HttpMethod.GET, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONObject data = json.optJSONObject("data");
            JSONArray netPositions = data != null ? data.optJSONArray("net") : new JSONArray();

            JSONObject result = new JSONObject();
            result.put("status", true);
            result.put("message", "SUCCESS");
            result.put("data", netPositions != null ? netPositions : new JSONArray());
            return result;
        } catch (Exception e) {
            log.warn("Zerodha positions fetch error | clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject result = new JSONObject();
            result.put("status", false);
            result.put("message", e.getMessage());
            result.put("data", new JSONArray());
            return result;
        }
    }

    // ─── HOLDINGS ────────────────────────────────────────────────────────────
    public JSONObject getHoldings(ZerodhaBaseRequest request) {
        log.info("Zerodha get holdings | clientId={}", request.getClientId());
        HttpHeaders headers = buildKiteHeaders(request.getApiKey(), request.getAccessToken());
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
            log.warn("Zerodha holdings fetch error | clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject result = new JSONObject();
            result.put("status", false);
            result.put("message", e.getMessage());
            result.put("data", new JSONArray());
            return result;
        }
    }

    // ─── ORDER HISTORY ───────────────────────────────────────────────────────
    public JSONObject getOrderBook(ZerodhaBaseRequest request) {
        log.info("Zerodha get orders | clientId={}", request.getClientId());
        HttpHeaders headers = buildKiteHeaders(request.getApiKey(), request.getAccessToken());
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(ALL_ORDERS_URL, HttpMethod.GET, entity, String.class);
            JSONObject json = new JSONObject(response.getBody());
            JSONArray data = json.optJSONArray("data");

            JSONObject result = new JSONObject();
            result.put("status", true);
            result.put("message", "SUCCESS");
            result.put("data", data != null ? data : new JSONArray());
            return result;
        } catch (Exception e) {
            log.warn("Zerodha orders fetch error | clientId={}: {}", request.getClientId(), e.getMessage());
            JSONObject result = new JSONObject();
            result.put("status", false);
            result.put("message", e.getMessage());
            result.put("data", new JSONArray());
            return result;
        }
    }
}
