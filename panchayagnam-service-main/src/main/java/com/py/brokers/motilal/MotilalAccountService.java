package com.py.brokers.motilal;

import com.py.brokers.motilal.dto.MotilalModifyOrderParams;
import com.py.brokers.motilal.dto.MotilolOrderParams;
import com.py.demataccount.entity.PyBrokerSecret;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class MotilalAccountService {

    private static final Logger log = LoggerFactory.getLogger(MotilalAccountService.class);

    private static final String LOGIN_URL
            = "https://openapi.motilaloswal.com/rest/login/v7/authdirectapi";
    private static final String ACCESS_TOKEN_URL
            = "https://openapi.motilaloswal.com/rest/login/v1/getaccesstoken";
    private static final String PROFILE_URL
            = "https://openapi.motilaloswal.com/rest/login/v5/getprofile";
    private static final String RMS_URL
            = "https://openapi.motilaloswal.com/rest/report/v3/getreportmarginsummary";
    private static final String PLACE_ORDER_URL
            = "https://openapi.motilaloswal.com/rest/trans/v2/placeorder";
    private static final String GET_ORDERS_URL
            = "https://openapi.motilaloswal.com/rest/book/v5/getorderbook";
    private static final String LTP_URL
            = "https://openapi.motilaloswal.com/rest/report/v3/getltpdata";
    private static final String MODIFY_ORDER_URL
            = "https://openapi.motilaloswal.com/rest/trans/v5/modifyorder";
    private static final String CANCEL_ORDER_URL
            = "https://openapi.motilaloswal.com/rest/trans/v2/cancelorder";
    private static final String HOLDINGS_URL
            = "https://openapi.motilaloswal.com/rest/report/v3/getdpholding";
    private static final String POSITIONS_URL
            = "https://openapi.motilaloswal.com/rest/book/v4/getposition";

    @Autowired
    private MotilalLoginService motilalLoginService;

    @Autowired
    private RestTemplate restTemplate;

    // ── HELPER ────────────────────────────────────────────────────────────────
    private HttpHeaders headers(String apiKey, String apiSecret,
            String vendorInfo, String authToken, String accessToken) {
        return motilalLoginService.buildHeaders(
                apiKey, apiSecret, vendorInfo, authToken, accessToken);
    }

    private JSONObject post(String url, HttpEntity<String> entity) {
        ResponseEntity<String> response = restTemplate.postForEntity(url, entity, String.class);
        if (response.getBody() == null || response.getBody().isBlank()) {
            throw new RuntimeException("Empty response from Motilal API: " + url);
        }
        return new JSONObject(response.getBody());
    }

    private void assertSuccess(JSONObject json, String context) {
        if (!"SUCCESS".equals(json.optString("status"))) {
            String msg = json.optString("message", context + " failed");
            String code = json.optString("errorcode", "");
            throw new RuntimeException(context + " failed: " + msg
                    + (code.isBlank() ? "" : " (Code: " + code + ")"));
        }
    }

    // ── LOGIN ─────────────────────────────────────────────────────────────────
    public JSONObject login(String userId, String hashedPassword,
            String twoFa, String totp,
            String apiKey, String apiSecret, String vendorInfo) {

        JSONObject body = new JSONObject();
        body.put("userid", userId);
        body.put("password", hashedPassword);
        body.put("2FA", twoFa);
        body.put("totp", totp);

        HttpEntity<String> entity = new HttpEntity<>(body.toString(),
                headers(apiKey, apiSecret, vendorInfo, null, null));

        JSONObject json = post(LOGIN_URL, entity);
        log.info("Motilal login response received: status={}", json.optString("status"));
        assertSuccess(json, "Motilal login");
        return json;
    }

    // ── GET ACCESS TOKEN ──────────────────────────────────────────────────────
    public JSONObject getAccessToken(String authToken,
            String apiKey, String apiSecret, String vendorInfo) {

        HttpEntity<String> entity = new HttpEntity<>("{}",
                headers(apiKey, apiSecret, vendorInfo, authToken, null));

        JSONObject json = post(ACCESS_TOKEN_URL, entity);
        log.info("Motilal access token response received: status={}", json.optString("status"));
        assertSuccess(json, "Motilal access token");
        return json;
    }

    // ── GET PROFILE ───────────────────────────────────────────────────────────
    public JSONObject getProfile(String apiKey, String apiSecret,
            String vendorInfo, String authToken, String accessToken) {

        HttpEntity<String> entity = new HttpEntity<>("",
                headers(apiKey, apiSecret, vendorInfo, authToken, accessToken));

        JSONObject json = post(PROFILE_URL, entity);
        log.info("Motilal profile response: {}", json);
        assertSuccess(json, "Motilal profile");
        return json;
    }

    // ── RMS ───────────────────────────────────────────────────────────────────
    public JSONObject getRMS(String apiKey, String apiSecret,
            String vendorInfo, String authToken, String accessToken) {

        JSONObject body = new JSONObject();
        body.put("summary", "");

        HttpEntity<String> entity = new HttpEntity<>(body.toString(),
                headers(apiKey, apiSecret, vendorInfo, authToken, accessToken));

        JSONObject json = post(RMS_URL, entity);
        log.info("Motilal RMS response: {}", json);
        assertSuccess(json, "Motilal RMS");
        return json;
    }

    // ── ORDER HISTORY ─────────────────────────────────────────────────────────
    public JSONObject getOrderBook(String apiKey, String apiSecret,
            String vendorInfo, String authToken, String accessToken) {

        JSONObject body = new JSONObject();
        body.put("clientcode", "");

        HttpEntity<String> entity = new HttpEntity<>(body.toString(),
                headers(apiKey, apiSecret, vendorInfo, authToken, accessToken));

        JSONObject json = post(GET_ORDERS_URL, entity);
        log.info("Motilal order book response: {}", json);
        assertSuccess(json, "Motilal order book");
        return json;
    }

    // ── LTP ───────────────────────────────────────────────────────────────────
    public JSONObject getLtp(String apiKey, String apiSecret,
            String vendorInfo, String authToken, String accessToken,
            String exchange, long scripCode) {

        JSONObject body = new JSONObject();
        body.put("clientcode", "");
        body.put("exchange", exchange);
        body.put("scripcode", scripCode);

        HttpEntity<String> entity = new HttpEntity<>(body.toString(),
                headers(apiKey, apiSecret, vendorInfo, authToken, accessToken));

        JSONObject json = post(LTP_URL, entity);
        log.info("Motilal LTP response: {}", json);
        assertSuccess(json, "Motilal LTP");
        return json.getJSONObject("data");
    }

    public double getLtpPrice(String apiKey, String apiSecret,
            String vendorInfo, String authToken, String accessToken,
            String exchange, long scripCode) {

        JSONObject data = getLtp(apiKey, apiSecret, vendorInfo,
                authToken, accessToken, exchange, scripCode);
        double ltpPaise = data.optDouble("ltp", 0.0);
        double ltpRupees = ltpPaise / 100.0;
        log.info("LTP | exchange={} scripCode={} ltp={}p = ₹{}",
                exchange, scripCode, ltpPaise, ltpRupees);
        return ltpRupees;
    }

    // ── PLACE ORDER ───────────────────────────────────────────────────────────
    public JSONObject placeOrder(MotilolOrderParams order,
            String apiKey, String apiSecret,
            String vendorInfo, String authToken, String accessToken) {

        log.info("Placing Motilal order | exchange={} token={} side={} qty={} price={}",
                order.getExchange(), order.getSymbolToken(),
                order.getBuyOrSell(), order.getQuantityInLot(), order.getPrice());

        JSONObject body = new JSONObject();
        body.put("clientcode", "");
        body.put("exchange", order.getExchange());
        body.put("symboltoken", order.getSymbolToken());
        body.put("buyorsell", order.getBuyOrSell());
        body.put("ordertype", order.getOrderType());
        body.put("producttype", order.getProductType());
        body.put("orderduration", order.getOrderDuration());
        body.put("price", order.getPrice());
        body.put("triggerprice",
                order.getTriggerPrice() != null ? order.getTriggerPrice() : 0);
        body.put("quantityinlot", order.getQuantityInLot());
        body.put("disclosedquantity",
                order.getDisclosedQuantity() != null ? order.getDisclosedQuantity() : 0);
        body.put("amoorder",
                order.getAmoOrder() != null ? order.getAmoOrder() : "N");
        body.put("goodtilldate",
                order.getGoodTillDate() != null ? order.getGoodTillDate() : "");
        body.put("algoid",
                order.getAlgoId() != null ? order.getAlgoId() : "");
        body.put("tag", "TRADEOWN");
        body.put("participantcode",
                order.getParticipantCode() != null ? order.getParticipantCode() : "");

        HttpEntity<String> entity = new HttpEntity<>(body.toString(),
                headers(apiKey, apiSecret, vendorInfo, authToken, accessToken));

        JSONObject json = post(PLACE_ORDER_URL, entity);
        log.info("Motilal place order response: {}", json);
        assertSuccess(json, "Motilal place order");

        log.info("✅ Motilal order placed | uniqueOrderId={}",
                json.optString("uniqueorderid"));
        return json;
    }

    // ── MODIFY ORDER ──────────────────────────────────────────────────────────
    public JSONObject modifyOrder(MotilalModifyOrderParams order,
            String apiKey, String apiSecret,
            String vendorInfo, String authToken, String accessToken) {

        log.info("Modifying Motilal order | uniqueOrderId={} qty={} price={}",
                order.getUniqueOrderId(), order.getNewQuantityInLot(), order.getNewPrice());

        JSONObject body = new JSONObject();
        body.put("clientcode", order.getClientCode() != null ? order.getClientCode() : "");
        body.put("uniqueorderid", order.getUniqueOrderId());
        body.put("newordertype", order.getNewOrderType());
        body.put("neworderduration", order.getNewOrderDuration());
        body.put("newprice", order.getNewPrice());
        body.put("newtriggerprice",
                order.getNewTriggerPrice() != null ? order.getNewTriggerPrice() : 0);
        body.put("newquantityinlot", order.getNewQuantityInLot());
        body.put("newdisclosedquantity",
                order.getNewDisclosedQuantity() != null ? order.getNewDisclosedQuantity() : 0);
        body.put("newgoodtilldate",
                order.getNewGoodTillDate() != null ? order.getNewGoodTillDate() : "");
        body.put("lastmodifiedtime", order.getLastModifiedTime());
        body.put("qtytradedtoday", order.getQtyTradedToday());

        HttpEntity<String> entity = new HttpEntity<>(body.toString(),
                headers(apiKey, apiSecret, vendorInfo, authToken, accessToken));

        JSONObject json = post(MODIFY_ORDER_URL, entity);
        log.info("Motilal modify order response: {}", json);
        assertSuccess(json, "Motilal modify order");

        log.info("✅ Motilal order modified | uniqueOrderId={}",
                json.optString("uniqueorderid"));
        return json;
    }

    // ── CANCEL ORDER ──────────────────────────────────────────────────────────
    public JSONObject cancelOrder(MotilalModifyOrderParams order,
            String apiKey, String apiSecret,
            String vendorInfo, String authToken, String accessToken) {

        log.info("Cancelling Motilal order | uniqueOrderId={}", order.getUniqueOrderId());

        JSONObject body = new JSONObject();
        body.put("clientcode", order.getClientCode() != null ? order.getClientCode() : "");
        body.put("uniqueorderid", order.getUniqueOrderId());

        HttpEntity<String> entity = new HttpEntity<>(body.toString(),
                headers(apiKey, apiSecret, vendorInfo, authToken, accessToken));

        JSONObject json = post(CANCEL_ORDER_URL, entity);
        log.info("Motilal cancel order response: {}", json);
        assertSuccess(json, "Motilal cancel order");

        log.info("✅ Motilal order cancelled | uniqueOrderId={}",
                json.optString("uniqueorderid"));
        return json;
    }

    // ── HOLDINGS ──────────────────────────────────────────────────────────────
    public JSONObject getHoldings(String apiKey, String apiSecret,
            String vendorInfo, String authToken, String accessToken) {

        JSONObject body = new JSONObject();
        body.put("clientcode", "");

        HttpEntity<String> entity = new HttpEntity<>(body.toString(),
                headers(apiKey, apiSecret, vendorInfo, authToken, accessToken));

        JSONObject json = post(HOLDINGS_URL, entity);
        log.info("Motilal holdings response status={}", json.optString("status"));
        assertSuccess(json, "Motilal holdings");
        return json;
    }

    // ── POSITIONS ─────────────────────────────────────────────────────────────
    public JSONObject getPositions(String apiKey, String apiSecret,
            String vendorInfo, String authToken, String accessToken) {

        JSONObject body = new JSONObject();
        body.put("clientcode", "");

        HttpEntity<String> entity = new HttpEntity<>(body.toString(),
                headers(apiKey, apiSecret, vendorInfo, authToken, accessToken));

        JSONObject json = post(POSITIONS_URL, entity);
        log.info("Motilal positions response status={}", json.optString("status"));
        assertSuccess(json, "Motilal positions");
        return json;
    }

    // =========================================================================
    // ✅ GET PROFILE
    // =========================================================================
    public JSONObject getProfile(PyBrokerSecret secret, JSONObject tokens) {

        HttpHeaders headers = motilalLoginService.buildHeaders(
                secret,
                tokens.getString("AuthToken"),
                tokens.getString("AccessToken"));
        HttpEntity<String> entity = new HttpEntity<>("", headers);

        RestTemplate restTemplate = new RestTemplate();
        ResponseEntity<String> response = restTemplate.postForEntity(
                PROFILE_URL, entity, String.class);

        JSONObject json = new JSONObject(response.getBody());
        log.info("🔍 Motilal profile response: {}", json);

        if (!"SUCCESS".equals(json.optString("status"))) {
            String msg = json.optString("message", "Profile fetch failed");
            String code = json.optString("errorcode", "");
            throw new RuntimeException("Motilal profile failed: " + msg
                    + (code.isBlank() ? "" : " (Code: " + code + ")"));
        }

        return json;
    }
}
