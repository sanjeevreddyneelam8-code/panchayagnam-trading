package com.py.dhan.service;

import com.py.dhan.dto.*;
import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class DhanApiService {

    private static final Logger log = LoggerFactory.getLogger(DhanApiService.class);

    private static final String LOGIN_URL = "https://auth.dhan.co/app/generateAccessToken";
    private static final String API_URL = "https://api.dhan.co/v2";
    private static final String FUND_URL = API_URL + "/fundlimit";
    private static final String ORDER_URL = API_URL + "/orders";
    private static final String TRADES_URL = API_URL + "/trades";
    private static final String HOLDINGS_URL = API_URL + "/holdings";
    private static final String POSITIONS_URL = API_URL + "/positions";

    @Autowired
    private RestTemplate restTemplate;

    @Autowired
    private DhanHeaderService dhanHeaderService;

    // ── LOGIN ─────────────────────────────────────────────────────────────────
    public JSONObject login(DhanLoginRequest request) {
        log.info("Dhan login | clientId={}", request.getClientId());

        String url = LOGIN_URL
                + "?dhanClientId=" + request.getClientId()
                + "&pin=" + request.getMpin()
                + "&totp=" + request.getTotp();

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);

        ResponseEntity<String> response = restTemplate.postForEntity(
                url, new HttpEntity<>(headers), String.class);

        JSONObject json = new JSONObject(response.getBody());
        boolean hasToken = json.has("accessToken") && !json.optString("accessToken", "").isEmpty();
        log.info("Dhan login response received | clientId={} success={}", request.getClientId(), hasToken);

        if (!hasToken) {
            String errorMsg = json.optString("remarks", json.optString("message", "no accessToken in response"));
            throw new RuntimeException("Dhan login failed: " + errorMsg);
        }

        log.info("Dhan login SUCCESS | clientId={}", request.getClientId());
        return json;
    }

    // ── FUND LIMIT / RMS ──────────────────────────────────────────────────────
    public JSONObject getFundLimit(DhanBaseRequest request) {
        log.info("Dhan fund limit | clientId={}", request.getClientId());

        HttpHeaders headers = dhanHeaderService.buildHeaders(request.getAccessToken());
        HttpEntity<String> entity = new HttpEntity<>(headers);

        ResponseEntity<String> response = restTemplate.exchange(
                FUND_URL, HttpMethod.GET, entity, String.class);

        JSONObject json = new JSONObject(response.getBody());
        log.info("Dhan fund limit response | clientId={}: {}", request.getClientId(), json);

//        double available = json.optDouble("availabelBalance",
//                json.optDouble("availableBalance",
//                        json.optDouble("net", 0.0)));
//
//        JSONObject result = new JSONObject();
//        result.put("availablecash", String.valueOf(available));
        return json;
    }

    // ── PLACE ORDER ───────────────────────────────────────────────────────────
    public JSONObject placeOrder(DhanPlaceOrderRequest request) {
        log.info("Dhan place order | clientId={} exchange={} securityId={} side={}",
                request.getClientId(), request.getExchangeSegment(),
                request.getSecurityId(), request.getTransactionType());

        JSONObject body = new JSONObject();
        body.put("dhanClientId", request.getDhanClientId());
        body.put("correlationId", request.getCorrelationId());
        body.put("transactionType", request.getTransactionType());
        body.put("exchangeSegment", request.getExchangeSegment());
        body.put("productType", request.getProductType());
        body.put("orderType", request.getOrderType());
        body.put("validity", request.getValidity());
        body.put("securityId", request.getSecurityId());
        body.put("quantity", request.getQuantity());
        body.put("disclosedQuantity", 0);
        if (!request.getOrderType().equals("MARKET")) {
            body.put("price", request.getPrice() != null && request.getPrice() > 0
                    ? request.getPrice() : 0);
        }
        body.put("triggerPrice", request.getTriggerPrice() != null
                && request.getTriggerPrice() > 0 ? request.getTriggerPrice() : 0);
        body.put("afterMarketOrder", request.isAfterMarketOrder());
        body.put("amoTime", request.getAmoTime() != null ? request.getAmoTime() : null);

        HttpHeaders headers = dhanHeaderService.buildHeaders(request.getAccessToken());
        HttpEntity<String> entity = new HttpEntity<>(body.toString(), headers);

        ResponseEntity<String> response = restTemplate.postForEntity(
                ORDER_URL, entity, String.class);

        JSONObject json = new JSONObject(response.getBody());
        log.info("Dhan place order response | clientId={}: {}", request.getClientId(), json);

        if (!json.has("orderId")) {
            throw new RuntimeException("Dhan order failed — no orderId: " + json);
        }

        log.info("Dhan place order SUCCESS | clientId={} orderId={}",
                request.getClientId(), json.optString("orderId"));
        return json;
    }

    // ── MODIFY ORDER ──────────────────────────────────────────────────────────
    public JSONObject modifyOrder(DhanModifyOrderRequest request) {
        log.info("Dhan modify order | clientId={} orderId={}",
                request.getClientId(), request.getOrderId());

        JSONObject body = new JSONObject();
        body.put("dhanClientId", request.getDhanClientId());
        body.put("orderId", request.getOrderId());
        body.put("orderType", request.getOrderType());
        body.put("quantity", request.getQuantity());
        body.put("validity", request.getValidity());
        body.put("disclosedQuantity",
                request.getDisclosedQuantity() != null ? request.getDisclosedQuantity() : 0);

        String ot = request.getOrderType().toUpperCase();
        if (ot.equals("LIMIT") || ot.equals("STOP_LOSS")) {
            body.put("price", request.getPrice() != null && request.getPrice() > 0
                    ? request.getPrice() : 0.0);
        } else {
            body.put("price", "");
        }
        if (ot.equals("STOP_LOSS") || ot.equals("STOP_LOSS_MARKET")) {
            body.put("triggerPrice", request.getTriggerPrice() != null
                    && request.getTriggerPrice() > 0 ? request.getTriggerPrice() : 0.0);
        } else {
            body.put("triggerPrice", "");
        }

        HttpHeaders headers = dhanHeaderService.buildHeaders(request.getAccessToken());
        HttpEntity<String> entity = new HttpEntity<>(body.toString(), headers);

        ResponseEntity<String> response = restTemplate.exchange(
                ORDER_URL + "/" + request.getOrderId(),
                HttpMethod.PUT, entity, String.class);

        JSONObject json = new JSONObject(response.getBody());
        log.info("Dhan modify order response | clientId={} orderId={}: {}",
                request.getClientId(), request.getOrderId(), json);

        if (!json.has("orderId")) {
            throw new RuntimeException("Dhan modifyOrder failed — no orderId: " + json);
        }

        log.info("Dhan modify order SUCCESS | clientId={} orderId={}",
                request.getClientId(), json.optString("orderId"));
        return json;
    }

    // ── CANCEL ORDER ──────────────────────────────────────────────────────────
    public JSONObject cancelOrder(DhanCancelOrderRequest request) {
        log.info("Dhan cancel order | clientId={} orderId={}",
                request.getClientId(), request.getOrderId());

        HttpHeaders headers = dhanHeaderService.buildHeaders(request.getAccessToken());
        HttpEntity<String> entity = new HttpEntity<>(headers);

        ResponseEntity<String> response = restTemplate.exchange(
                ORDER_URL + "/" + request.getOrderId(),
                HttpMethod.DELETE, entity, String.class);

        int statusCode = response.getStatusCode().value();
        log.info("Dhan cancel order HTTP {} | clientId={} orderId={}",
                statusCode, request.getClientId(), request.getOrderId());

        if (statusCode == 200 || statusCode == 202) {
            String body = response.getBody();
            if (body != null && !body.isBlank()) {
                return new JSONObject(body);
            }
            JSONObject result = new JSONObject();
            result.put("orderId", request.getOrderId());
            result.put("orderStatus", "CANCELLED");
            return result;
        }

        JSONObject error = new JSONObject();
        error.put("orderId", request.getOrderId());
        error.put("orderStatus", "FAILED");
        error.put("httpStatus", statusCode);
        error.put("errorBody", response.getBody());
        log.error("Dhan cancel order FAILED | clientId={} orderId={} status={}",
                request.getClientId(), request.getOrderId(), statusCode);
        return error;
    }

    // ── ORDER HISTORY ─────────────────────────────────────────────────────────
    public JSONObject getOrderBook(DhanBaseRequest request) {
        log.info("Dhan order book | clientId={}", request.getClientId());

        HttpHeaders headers = dhanHeaderService.buildHeaders(request.getAccessToken());
        HttpEntity<String> entity = new HttpEntity<>(headers);

        ResponseEntity<String> response = restTemplate.exchange(
                ORDER_URL, HttpMethod.GET, entity, String.class);

        JSONObject result = new JSONObject();
        result.put("data", new JSONArray(response.getBody()));
        result.put("stat", "Ok");

        log.info("Dhan order book SUCCESS | clientId={}", request.getClientId());
        return result;
    }

    // ── HOLDINGS ──────────────────────────────────────────────────────────────
    public JSONObject getHoldings(DhanBaseRequest request) {
        log.info("Dhan holdings | clientId={}", request.getClientId());

        HttpHeaders headers = dhanHeaderService.buildHeaders(request.getAccessToken());
        HttpEntity<String> entity = new HttpEntity<>(headers);

        ResponseEntity<String> response = restTemplate.exchange(
                HOLDINGS_URL, HttpMethod.GET, entity, String.class);

        JSONObject result = new JSONObject();
        result.put("data", new JSONArray(response.getBody()));
        result.put("stat", "Ok");

        log.info("Dhan holdings SUCCESS | clientId={}", request.getClientId());
        return result;
    }

    // ── POSITIONS ─────────────────────────────────────────────────────────────
    public JSONObject getPositions(DhanBaseRequest request) {
        log.info("Dhan positions | clientId={}", request.getClientId());

        HttpHeaders headers = dhanHeaderService.buildHeaders(request.getAccessToken());
        HttpEntity<String> entity = new HttpEntity<>(headers);

        ResponseEntity<String> response = restTemplate.exchange(
                POSITIONS_URL, HttpMethod.GET, entity, String.class);

        JSONObject result = new JSONObject();
        result.put("data", new JSONArray(response.getBody()));
        result.put("stat", "Ok");

        log.info("Dhan positions SUCCESS | clientId={}", request.getClientId());
        return result;
    }

    // ── MAPPING HELPERS ───────────────────────────────────────────────────────
    public String toDhanExchange(String exchange) {
        return switch (exchange.toUpperCase()) {
            case "NSE" ->
                "NSE_EQ";
            case "BSE" ->
                "BSE_EQ";
            case "NFO" ->
                "NSE_FNO";
            case "BFO" ->
                "BSE_FNO";
            case "CDS" ->
                "NSE_CURRENCY";
            case "MCX" ->
                "MCX_COMM";
            default ->
                exchange;
        };
    }

    public String toDhanProductType(String productType) {
        return switch (productType.toUpperCase()) {
            case "DELIVERY", "CNC" ->
                "CNC";
            case "INTRADAY", "MIS" ->
                "INTRADAY";
            case "MARGIN" ->
                "MARGIN";
            case "CARRYFORWARD", "MTF" ->
                "MTF";
            default ->
                "INTRADAY";
        };
    }

    public String toDhanOrderType(String orderType) {
        return switch (orderType.toUpperCase()) {
            case "MARKET" ->
                "MARKET";
            case "LIMIT" ->
                "LIMIT";
            case "STOPLOSS_LIMIT", "SL" ->
                "STOP_LOSS";
            case "STOPLOSS_MARKET", "SL-M" ->
                "STOP_LOSS_MARKET";
            default ->
                "MARKET";
        };
    }
}
