package com.py.angel.service;

import com.py.angel.client.Routes;
import com.py.angel.client.SmartConnect;
import com.py.angel.dto.AngelOneCancelOrderRequest;
import com.py.angel.dto.AngelOneConvertPositionRequest;
import com.py.angel.dto.AngelOneLoginRequest;
import com.py.angel.dto.AngelOneLtpRequest;
import com.py.angel.dto.AngelOneModifyOrderRequest;
import com.py.angel.dto.AngelOneOrderHistoryRequest;
import com.py.angel.dto.AngelOnePlaceOrderRequest;
import com.py.angel.dto.AngelOneRMSRequest;
import com.py.angel.dto.Order;
import com.py.angel.dto.OrderParams;
import com.py.angel.exception.SmartAPIException;
import com.py.angel.http.ApiRequestHandler;
import java.io.IOException;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class AngelOneApisService {

    private final ApiRequestHandler apiRequestHandler;
    private final Routes routes;
    private static final Logger log = LoggerFactory.getLogger(AngelOneApisService.class);

    @org.springframework.beans.factory.annotation.Value("${trading.paper-trading.enabled:true}")
    private boolean paperTradingEnabled;

    public AngelOneApisService(ApiRequestHandler apiRequestHandler, Routes routes) {
        this.apiRequestHandler = apiRequestHandler;
        this.routes = routes;
    }

    // ─── ERROR CODE MAPPER ────────────────────────────────────────────────────
    private String buildErrorMessage(String errorCode, String brokerMessage) {
        String friendly = switch (errorCode) {

            // ── Token errors ──────────────────────────────────────────────────
            case "AG8001" -> "Invalid token — please re-login to refresh your session";
            case "AG8002" -> "Token expired — please re-login to get a new token";
            case "AG8003" -> "Token missing — authentication token was not sent";
            case "AB8050" -> "Invalid refresh token — please re-login";
            case "AB8051" -> "Refresh token expired — please re-login";

            // ── Login / credential errors ─────────────────────────────────────
            case "AB1000" -> "Invalid email or password — check your credentials";
            case "AB1001" -> "Invalid email address format";
            case "AB1002" -> "Password length is invalid — check AngelOne password requirements";
            case "AB1006" -> "This client is blocked for trading — contact AngelOne support";
            case "AB1010" -> "AMX session expired — please re-login";
            case "AB1011" -> "Client not logged in — please login first";
            case "AB1031" -> "Old password mismatch";
            case "AB1032" -> "User not found — check the client code";
            case "AB1034" -> "Invalid API Key — check the API key in your AngelOne developer app";

            // ── Registration errors ───────────────────────────────────────────
            case "AB1003" -> "Client already exists — use UPDATE instead of ADD";
            case "AB1005" -> "User type must be USER — check your AngelOne account type";

            // ── Order errors ──────────────────────────────────────────────────
            case "AB1008" -> "Invalid order variety — use NORMAL, AMO, STOPLOSS, or ROBO";
            case "AB1009" -> "Symbol not found — check the trading symbol or token";
            case "AB1012" -> "Invalid product type — use DELIVERY, INTRADAY, or MARGIN";
            case "AB1013" -> "Order not found — the order ID may be invalid or already settled";
            case "AB1014" -> "Trade not found";
            case "AB2002" -> "ROBO orders are blocked for this account";
            case "AB4008" -> "Order tag exceeds 20 characters — shorten the tag and retry";

            // ── Portfolio errors ──────────────────────────────────────────────
            case "AB1015" -> "Holdings not found for this account";
            case "AB1016" -> "Positions not found for this account";
            case "AB1017" -> "Position conversion failed — the position may already be converted "
                           + "or insufficient quantity available";
            case "AB1018" -> "Failed to fetch symbol details — try again or check the token";

            // ── System / internal errors ──────────────────────────────────────
            case "AB1004" -> "AngelOne server error — please try again after some time";
            case "AB1007" -> "AMX error — AngelOne backend issue, try again shortly";
            case "AB2000" -> "Unspecified error from AngelOne — check credentials and try again";
            case "AB2001" -> "AngelOne internal error — please try again after some time";

            // ── Network / IP / exchange errors ────────────────────────────────
            case "AG7002" -> "IP not whitelisted — add this server IP in your AngelOne account";
            case "AB4036" -> "Exchange not enabled for this account";

            // ── Unknown — surface broker message as-is ────────────────────────
            default -> brokerMessage;
        };
        return "AngelOne [" + errorCode + "]: " + friendly;
    }

    // ─── READ ERROR FROM RESPONSE ─────────────────────────────────────────────
    // Handles both camelCase (errorCode) and lowercase (errorcode) field names
    private String extractErrorCode(JSONObject response) {
        return response.optString("errorCode",
               response.optString("errorcode", ""));
    }

    private String extractMessage(JSONObject response, String fallback) {
        return response.optString("message", fallback);
    }

    // ─── LOGIN ───────────────────────────────────────────────────────────────
    public JSONObject login(AngelOneLoginRequest request) {
        if (paperTradingEnabled && (
                (request.getClientCode() != null && (request.getClientCode().startsWith("SIM-") || request.getClientCode().startsWith("AG"))) ||
                (request.getApiKey() != null && request.getApiKey().startsWith("SIM-")) ||
                (request.getPassword() != null && request.getPassword().startsWith("SIM-")))) {
            log.info("🛡️ [PAPER TRADING] Simulated AngelOne login for clientCode={}", request.getClientCode());
            JSONObject simData = new JSONObject();
            simData.put("jwtToken", "PAPER-SIM-JWT-ANGEL-" + System.currentTimeMillis());
            simData.put("refreshToken", "PAPER-SIM-REFRESH-ANGEL-" + System.currentTimeMillis());
            simData.put("feedToken", "PAPER-SIM-FEED-ANGEL-" + System.currentTimeMillis());
            return simData;
        }
        try {
            JSONObject params = new JSONObject();
            params.put("clientcode", request.getClientCode());
            params.put("password", request.getPassword());
            params.put("totp", request.getTotp());

            JSONObject loginResult = apiRequestHandler.postRequest(
                    request.getApiKey(), routes.getLoginUrl(), params);

            log.info("AngelOne login raw response: {}", loginResult);

            boolean successBool = loginResult.optBoolean("success", false);
            boolean successString = "true".equalsIgnoreCase(loginResult.optString("status", ""));
            boolean isSuccess = successBool || successString;

            String errorCode = extractErrorCode(loginResult);
            String message = extractMessage(loginResult, "Login failed");

            if (!isSuccess) {
                log.error("AngelOne login rejected | clientCode={} errorCode={} message={}",
                        request.getClientCode(), errorCode, message);
                throw new RuntimeException(buildErrorMessage(errorCode, message));
            }

            Object dataRaw = loginResult.opt("data");
            if (dataRaw == null || dataRaw.equals(JSONObject.NULL)) {
                log.error("AngelOne login: data is null despite success | response={}", loginResult);
                throw new RuntimeException(
                        "AngelOne login succeeded but data block is null — please try again");
            }
            if (!(dataRaw instanceof JSONObject)) {
                log.error("AngelOne login: data is not a JSONObject | type={} value={}",
                        dataRaw.getClass().getSimpleName(), dataRaw);
                throw new RuntimeException(
                        "AngelOne login succeeded but data block is invalid ("
                        + dataRaw.getClass().getSimpleName() + ") — please try again");
            }

            log.info("AngelOne login SUCCESS | clientCode={}", request.getClientCode());
            return (JSONObject) dataRaw;

        } catch (RuntimeException e) {
            throw e;
        } catch (IOException | SmartAPIException e) {
            log.error("AngelOne login HTTP/API error: {}", e.getMessage(), e);
            throw new RuntimeException("AngelOne login failed: " + e.getMessage(), e);
        }
    }

    // ─── RMS ─────────────────────────────────────────────────────────────────
    public JSONObject getRMS(AngelOneRMSRequest request) {
        try {
            log.info("AngelOne RMS fetch initiated");
            String url = routes.get("api.order.rms.data");
            JSONObject response = apiRequestHandler.getRequest(
                    request.getApiKey(), url, request.getAccessToken());

            log.info("AngelOne RMS raw response: {}", response);

            if (!response.optBoolean("status", false)) {
                String errorCode = extractErrorCode(response);
                String message = extractMessage(response, "RMS fetch failed");
                log.error("AngelOne RMS rejected | errorCode={} message={}", errorCode, message);
                throw new RuntimeException(buildErrorMessage(errorCode, message));
            }

            if (response.isNull("data")) {
                log.warn("AngelOne RMS: data block is null");
                throw new RuntimeException("AngelOne RMS returned empty data — please try again");
            }

            log.info("AngelOne RMS fetch completed");
            return response.getJSONObject("data");

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("AngelOne RMS failed: {}", e.getMessage(), e);
            throw new RuntimeException("RMS fetch failed: " + e.getMessage(), e);
        }
    }

    // ─── PLACE ORDER ─────────────────────────────────────────────────────────
    public JSONObject placeOrder(AngelOnePlaceOrderRequest request) {
        try {
            SmartConnect smartConnect = new SmartConnect(request.getApiKey());
            smartConnect.setAccessToken(request.getAccessToken());

            OrderParams orderParams = new OrderParams();
            orderParams.setExchange(request.getExchange());
            orderParams.setTradingsymbol(request.getTradingsymbol());
            orderParams.setSymboltoken(request.getSymboltoken());
            orderParams.setOrdertype(request.getOrdertype());
            orderParams.setProducttype(request.getProducttype());
            orderParams.setQuantity(request.getQuantity());
            orderParams.setPrice(request.getPrice());
            orderParams.setDuration(request.getDuration());
            orderParams.setSquareoff(request.getSquareoff());
            orderParams.setStoploss(request.getStoploss());
            orderParams.setTriggerprice(request.getTriggerprice().toString());
            orderParams.setTransactiontype(request.getTransactiontype());

            log.info("AngelOne place order | symbol={} qty={} type={}",
                    request.getTradingsymbol(), request.getQuantity(),
                    request.getTransactiontype());

            Order order = smartConnect.placeOrder(orderParams, request.getVariety());

            if (order == null || order.orderId == null) {
                throw new RuntimeException(
                        "Place order failed — no order ID returned from AngelOne");
            }

            log.info("AngelOne place order SUCCESS | symbol={} orderId={}",
                    request.getTradingsymbol(), order.orderId);

            JSONObject response = new JSONObject();
            response.put("orderId", order.orderId);
            response.put("status", "SUCCESS");
            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            log.error("AngelOne place order error: {}", e.getMessage(), e);
            throw new RuntimeException("Place order failed: " + e.getMessage(), e);
        }
    }

    // ─── MODIFY ORDER ────────────────────────────────────────────────────────
    public JSONObject modifyOrder(AngelOneModifyOrderRequest request) {
        try {
            SmartConnect smartConnect = new SmartConnect(request.getApiKey());
            smartConnect.setAccessToken(request.getAccessToken());

            OrderParams orderParams = new OrderParams();
            orderParams.setExchange(request.getExchange());
            orderParams.setTradingsymbol(request.getTradingSymbol());
            orderParams.setSymboltoken(request.getSymbolToken());
            orderParams.setOrdertype(request.getOrderType());
            orderParams.setProducttype(request.getProductType());
            orderParams.setQuantity(request.getQuantity());
            orderParams.setPrice(request.getPrice());
            orderParams.setDuration(request.getDuration() != null ? request.getDuration() : "DAY");
            orderParams.setTriggerprice(
                    request.getTriggerPrice() != null
                    ? String.valueOf(request.getTriggerPrice()) : "0");

            String variety = request.getVariety() != null ? request.getVariety() : "NORMAL";

            log.info("AngelOne modify order | orderId={} symbol={} qty={} price={}",
                    request.getOrderId(), request.getTradingSymbol(),
                    request.getQuantity(), request.getPrice());

            Order order = smartConnect.modifyOrder(request.getOrderId(), orderParams, variety);

            if (order == null || order.orderId == null) {
                throw new RuntimeException(
                        "Modify order failed — no order ID returned from AngelOne");
            }

            log.info("AngelOne modify order SUCCESS | orderId={}", order.orderId);

            JSONObject response = new JSONObject();
            response.put("orderId", order.orderId);
            response.put("status", "MODIFIED");
            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            log.error("AngelOne modify order failed: {}", e.getMessage(), e);
            throw new RuntimeException("Modify order failed: " + e.getMessage(), e);
        }
    }

    // ─── CANCEL ORDER ────────────────────────────────────────────────────────
    public JSONObject cancelOrder(AngelOneCancelOrderRequest request) {
        try {
            SmartConnect smartConnect = new SmartConnect(request.getApiKey());
            smartConnect.setAccessToken(request.getAccessToken());

            String variety = request.getVariety() != null ? request.getVariety() : "NORMAL";

            log.info("AngelOne cancel order | orderId={} variety={}",
                    request.getOrderId(), variety);

            Order order = smartConnect.cancelOrder(request.getOrderId(), variety);

            if (order == null || order.orderId == null) {
                throw new RuntimeException(
                        "Cancel order failed — no order ID returned from AngelOne");
            }

            log.info("AngelOne cancel order SUCCESS | orderId={}", order.orderId);

            JSONObject response = new JSONObject();
            response.put("orderId", order.orderId);
            response.put("status", "CANCELLED");
            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            log.error("AngelOne cancel order failed: {}", e.getMessage(), e);
            throw new RuntimeException("Cancel order failed: " + e.getMessage(), e);
        }
    }

    // ─── ORDER HISTORY ───────────────────────────────────────────────────────
    public JSONObject getOrderHistory(AngelOneOrderHistoryRequest request) {
        try {
            log.info("AngelOne order history fetch initiated");

            SmartConnect smartConnect = new SmartConnect(request.getApiKey());
            smartConnect.setAccessToken(request.getAccessToken());

            JSONObject response = smartConnect.getOrderHistory();

            if (response == null) {
                throw new RuntimeException(
                        "Order history fetch failed — null response from AngelOne");
            }

            if (!response.optBoolean("status", false)) {
                String errorCode = extractErrorCode(response);
                String message = extractMessage(response, "Order history fetch failed");
                log.error("AngelOne order history rejected | errorCode={} message={}",
                        errorCode, message);
                throw new RuntimeException(buildErrorMessage(errorCode, message));
            }

            log.info("AngelOne order history fetch SUCCESS");
            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            log.error("AngelOne order history failed: {}", e.getMessage(), e);
            throw new RuntimeException("Order history failed: " + e.getMessage(), e);
        }
    }

    // ─── LTP ─────────────────────────────────────────────────────────────────
    public JSONObject getLTP(AngelOneLtpRequest request) {
        try {
            log.info("AngelOne LTP request | exchange={} symbol={} token={}",
                    request.getExchange(), request.getTradingSymbol(), request.getSymbolToken());

            JSONObject params = new JSONObject();
            params.put("exchange", request.getExchange());
            params.put("tradingsymbol", request.getTradingSymbol());
            params.put("symboltoken", request.getSymbolToken());

            String url = routes.get("api.ltp.data");
            JSONObject response = apiRequestHandler.postRequest(
                    request.getApiKey(), url, params, request.getAccessToken());

            log.info("AngelOne LTP raw response: {}", response);

            if (!response.optBoolean("status", false)) {
                String errorCode = extractErrorCode(response);
                String message = extractMessage(response, "LTP fetch failed");
                log.error("AngelOne LTP rejected | symbol={} errorCode={} message={}",
                        request.getTradingSymbol(), errorCode, message);
                throw new RuntimeException(buildErrorMessage(errorCode, message));
            }

            if (response.isNull("data")) {
                log.warn("AngelOne LTP: data block is null for symbol={}", request.getTradingSymbol());
                throw new RuntimeException(
                        "LTP returned empty data for symbol: " + request.getTradingSymbol());
            }

            log.info("AngelOne LTP SUCCESS | symbol={}", request.getTradingSymbol());
            return response.getJSONObject("data");

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("AngelOne LTP failed: {}", e.getMessage(), e);
            throw new RuntimeException("LTP fetch failed: " + e.getMessage(), e);
        }
    }

    // ─── CONVERT POSITION ────────────────────────────────────────────────────
    public JSONObject convertPosition(AngelOneConvertPositionRequest request) {
        try {
            log.info("AngelOne convert position initiated | symbol={} {} -> {}",
                    request.getTradingsymbol(),
                    request.getOldproducttype(),
                    request.getNewproducttype());

            JSONObject params = new JSONObject();
            params.put("exchange",        request.getExchange());
            params.put("symboltoken",     request.getSymboltoken());
            params.put("oldproducttype",  request.getOldproducttype());
            params.put("newproducttype",  request.getNewproducttype());
            params.put("tradingsymbol",   request.getTradingsymbol());
            params.put("symbolname",      request.getSymbolname());
            params.put("instrumenttype",  request.getInstrumenttype() != null
                                            ? request.getInstrumenttype() : "");
            params.put("priceden",        request.getPriceden());
            params.put("pricenum",        request.getPricenum());
            params.put("genden",          request.getGenden());
            params.put("gennum",          request.getGennum());
            params.put("precision",       request.getPrecision());
            params.put("multiplier",      request.getMultiplier());
            params.put("boardlotsize",    request.getBoardlotsize());
            params.put("buyqty",          request.getBuyqty());
            params.put("sellqty",         request.getSellqty());
            params.put("buyamount",       request.getBuyamount());
            params.put("sellamount",      request.getSellamount());
            params.put("transactiontype", request.getTransactiontype());
            params.put("quantity",        request.getQuantity());
            params.put("type",            request.getType());

            String url = routes.get("api.order.rms.position.convert");
            JSONObject response = apiRequestHandler.postRequest(
                    request.getApiKey(), url, params, request.getAccessToken());

            log.info("AngelOne convert position raw response: {}", response);

            if (!response.optBoolean("status", false)) {
                String errorCode = extractErrorCode(response);
                String message = extractMessage(response, "Position conversion failed");
                log.error("AngelOne convert position rejected | symbol={} {} -> {} "
                        + "| errorCode={} message={}",
                        request.getTradingsymbol(),
                        request.getOldproducttype(),
                        request.getNewproducttype(),
                        errorCode, message);
                throw new RuntimeException(buildErrorMessage(errorCode, message));
            }

            log.info("AngelOne convert position SUCCESS | symbol={} {} -> {}",
                    request.getTradingsymbol(),
                    request.getOldproducttype(),
                    request.getNewproducttype());

            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("AngelOne convert position failed: {}", e.getMessage(), e);
            throw new RuntimeException("Convert position failed: " + e.getMessage(), e);
        }
    }
}