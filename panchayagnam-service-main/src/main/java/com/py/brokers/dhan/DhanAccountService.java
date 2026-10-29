package com.py.brokers.dhan;

import com.py.brokers.angel.dto.User;
import com.py.brokers.dhan.dto.DhanConvertPositionParams;
import com.py.brokers.dhan.dto.DhanModifyOrderParams;
import com.py.brokers.dhan.dto.DhanOrderParams;
import java.io.BufferedReader;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.URL;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

/**
 * Dhan Broker API Service
 *
 * Supported APIs:
 *  - Login
 *  - Fund Limit (RMS)
 *  - Place Order          POST   /orders
 *  - Modify Order         PUT    /orders/{orderId}
 *  - Cancel Order         DELETE /orders/{orderId}
 *  - Order Book           GET    /orders
 *  - Get Order By ID      GET    /orders/{orderId}
 *  - Trade Book           GET    /trades
 *  - Holdings             GET    /holdings
 *  - Positions            GET    /positions
 *  - Convert Position     POST   /positions/convert
 *  - Exit All Positions   DELETE /positions
 */
@Service
public class DhanAccountService {

    private static final Logger log = LoggerFactory.getLogger(DhanAccountService.class);

    private static final String LOGIN_URL     = "https://auth.dhan.co/app/generateAccessToken";
    private static final String API_URL       = "https://api.dhan.co/v2";
    private static final String FUND_URL      = API_URL + "/fundlimit";
    private static final String ORDER_URL     = API_URL + "/orders";
    private static final String TRADES_URL    = API_URL + "/trades";
    private static final String HOLDINGS_URL  = API_URL + "/holdings";
    private static final String POSITIONS_URL = API_URL + "/positions";

    private final HttpClient httpClient = HttpClient.newHttpClient();

    // ── LOGIN ────────────────────────────────────────────────────────────────
    public JSONObject login(String clientId, String mpin, String totp) {
        try {
            log.info("Dhan login attempt for clientId={}", clientId);

            String url = LOGIN_URL
                    + "?dhanClientId=" + clientId
                    + "&pin=" + mpin
                    + "&totp=" + totp;

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.noBody())
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            JSONObject json = new JSONObject(response.body());

            log.info("Dhan login response received for clientId={}: hasAccessToken={}", clientId, json.has("accessToken"));

            if (!json.has("accessToken") || json.optString("accessToken", "").isEmpty()) {
                throw new RuntimeException("Dhan login failed — no accessToken in response for clientId=" + clientId);
            }

            log.info("Dhan login SUCCESS for clientId={}", clientId);
            return json;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException("Dhan login HTTP error: " + e.getMessage(), e);
        }
    }

    // ── PROFILE ──────────────────────────────────────────────────────────────
    public User buildUserFromLoginResponse(JSONObject loginData) {
        User user = new User();
        user.setUserId(loginData.optString("dhanClientId", ""));
        user.setUserName(loginData.optString("dhanClientName", ""));
        user.setBrokerName("DHAN");
        user.setEmail("");
        user.setMobileNo("");
        return user;
    }

    // ── FUND LIMIT / RMS ─────────────────────────────────────────────────────
    /**
     * GET /fundlimit
     * Normalizes to "availablecash" key to match existing broker RMS convention.
     * Note: Dhan response key is "availabelBalance" (their typo).
     */
    public JSONObject getFundLimit(String clientId, String accessToken) {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(FUND_URL))
                    .header("access-token", accessToken)
                    .header("Content-Type", "application/json")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            JSONObject json = new JSONObject(response.body());

            log.info("Dhan fundlimit response for clientId={}: {}", clientId, json);

            double available = json.optDouble("availabelBalance",
                    json.optDouble("availableBalance",
                            json.optDouble("net", 0.0)));

            JSONObject result = new JSONObject();
            result.put("availablecash", String.valueOf(available));
            return result;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("Dhan fundlimit HTTP error for clientId={}: {}", clientId, e.getMessage());
            return new JSONObject();
        }
    }

    // ── PLACE ORDER ──────────────────────────────────────────────────────────
    /**
     * POST /orders
     * Response: { "orderId": "112111182198", "orderStatus": "PENDING" }
     */
    public JSONObject placeOrder(DhanOrderParams params, String accessToken) {
        try {
            JSONObject body = buildOrderBody(params);
            log.info("Dhan placeOrder request for clientId={}: {}", params.getDhanClientId(), body);

            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(new URL("https://api.ipify.org").openStream()))) {
                String ip = reader.readLine();
                System.out.println("Outgoing IP: " + ip);
            }

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(ORDER_URL))
                    .header("Content-Type", "application/json")
                    .header("access-token", accessToken)
                    .POST(HttpRequest.BodyPublishers.ofString(body.toString()))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            JSONObject json = new JSONObject(response.body());

            log.info("Dhan placeOrder response for clientId={}: {}", params.getDhanClientId(), json);

            if (!json.has("orderId")) {
                throw new RuntimeException("Dhan order failed — no orderId in response: " + json);
            }

            return json;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException("Dhan placeOrder HTTP error: " + e.getMessage(), e);
        }
    }

    // ── MODIFY ORDER ─────────────────────────────────────────────────────────
    /**
     * PUT /orders/{orderId}
     * Modifies price, quantity, orderType, or validity of a pending order.
     * Response: { "orderId": "112111182045", "orderStatus": "TRANSIT" }
     */
    public JSONObject modifyOrder(DhanModifyOrderParams params, String accessToken) {
        try {
            JSONObject body = buildModifyOrderBody(params);
            log.info("Dhan modifyOrder request for clientId={} orderId={}: {}",
                    params.getDhanClientId(), params.getOrderId(), body);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(ORDER_URL + "/" + params.getOrderId()))
                    .header("Content-Type", "application/json")
                    .header("access-token", accessToken)
                    .PUT(HttpRequest.BodyPublishers.ofString(body.toString()))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            JSONObject json = new JSONObject(response.body());

            log.info("Dhan modifyOrder response for clientId={} orderId={}: {}",
                    params.getDhanClientId(), params.getOrderId(), json);

            if (!json.has("orderId")) {
                throw new RuntimeException("Dhan modifyOrder failed — no orderId in response: " + json);
            }

            return json;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException("Dhan modifyOrder HTTP error: " + e.getMessage(), e);
        }
    }

    // ── CANCEL ORDER ─────────────────────────────────────────────────────────
    /**
     * DELETE /orders/{orderId}
     * Cancels a pending order. No request body.
     * Success HTTP: 202 Accepted
     * Response: { "orderId": "112111182045", "orderStatus": "CANCELLED" }
     */
    public JSONObject cancelOrder(String clientId, String orderId, String accessToken) {
        try {
            log.info("Dhan cancelOrder request for clientId={} orderId={}", clientId, orderId);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(ORDER_URL + "/" + orderId))
                    .header("Content-Type", "application/json")
                    .header("access-token", accessToken)
                    .DELETE()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            int statusCode = response.statusCode();

            log.info("Dhan cancelOrder HTTP {} for clientId={} orderId={} body={}",
                    statusCode, clientId, orderId, response.body());

            if (statusCode == 202 || statusCode == 200) {
                String body = response.body();
                if (body != null && !body.isBlank()) {
                    return new JSONObject(body);
                }
                JSONObject result = new JSONObject();
                result.put("orderId", orderId);
                result.put("orderStatus", "CANCELLED");
                return result;
            }

            JSONObject error = new JSONObject();
            error.put("orderId", orderId);
            error.put("orderStatus", "FAILED");
            error.put("httpStatus", statusCode);
            error.put("errorBody", response.body());
            log.error("Dhan cancelOrder FAILED for clientId={} orderId={} status={}: {}",
                    clientId, orderId, statusCode, response.body());
            return error;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException("Dhan cancelOrder HTTP error: " + e.getMessage(), e);
        }
    }

    // ── ORDER BOOK ───────────────────────────────────────────────────────────
    /**
     * GET /orders
     * All orders for the day. Fields include orderId, orderStatus,
     * transactionType, exchangeSegment, productType, orderType, validity,
     * tradingSymbol, securityId, quantity, price, triggerPrice, createTime,
     * updateTime, remainingQuantity, averageTradedPrice, filledQty etc.
     */
    public JSONObject getOrderBook(String clientId, String accessToken) {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(ORDER_URL))
                    .header("Content-Type", "application/json")
                    .header("access-token", accessToken)
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            log.info("Dhan getOrderBook response for clientId={}", clientId);

            JSONObject result = new JSONObject();
            result.put("data", new org.json.JSONArray(response.body()));
            result.put("stat", "Ok");
            return result;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("Dhan getOrderBook HTTP error for clientId={}: {}", clientId, e.getMessage());
            return new JSONObject();
        }
    }

    // ── GET ORDER BY ID ──────────────────────────────────────────────────────
    /**
     * GET /orders/{orderId}
     */
    public JSONObject getOrderById(String clientId, String accessToken, String orderId) {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(ORDER_URL + "/" + orderId))
                    .header("Content-Type", "application/json")
                    .header("access-token", accessToken)
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            log.info("Dhan getOrderById response for clientId={} orderId={}", clientId, orderId);

            JSONObject result = new JSONObject();
            result.put("data", new org.json.JSONArray(response.body()));
            result.put("stat", "Ok");
            return result;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("Dhan getOrderById HTTP error for clientId={}: {}", clientId, e.getMessage());
            return new JSONObject();
        }
    }

    // ── TRADE BOOK ───────────────────────────────────────────────────────────
    /**
     * GET /trades
     * All trades executed for the day.
     */
    public JSONObject getTradeBook(String clientId, String accessToken) {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(TRADES_URL))
                    .header("Content-Type", "application/json")
                    .header("access-token", accessToken)
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            log.info("Dhan getTradeBook response for clientId={}", clientId);

            JSONObject result = new JSONObject();
            result.put("data", new org.json.JSONArray(response.body()));
            result.put("stat", "Ok");
            return result;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("Dhan getTradeBook HTTP error for clientId={}: {}", clientId, e.getMessage());
            return new JSONObject();
        }
    }

    // ── HOLDINGS ─────────────────────────────────────────────────────────────
    /**
     * GET /holdings
     * Holdings from previous trading sessions (T1 + delivered quantities).
     * Response fields: exchange, tradingSymbol, securityId, isin,
     * totalQty, dpQty, t1Qty, availableQty, collateralQty, avgCostPrice.
     */
    public JSONObject getHoldings(String clientId, String accessToken) {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(HOLDINGS_URL))
                    .header("Content-Type", "application/json")
                    .header("access-token", accessToken)
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            log.info("Dhan getHoldings response for clientId={}", clientId);

            JSONObject result = new JSONObject();
            result.put("data", new org.json.JSONArray(response.body()));
            result.put("stat", "Ok");
            return result;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("Dhan getHoldings HTTP error for clientId={}: {}", clientId, e.getMessage());
            return new JSONObject();
        }
    }

    // ── POSITIONS ────────────────────────────────────────────────────────────
    /**
     * GET /positions
     * All open positions for the day including F&O carryforward.
     * Response fields: dhanClientId, tradingSymbol, securityId, positionType,
     * exchangeSegment, productType, buyAvg, buyQty, costPrice, sellAvg,
     * sellQty, netQty, realizedProfit, unrealizedProfit, carryForwardBuyQty,
     * carryForwardSellQty, dayBuyQty, daySellQty, drvExpiryDate,
     * drvOptionType, drvStrikePrice, crossCurrency.
     */
    public JSONObject getPositions(String clientId, String accessToken) {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(POSITIONS_URL))
                    .header("Content-Type", "application/json")
                    .header("access-token", accessToken)
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            log.info("Dhan getPositions response for clientId={}", clientId);

            JSONObject result = new JSONObject();
            result.put("data", new org.json.JSONArray(response.body()));
            result.put("stat", "Ok");
            return result;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("Dhan getPositions HTTP error for clientId={}: {}", clientId, e.getMessage());
            return new JSONObject();
        }
    }

    // ── CONVERT POSITION ─────────────────────────────────────────────────────
    /**
     * POST /positions/convert
     * Converts open position between product types: INTRADAY <-> CNC / MARGIN.
     * Success HTTP: 202 Accepted (empty body) → synthetic { status: SUCCESS }.
     */
    public JSONObject convertPosition(DhanConvertPositionParams params, String accessToken) {
        try {
            JSONObject body = buildConvertPositionBody(params);
            log.info("Dhan convertPosition request for clientId={} securityId={} {}->{}:{} ",
                    params.getDhanClientId(), params.getSecurityId(),
                    params.getFromProductType(), params.getToProductType(), body);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(POSITIONS_URL + "/convert"))
                    .header("Content-Type", "application/json")
                    .header("Accept", "application/json")
                    .header("access-token", accessToken)
                    .POST(HttpRequest.BodyPublishers.ofString(body.toString()))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            int statusCode = response.statusCode();

            log.info("Dhan convertPosition HTTP {} for clientId={} securityId={}",
                    statusCode, params.getDhanClientId(), params.getSecurityId());

            if (statusCode == 202 || statusCode == 200) {
                String responseBody = response.body();
                if (responseBody != null && !responseBody.isBlank()) {
                    return new JSONObject(responseBody);
                }
                // Dhan returns 202 with empty body on success
                JSONObject result = new JSONObject();
                result.put("status", "SUCCESS");
                result.put("message", "Position converted successfully");
                return result;
            }

            JSONObject error = new JSONObject();
            error.put("status", "ERROR");
            error.put("httpStatus", statusCode);
            error.put("errorBody", response.body());
            log.error("Dhan convertPosition FAILED for clientId={} status={}: {}",
                    params.getDhanClientId(), statusCode, response.body());
            return error;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException("Dhan convertPosition HTTP error: " + e.getMessage(), e);
        }
    }

    // ── EXIT ALL POSITIONS ───────────────────────────────────────────────────
    /**
     * DELETE /positions
     * Squares off ALL open positions for the current trading day.
     * NOTE: Does NOT cancel pending orders — only closes open positions.
     * Response: { "status": "SUCCESS", "message": "All orders and positions exited successfully" }
     */
    public JSONObject exitAllPositions(String clientId, String accessToken) {
        try {
            log.info("Dhan exitAllPositions request for clientId={}", clientId);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(POSITIONS_URL))
                    .header("Accept", "application/json")
                    .header("access-token", accessToken)
                    .DELETE()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            int statusCode = response.statusCode();
            String responseBody = response.body();

            log.info("Dhan exitAllPositions HTTP {} for clientId={} body={}",
                    statusCode, clientId, responseBody);

            if (statusCode == 200 || statusCode == 202) {
                if (responseBody != null && !responseBody.isBlank()) {
                    return new JSONObject(responseBody);
                }
                JSONObject result = new JSONObject();
                result.put("status", "SUCCESS");
                result.put("message", "All orders and positions exited successfully");
                return result;
            }

            JSONObject error = new JSONObject();
            error.put("status", "ERROR");
            error.put("httpStatus", statusCode);
            error.put("errorBody", responseBody);
            log.error("Dhan exitAllPositions FAILED for clientId={} status={}: {}",
                    clientId, statusCode, responseBody);
            return error;

        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException("Dhan exitAllPositions HTTP error: " + e.getMessage(), e);
        }
    }

    // ── MAPPING HELPERS ──────────────────────────────────────────────────────
    public String toDhanExchange(String exchange) {
        return switch (exchange.toUpperCase()) {
            case "NSE"  -> "NSE_EQ";
            case "BSE"  -> "BSE_EQ";
            case "NFO"  -> "NSE_FNO";
            case "BFO"  -> "BSE_FNO";
            case "CDS"  -> "NSE_CURRENCY";
            case "MCX"  -> "MCX_COMM";
            default     -> exchange;
        };
    }

    public String toDhanProductType(String productType) {
        return switch (productType.toUpperCase()) {
            case "DELIVERY", "CNC"      -> "CNC";
            case "INTRADAY", "MIS"      -> "INTRADAY";
            case "MARGIN"               -> "MARGIN";
            case "CARRYFORWARD", "MTF"  -> "MTF";
            default                     -> "INTRADAY";
        };
    }

    public String toDhanOrderType(String orderType) {
        return switch (orderType.toUpperCase()) {
            case "MARKET"                       -> "MARKET";
            case "LIMIT"                        -> "LIMIT";
            case "STOPLOSS_LIMIT",  "SL"        -> "STOP_LOSS";
            case "STOPLOSS_MARKET", "SL-M"      -> "STOP_LOSS_MARKET";
            default                             -> "MARKET";
        };
    }

    // ── PRIVATE HELPERS ──────────────────────────────────────────────────────
    private JSONObject buildOrderBody(DhanOrderParams params) {
        JSONObject body = new JSONObject();
        body.put("dhanClientId",        params.getDhanClientId());
        body.put("correlationId",       params.getCorrelationId());
        body.put("transactionType",     params.getTransactionType());
        body.put("exchangeSegment",     params.getExchangeSegment());
        body.put("productType",         params.getProductType());
        body.put("orderType",           params.getOrderType());
        body.put("validity",            params.getValidity());
        body.put("securityId",          params.getSecurityId());
        body.put("quantity",            params.getQuantity());
        body.put("disclosedQuantity",   0);
        if (!params.getOrderType().equals("MARKET")) {
            body.put("price", params.getPrice() > 0 ? params.getPrice() : 0);
        }
        body.put("triggerPrice",        params.getTriggerPrice() > 0 ? params.getTriggerPrice() : 0);
        body.put("afterMarketOrder",    params.isAfterMarketOrder());
        body.put("amoTime",             params.getAmoTime() != null ? params.getAmoTime() : null);
        return body;
    }

    private JSONObject buildModifyOrderBody(DhanModifyOrderParams params) {
        JSONObject body = new JSONObject();
        body.put("dhanClientId",        params.getDhanClientId());
        body.put("orderId",             params.getOrderId());
        body.put("orderType",           params.getOrderType());
        body.put("quantity",            params.getQuantity());
        body.put("validity",            params.getValidity());
        body.put("disclosedQuantity",   params.getDisclosedQuantity());

        String ot = params.getOrderType().toUpperCase();
        // Price: only for LIMIT and STOP_LOSS; empty string for MARKET / SL-M
        if (ot.equals("LIMIT") || ot.equals("STOP_LOSS")) {
            body.put("price", params.getPrice() > 0 ? params.getPrice() : 0.0);
        } else {
            body.put("price", "");
        }
        // TriggerPrice: only for SL types
        if (ot.equals("STOP_LOSS") || ot.equals("STOP_LOSS_MARKET")) {
            body.put("triggerPrice", params.getTriggerPrice() > 0 ? params.getTriggerPrice() : 0.0);
        } else {
            body.put("triggerPrice", "");
        }
        return body;
    }

    private JSONObject buildConvertPositionBody(DhanConvertPositionParams params) {
        JSONObject body = new JSONObject();
        body.put("dhanClientId",    params.getDhanClientId());
        body.put("fromProductType", params.getFromProductType());
        body.put("exchangeSegment", params.getExchangeSegment());
        body.put("positionType",    params.getPositionType());
        body.put("securityId",      params.getSecurityId());
        body.put("tradingSymbol",   params.getTradingSymbol() != null ? params.getTradingSymbol() : "");
        body.put("convertQty",      params.getConvertQty());
        body.put("toProductType",   params.getToProductType());
        return body;
    }
}