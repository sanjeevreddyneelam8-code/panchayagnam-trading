package com.py.brokers.angel.client;

import static com.py.brokers.angel.client.Constants.IO_EXCEPTION_ERROR_MSG;
import static com.py.brokers.angel.client.Constants.IO_EXCEPTION_OCCURRED;
import static com.py.brokers.angel.client.Constants.JSON_EXCEPTION_ERROR_MSG;
import static com.py.brokers.angel.client.Constants.JSON_EXCEPTION_OCCURRED;
import static com.py.brokers.angel.client.Constants.SMART_API_EXCEPTION_ERROR_MSG;
import static com.py.brokers.angel.client.Constants.SMART_API_EXCEPTION_OCCURRED;
import com.py.brokers.angel.exception.SmartAPIException;
import com.py.brokers.angel.http.ApiRequestHandler;
import com.py.brokers.angel.dto.EstimateChargesParams;
import com.py.brokers.angel.dto.Gtt;
import com.py.brokers.angel.dto.GttParams;
import com.py.brokers.angel.dto.MarginParams;
import com.py.brokers.angel.dto.Order;
import com.py.brokers.angel.dto.OrderParams;
import com.py.brokers.angel.dto.TokenSet;
import com.py.brokers.angel.dto.User;
import com.py.demataccount.service.PyBrokerAccountService;

import java.io.IOException;
import java.net.Proxy;
import java.util.List;
import java.util.Map;
import org.apache.commons.codec.digest.DigestUtils;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class SmartConnect {

    public static boolean ENABLE_LOGGING = false;
    private Proxy proxy = null;
    private String apiKey;
    private String accessToken;
    private String refreshToken;
    private Routes routes = new Routes();
    private String userId;
    private ApiRequestHandler smartAPIRequestHandler = new ApiRequestHandler();
    private static final Logger log = LoggerFactory.getLogger(SmartConnect.class);

    @Autowired
    private PyBrokerAccountService pyBrokerAccountService;

    public SmartConnect() {
        System.setProperty("https.protocols", "TLSv1.2,TLSv1.3");
    }

    public SmartConnect(String apiKey) {
        this.apiKey = apiKey;
    }

    public SmartConnect(String apiKey, String accessToken, String refreshToken) {
        this.apiKey = apiKey;
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
    }

    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }

    public String getApiKey() throws NullPointerException {
        if (apiKey != null) {
            return apiKey;
        } else {
            throw new NullPointerException();
        }
    }

    public String getAccessToken() throws NullPointerException {
        if (accessToken != null) {
            return accessToken;
        } else {
            throw new NullPointerException();
        }
    }

    public String getUserId() throws NullPointerException {
        if (userId != null) {
            return userId;
        } else {
            throw new NullPointerException();
        }
    }

    public void setUserId(String id) {
        userId = id;
    }

    public String getPublicToken() throws NullPointerException {
        if (refreshToken != null) {
            return refreshToken;
        } else {
            throw new NullPointerException();
        }
    }

    public void setAccessToken(String accessToken) {
        this.accessToken = accessToken;
    }

    public void setRefreshToken(String refreshToken) {
        this.refreshToken = refreshToken;
    }

    public String getLoginURL() throws NullPointerException {
        return routes.getLoginUrl();
    }

    // =========================================================================
    // ✅ FIXED — generateSession with proper error messages
    // =========================================================================
    public User generateSession(String clientCode, String password, String totp, String apiKey) {
        try {
            smartAPIRequestHandler = new ApiRequestHandler();

            JSONObject params = new JSONObject();
            params.put("clientcode", clientCode);
            params.put("password", password);
            params.put("totp", totp);

            JSONObject loginResultObject = smartAPIRequestHandler.postRequest(
                    apiKey, routes.getLoginUrl(), params);

            // ✅ Check status — catches IP not registered, wrong password etc
            if (!loginResultObject.optBoolean("status", false)) {
                String errorMsg = loginResultObject.optString("message", "Login failed");
                String errorCode = loginResultObject.optString("errorcode", "");
                log.error("❌ Login failed — clientCode: {} errorCode: {} message: {}",
                        clientCode, errorCode, errorMsg);
                throw new RuntimeException("Login failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            String jwtToken = loginResultObject.getJSONObject("data").getString("jwtToken");
            String refreshToken = loginResultObject.getJSONObject("data").getString("refreshToken");
            String feedToken = loginResultObject.getJSONObject("data").getString("feedToken");

            String url = routes.get("api.user.profile");
            User user = new User().parseResponse(
                    smartAPIRequestHandler.getRequest(apiKey, url, jwtToken));
            user.setAccessToken(jwtToken);
            user.setRefreshToken(refreshToken);
            user.setFeedToken(feedToken);

            log.info("✅ Login success — clientCode: {}", clientCode);
            return user;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ Login exception — clientCode: {} error: {}", clientCode, e.getMessage());
            throw new RuntimeException("Login failed: " + e.getMessage());
        }
    }

    // =========================================================================
    // renewAccessToken
    // =========================================================================
    public TokenSet renewAccessToken(String accessToken, String refreshToken) {
        try {
            String hashableText = this.apiKey + refreshToken + accessToken;
            String sha256hex = sha256Hex(hashableText);

            JSONObject params = new JSONObject();
            params.put("refreshToken", refreshToken);
            params.put("checksum", sha256hex);

            String url = routes.get("api.refresh");
            JSONObject response = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Token renewal failed");
                String errorCode = response.optString("errorcode", "");
                log.error("❌ renewAccessToken failed — errorCode: {} message: {}", errorCode, errorMsg);
                throw new RuntimeException("Token renewal failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            accessToken = response.getJSONObject("data").getString("jwtToken");
            refreshToken = response.getJSONObject("data").getString("refreshToken");

            TokenSet tokenSet = new TokenSet();
            tokenSet.setUserId(userId);
            tokenSet.setAccessToken(accessToken);
            tokenSet.setRefreshToken(refreshToken);
            return tokenSet;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ renewAccessToken exception: {}", e.getMessage());
            throw new RuntimeException("Token renewal failed: " + e.getMessage());
        }
    }

    public String sha256Hex(String str) {
        byte[] a = DigestUtils.sha256(str);
        StringBuilder sb = new StringBuilder(a.length * 2);
        for (byte b : a) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    // =========================================================================
    // getProfile
    // =========================================================================
    public User getProfile() {
        try {
            String url = routes.get("api.user.profile");
            JSONObject response = smartAPIRequestHandler.getRequest(
                    this.apiKey, url, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Failed to fetch profile");
                String errorCode = response.optString("errorcode", "");
                log.error("❌ getProfile failed — errorCode: {} message: {}", errorCode, errorMsg);
                throw new RuntimeException("Profile failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return new User().parseResponse(response);

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ getProfile exception: {}", e.getMessage());
            throw new RuntimeException("Profile failed: " + e.getMessage());
        }
    }

    // =========================================================================
    // ✅ FIXED — placeOrder with proper error messages
    // =========================================================================
    public Order placeOrder(OrderParams orderParams, String variety) {
        try {
            String url = routes.get("api.order.place");
            JSONObject params = new JSONObject();

            if (orderParams.getExchange() != null) {
                params.put("exchange", orderParams.getExchange());
            }
            if (orderParams.getTradingsymbol() != null) {
                params.put("tradingsymbol", orderParams.getTradingsymbol());
            }
            if (orderParams.getTransactiontype() != null) {
                params.put("transactiontype", orderParams.getTransactiontype());
            }
            if (orderParams.getQuantity() != null) {
                params.put("quantity", String.valueOf(orderParams.getQuantity()));
            }
            if (orderParams.getPrice() != null) {
                boolean isMarket = "MARKET".equalsIgnoreCase(orderParams.getOrdertype());
                params.put("price", isMarket ? "0" : String.valueOf(orderParams.getPrice()));
            } else {
                params.put("price", "0");
            }
            if (orderParams.getProducttype() != null) {
                params.put("producttype", orderParams.getProducttype());
            }
            if (orderParams.getOrdertype() != null) {
                params.put("ordertype", orderParams.getOrdertype());
            }
            if (orderParams.getDuration() != null) {
                params.put("duration", orderParams.getDuration());
            }
            if (orderParams.getSymboltoken() != null) {
                params.put("symboltoken", orderParams.getSymboltoken());
            }
            params.put("squareoff", orderParams.getSquareoff() != null ? orderParams.getSquareoff() : "0");
            params.put("stoploss", orderParams.getStoploss() != null ? orderParams.getStoploss() : "0");
            params.put("disclosedquantity", "0");
            if (orderParams.getTriggerprice() != null) {
                params.put("triggerprice", orderParams.getTriggerprice());
            }
            params.put("variety", variety != null ? variety : "NORMAL");

            JSONObject jsonObject = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, this.getAccessToken());

            // ✅ Check status in response
            boolean statusOk = jsonObject.optBoolean("status", false)
                    || "true".equalsIgnoreCase(jsonObject.optString("status", ""));
            if (!statusOk) {
                String errorMsg = jsonObject.optString("message", "Unknown error from Angel One");
                String errorCode = jsonObject.optString("errorcode", jsonObject.optString("errorCode", ""));
                log.error("❌ placeOrder failed — errorCode: {} message: {} full: {}", errorCode, errorMsg, jsonObject);
                throw new RuntimeException("Angel One rejected order: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            JSONObject dataObj = jsonObject.optJSONObject("data");
            if (dataObj == null || dataObj.optString("orderid", "").isBlank()) {
                log.error("❌ placeOrder returned empty data block: {}", jsonObject);
                throw new RuntimeException("Angel One did not return an Order ID: "
                        + jsonObject.optString("message", "Unknown response"));
            }

            Order order = new Order();
            order.orderId = dataObj.optString("orderid", "");
            order.uniqueOrderId = dataObj.optString("uniqueorderid", order.orderId);
            log.info("✅ Order placed: {}", order);
            return order;

        } catch (RuntimeException e) {
            throw e;
        } catch (SmartAPIException e) {
            log.error("❌ SmartAPIException in placeOrder: {}", e.getMessage());
            throw new RuntimeException("Order failed: " + e.getMessage());
        } catch (Exception e) {
            log.error("❌ Exception in placeOrder: {}", e.getMessage());
            throw new RuntimeException("Order failed: " + e.getMessage());
        }
    }

    // =========================================================================
    // ✅ FIXED — modifyOrder
    // =========================================================================
    public Order modifyOrder(String orderId, OrderParams orderParams, String variety) {
        try {
            String url = routes.get("api.order.modify");
            JSONObject params = new JSONObject();

            if (orderParams.getExchange() != null) {
                params.put("exchange", orderParams.getExchange());
            }
            if (orderParams.getTradingsymbol() != null) {
                params.put("tradingsymbol", orderParams.getTradingsymbol());
            }
            if (orderParams.getSymboltoken() != null) {
                params.put("symboltoken", orderParams.getSymboltoken());
            }
            if (orderParams.getQuantity() != null) {
                params.put("quantity", orderParams.getQuantity());
            }
            if (orderParams.getPrice() != null) {
                params.put("price", orderParams.getPrice());
            }
            if (orderParams.getProducttype() != null) {
                params.put("producttype", orderParams.getProducttype());
            }
            if (orderParams.getOrdertype() != null) {
                params.put("ordertype", orderParams.getOrdertype());
            }
            if (orderParams.getDuration() != null) {
                params.put("duration", orderParams.getDuration());
            }
            params.put("variety", variety);
            params.put("orderid", orderId);

            JSONObject jsonObject = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!jsonObject.optBoolean("status", false)) {
                String errorMsg = jsonObject.optString("message", "Modify order failed");
                String errorCode = jsonObject.optString("errorcode", "");
                log.error("❌ modifyOrder failed — errorCode: {} message: {}", errorCode, errorMsg);
                throw new RuntimeException("Modify order failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            Order order = new Order();
            order.orderId = jsonObject.getJSONObject("data").getString("orderid");
            return order;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ modifyOrder exception: {}", e.getMessage());
            throw new RuntimeException("Modify order failed: " + e.getMessage());
        }
    }

    // =========================================================================
    // ✅ FIXED — cancelOrder
    // =========================================================================
    public Order cancelOrder(String orderId, String variety) {
        try {
            String url = routes.get("api.order.cancel");
            JSONObject params = new JSONObject();
            params.put("variety", variety);
            params.put("orderid", orderId);

            JSONObject jsonObject = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!jsonObject.optBoolean("status", false)) {
                String errorMsg = jsonObject.optString("message", "Cancel order failed");
                String errorCode = jsonObject.optString("errorcode", "");
                log.error("❌ cancelOrder failed — errorCode: {} message: {}", errorCode, errorMsg);
                throw new RuntimeException("Cancel order failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            Order order = new Order();
            order.orderId = jsonObject.getJSONObject("data").getString("orderid");
            return order;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ cancelOrder exception: {}", e.getMessage());
            throw new RuntimeException("Cancel order failed: " + e.getMessage());
        }
    }

    // =========================================================================
    // ✅ FIXED — getOrderHistory
    // =========================================================================
    public JSONObject getOrderHistory() {
        try {
            String url = routes.get("api.order.book");
            JSONObject response = smartAPIRequestHandler.getRequest(
                    apiKey, url, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Failed to fetch order history");
                String errorCode = response.optString("errorcode", "");
                log.error("❌ getOrderHistory failed — errorCode: {} message: {}", errorCode, errorMsg);
                throw new RuntimeException("Order history failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            log.info("✅ Order history fetched");
            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ getOrderHistory exception: {}", e.getMessage());
            throw new RuntimeException("Order history failed: " + e.getMessage());
        }
    }

    // =========================================================================
    // getLTP
    // =========================================================================
    public JSONObject getLTP(String exchange, String tradingSymbol, String symboltoken, String apiKey, String token) {
        try {
            JSONObject params = new JSONObject();
            params.put("exchange", exchange);
            params.put("tradingsymbol", tradingSymbol);
            params.put("symboltoken", symboltoken);

            String url = routes.get("api.ltp.data");
            JSONObject response = smartAPIRequestHandler.postRequest(apiKey, url, params, token);

            return response.getJSONObject("data");
        } catch (Exception | SmartAPIException e) {
            log.error(e.getMessage());
            return null;
        }
    }

    // =========================================================================
    // getRMS
    // =========================================================================
    public JSONObject getRMS() {
        try {
            String url = routes.get("api.order.rms.data");
            JSONObject response = smartAPIRequestHandler.getRequest(
                    this.apiKey, url, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Failed to fetch RMS");
                String errorCode = response.optString("errorcode", "");
                log.error("❌ getRMS failed — errorCode: {} message: {}", errorCode, errorMsg);
                throw new RuntimeException("RMS failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response.getJSONObject("data");

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ getRMS exception: {}", e.getMessage());
            throw new RuntimeException("RMS failed: " + e.getMessage());
        }
    }

    // =========================================================================
    // ✅ FIXED — getHolding
    // =========================================================================
    public JSONObject getHolding() {
        try {
            String url = routes.get("api.order.rms.holding");
            JSONObject response = smartAPIRequestHandler.getRequest(
                    this.apiKey, url, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Failed to fetch holdings");
                String errorCode = response.optString("errorcode", "");
                log.error("❌ getHolding failed — errorCode: {} message: {}", errorCode, errorMsg);
                throw new RuntimeException("Holdings failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ getHolding exception: {}", e.getMessage());
            throw new RuntimeException("Holdings failed: " + e.getMessage());
        }
    }

    // =========================================================================
    // ✅ FIXED — getAllHolding
    // =========================================================================
    public JSONObject getAllHolding() throws SmartAPIException, IOException {
        try {
            String url = routes.get("api.order.rms.AllHolding");
            JSONObject response = smartAPIRequestHandler.getRequest(
                    this.apiKey, url, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Failed to fetch all holdings");
                String errorCode = response.optString("errorcode", "");
                log.error("❌ getAllHolding failed — errorCode: {} message: {}", errorCode, errorMsg);
                throw new RuntimeException("All holdings failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (SmartAPIException ex) {
            log.error("{} while getting all holdings {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in getting all holdings %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while getting all holdings {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in getting all holdings %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    // =========================================================================
    // getPosition
    // =========================================================================
    public JSONObject getPosition() {
        try {
            String url = routes.get("api.order.rms.position");
            JSONObject response = smartAPIRequestHandler.getRequest(
                    this.apiKey, url, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Failed to fetch positions");
                String errorCode = response.optString("errorcode", "");
                log.error("❌ getPosition failed — errorCode: {} message: {}", errorCode, errorMsg);
                throw new RuntimeException("Positions failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ getPosition exception: {}", e.getMessage());
            throw new RuntimeException("Positions failed: " + e.getMessage());
        }
    }

    // =========================================================================
    // convertPosition
    // =========================================================================
    public JSONObject convertPosition(JSONObject params) {
        try {
            String url = routes.get("api.order.rms.position.convert");
            JSONObject response = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Convert position failed");
                String errorCode = response.optString("errorcode", "");
                log.error("❌ convertPosition failed — errorCode: {} message: {}", errorCode, errorMsg);
                throw new RuntimeException("Convert position failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ convertPosition exception: {}", e.getMessage());
            throw new RuntimeException("Convert position failed: " + e.getMessage());
        }
    }

    // =========================================================================
    // GTT methods — kept same structure, added proper errors
    // =========================================================================
    public Gtt gttCreateRule(GttParams gttParams) {
        try {
            String url = routes.get("api.gtt.create");
            JSONObject params = new JSONObject();
            if (gttParams.tradingsymbol != null) {
                params.put("tradingsymbol", gttParams.tradingsymbol);
            }
            if (gttParams.symboltoken != null) {
                params.put("symboltoken", gttParams.symboltoken);
            }
            if (gttParams.exchange != null) {
                params.put("exchange", gttParams.exchange);
            }
            if (gttParams.transactiontype != null) {
                params.put("transactiontype", gttParams.transactiontype);
            }
            if (gttParams.producttype != null) {
                params.put("producttype", gttParams.producttype);
            }
            if (gttParams.price != null) {
                params.put("price", gttParams.price);
            }
            if (gttParams.qty != null) {
                params.put("qty", gttParams.qty);
            }
            if (gttParams.triggerprice != null) {
                params.put("triggerprice", gttParams.triggerprice);
            }
            if (gttParams.disclosedqty != null) {
                params.put("disclosedqty", gttParams.disclosedqty);
            }
            if (gttParams.timeperiod != null) {
                params.put("timeperiod", gttParams.timeperiod);
            }

            JSONObject jsonObject = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!jsonObject.optBoolean("status", false)) {
                String errorMsg = jsonObject.optString("message", "GTT create failed");
                String errorCode = jsonObject.optString("errorcode", "");
                throw new RuntimeException("GTT create failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            Gtt gtt = new Gtt();
            gtt.id = jsonObject.getJSONObject("data").getInt("id");
            return gtt;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ gttCreateRule exception: {}", e.getMessage());
            throw new RuntimeException("GTT create failed: " + e.getMessage());
        }
    }

    public Gtt gttModifyRule(Integer id, GttParams gttParams) {
        try {
            String url = routes.get("api.gtt.modify");
            JSONObject params = new JSONObject();
            if (gttParams.symboltoken != null) {
                params.put("symboltoken", gttParams.symboltoken);
            }
            if (gttParams.exchange != null) {
                params.put("exchange", gttParams.exchange);
            }
            if (gttParams.price != null) {
                params.put("price", gttParams.price);
            }
            if (gttParams.qty != null) {
                params.put("qty", gttParams.qty);
            }
            if (gttParams.triggerprice != null) {
                params.put("triggerprice", gttParams.triggerprice);
            }
            if (gttParams.disclosedqty != null) {
                params.put("disclosedqty", gttParams.disclosedqty);
            }
            if (gttParams.timeperiod != null) {
                params.put("timeperiod", gttParams.timeperiod);
            }
            params.put("id", id);

            JSONObject jsonObject = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!jsonObject.optBoolean("status", false)) {
                String errorMsg = jsonObject.optString("message", "GTT modify failed");
                String errorCode = jsonObject.optString("errorcode", "");
                throw new RuntimeException("GTT modify failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            Gtt gtt = new Gtt();
            gtt.id = jsonObject.getJSONObject("data").getInt("id");
            return gtt;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ gttModifyRule exception: {}", e.getMessage());
            throw new RuntimeException("GTT modify failed: " + e.getMessage());
        }
    }

    public Gtt gttCancelRule(Integer id, String symboltoken, String exchange) {
        try {
            JSONObject params = new JSONObject();
            params.put("id", id);
            params.put("symboltoken", symboltoken);
            params.put("exchange", exchange);

            String url = routes.get("api.gtt.cancel");
            JSONObject jsonObject = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!jsonObject.optBoolean("status", false)) {
                String errorMsg = jsonObject.optString("message", "GTT cancel failed");
                String errorCode = jsonObject.optString("errorcode", "");
                throw new RuntimeException("GTT cancel failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            Gtt gtt = new Gtt();
            gtt.id = jsonObject.getJSONObject("data").getInt("id");
            return gtt;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ gttCancelRule exception: {}", e.getMessage());
            throw new RuntimeException("GTT cancel failed: " + e.getMessage());
        }
    }

    public JSONObject gttRuleDetails(Integer id) {
        try {
            JSONObject params = new JSONObject();
            params.put("id", id);

            String url = routes.get("api.gtt.details");
            JSONObject response = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "GTT details failed");
                String errorCode = response.optString("errorcode", "");
                throw new RuntimeException("GTT details failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response.getJSONObject("data");

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ gttRuleDetails exception: {}", e.getMessage());
            throw new RuntimeException("GTT details failed: " + e.getMessage());
        }
    }

    public JSONArray gttRuleList(List<String> status, Integer page, Integer count) {
        try {
            JSONObject params = new JSONObject();
            params.put("status", status);
            params.put("page", page);
            params.put("count", count);

            String url = routes.get("api.gtt.list");
            JSONObject response = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "GTT list failed");
                String errorCode = response.optString("errorcode", "");
                throw new RuntimeException("GTT list failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response.getJSONArray("data");

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ gttRuleList exception: {}", e.getMessage());
            throw new RuntimeException("GTT list failed: " + e.getMessage());
        }
    }

    public JSONArray candleData(JSONObject params) {
        try {
            String url = routes.get("api.candle.data");
            JSONObject response = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Candle data failed");
                String errorCode = response.optString("errorcode", "");
                throw new RuntimeException("Candle data failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response.getJSONArray("data");

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ candleData exception: {}", e.getMessage());
            throw new RuntimeException("Candle data failed: " + e.getMessage());
        }
    }

    public JSONArray oiData(JSONObject params) {
        try {
            String url = routes.get("api.oi.data");
            JSONObject response = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "OI data failed");
                String errorCode = response.optString("errorcode", "");
                throw new RuntimeException("OI data failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response.getJSONArray("data");

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ oiData exception: {}", e.getMessage());
            throw new RuntimeException("OI data failed: " + e.getMessage());
        }
    }

    public String getSearchScrip(JSONObject payload, Long pyUserId) throws SmartAPIException, IOException {
        try {
            String url = routes.get("api.search.script.data");
            Map<String, String> map = pyBrokerAccountService.getLatestAccessToken(pyUserId);
            return smartAPIRequestHandler.postRequestJSONObject(
                    map.get("apiKey"), url, payload,
                    map.get("accessToken"));
        } catch (IOException ex) {
            log.error("{} while getSearchScrip {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in getSearchScrip %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        } catch (JSONException ex) {
            log.error("{} while getSearchScrip {}", JSON_EXCEPTION_OCCURRED, ex.getMessage());
            throw new JSONException(String.format("%s in getSearchScrip %s",
                    JSON_EXCEPTION_ERROR_MSG, ex.getMessage()));
        } catch (SmartAPIException ex) {
            log.error("{} while getSearchScrip {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in getSearchScrip %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        }
    }

    public JSONObject marketData(JSONObject params) throws SmartAPIException, IOException {
        try {
            String url = routes.get("api.market.data");
            JSONObject response = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Market data failed");
                String errorCode = response.optString("errorcode", "");
                throw new RuntimeException("Market data failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response.getJSONObject("data");

        } catch (RuntimeException e) {
            throw e;
        } catch (SmartAPIException ex) {
            log.error("{} while marketData {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in marketData %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while marketData {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in marketData %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject logout() {
        try {
            String url = routes.get("api.user.logout");
            JSONObject params = new JSONObject();
            params.put("clientcode", this.userId);
            JSONObject response = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, params, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Logout failed");
                log.warn("⚠️ Logout failed: {}", errorMsg);
            }

            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception | SmartAPIException e) {
            log.error("❌ logout exception: {}", e.getMessage());
            throw new RuntimeException("Logout failed: " + e.getMessage());
        }
    }

    public JSONObject getMarginDetails(List<MarginParams> marginParams)
            throws IOException, SmartAPIException {
        try {
            JSONArray positionsArray = new JSONArray();
            for (MarginParams params : marginParams) {
                JSONObject position = new JSONObject();
                position.put("exchange", params.exchange);
                position.put("qty", params.quantity);
                position.put("price", params.price);
                position.put("productType", params.productType);
                position.put("token", params.token);
                position.put("tradeType", params.tradeType);
                positionsArray.put(position);
            }

            JSONObject requestBody = new JSONObject();
            requestBody.put("positions", positionsArray);

            String url = routes.get("api.margin.batch");
            JSONObject response = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, requestBody, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Margin details failed");
                String errorCode = response.optString("errorcode", "");
                throw new RuntimeException("Margin details failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (SmartAPIException ex) {
            log.error("{} while getMarginDetails {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s while getMarginDetails %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while getMarginDetails {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s while getMarginDetails %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject getIndividualOrderDetails(String orderId)
            throws IOException, SmartAPIException {
        try {
            String url = routes.get("api.individual.order").concat(orderId);
            JSONObject response = smartAPIRequestHandler.getRequest(
                    this.apiKey, url, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Failed to fetch order");
                String errorCode = response.optString("errorcode", "");
                log.error("❌ getIndividualOrderDetails failed — errorCode: {} message: {}",
                        errorCode, errorMsg);
                throw new RuntimeException("Order details failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (SmartAPIException ex) {
            log.error("{} while getIndividualOrderDetails {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in getIndividualOrderDetails %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while getIndividualOrderDetails {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in getIndividualOrderDetails %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject estimateCharges(List<EstimateChargesParams> estimateChargesParams)
            throws IOException, SmartAPIException {
        try {
            JSONArray ordersArray = new JSONArray();
            for (EstimateChargesParams params : estimateChargesParams) {
                JSONObject order = new JSONObject();
                order.put("product_type", params.product_type);
                order.put("transaction_type", params.transaction_type);
                order.put("quantity", params.quantity);
                order.put("price", params.price);
                order.put("exchange", params.exchange);
                order.put("symbol_name", params.symbol_name);
                order.put("token", params.token);
                ordersArray.put(order);
            }

            JSONObject requestBody = new JSONObject();
            requestBody.put("orders", ordersArray);

            String url = routes.get("api.estimateCharges");
            JSONObject response = smartAPIRequestHandler.postRequest(
                    this.apiKey, url, requestBody, accessToken);

            if (!response.optBoolean("status", false)) {
                String errorMsg = response.optString("message", "Estimate charges failed");
                String errorCode = response.optString("errorcode", "");
                throw new RuntimeException("Estimate charges failed: " + errorMsg
                        + (errorCode.isBlank() ? "" : " (Code: " + errorCode + ")"));
            }

            return response;

        } catch (RuntimeException e) {
            throw e;
        } catch (SmartAPIException ex) {
            log.error("{} while estimateCharges {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s while estimateCharges %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while estimateCharges {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s while estimateCharges %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject verifyDis(JSONObject params) throws SmartAPIException, IOException {
        try {
            String url = routes.get("api.verifyDis");
            return smartAPIRequestHandler.postRequest(this.apiKey, url, params, accessToken);
        } catch (SmartAPIException ex) {
            log.error("{} while verifyDis {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in verifyDis %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while verifyDis {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in verifyDis %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        } catch (JSONException ex) {
            log.error("{} while verifyDis {}", JSON_EXCEPTION_OCCURRED, ex.getMessage());
            throw new JSONException(String.format("%s in verifyDis %s",
                    JSON_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject generateTPIN(JSONObject params) throws SmartAPIException, IOException {
        try {
            String url = routes.get("api.generateTPIN");
            return smartAPIRequestHandler.postRequest(this.apiKey, url, params, accessToken);
        } catch (SmartAPIException ex) {
            log.error("{} while generateTPIN {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in generateTPIN %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while generateTPIN {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in generateTPIN %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        } catch (JSONException ex) {
            log.error("{} while generateTPIN {}", JSON_EXCEPTION_OCCURRED, ex.getMessage());
            throw new JSONException(String.format("%s in generateTPIN %s",
                    JSON_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject getTranStatus(JSONObject params) throws SmartAPIException, IOException {
        try {
            String url = routes.get("api.getTranStatus");
            return smartAPIRequestHandler.postRequest(this.apiKey, url, params, accessToken);
        } catch (SmartAPIException ex) {
            log.error("{} while getTranStatus {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in getTranStatus %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while getTranStatus {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in getTranStatus %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        } catch (JSONException ex) {
            log.error("{} while getTranStatus {}", JSON_EXCEPTION_OCCURRED, ex.getMessage());
            throw new JSONException(String.format("%s in getTranStatus %s",
                    JSON_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject optionGreek(JSONObject params) throws SmartAPIException, IOException {
        try {
            String url = routes.get("api.optionGreek");
            return smartAPIRequestHandler.postRequest(this.apiKey, url, params, accessToken);
        } catch (SmartAPIException ex) {
            log.error("{} while optionGreek {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in optionGreek %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while optionGreek {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in optionGreek %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        } catch (JSONException ex) {
            log.error("{} while optionGreek {}", JSON_EXCEPTION_OCCURRED, ex.getMessage());
            throw new JSONException(String.format("%s in optionGreek %s",
                    JSON_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject gainersLosers(JSONObject params) throws SmartAPIException, IOException {
        try {
            String url = routes.get("api.gainersLosers");
            return smartAPIRequestHandler.postRequest(this.apiKey, url, params, accessToken);
        } catch (SmartAPIException ex) {
            log.error("{} while gainersLosers {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in gainersLosers %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while gainersLosers {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in gainersLosers %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        } catch (JSONException ex) {
            log.error("{} while gainersLosers {}", JSON_EXCEPTION_OCCURRED, ex.getMessage());
            throw new JSONException(String.format("%s in gainersLosers %s",
                    JSON_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject putCallRatio() throws IOException, SmartAPIException {
        try {
            String url = routes.get("api.putCallRatio");
            return smartAPIRequestHandler.getRequest(this.apiKey, url, accessToken);
        } catch (SmartAPIException ex) {
            log.error("{} while putCallRatio {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in putCallRatio %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while putCallRatio {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in putCallRatio %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        } catch (JSONException ex) {
            log.error("{} while putCallRatio {}", JSON_EXCEPTION_OCCURRED, ex.getMessage());
            throw new JSONException(String.format("%s in putCallRatio %s",
                    JSON_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject nseIntraday() throws IOException, SmartAPIException {
        try {
            String url = routes.get("api.nseIntraday");
            return smartAPIRequestHandler.getRequest(this.apiKey, url, accessToken);
        } catch (SmartAPIException ex) {
            log.error("{} while nseIntraday {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in nseIntraday %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while nseIntraday {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in nseIntraday %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        } catch (JSONException ex) {
            log.error("{} while nseIntraday {}", JSON_EXCEPTION_OCCURRED, ex.getMessage());
            throw new JSONException(String.format("%s in nseIntraday %s",
                    JSON_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject bseIntraday() throws IOException, SmartAPIException {
        try {
            String url = routes.get("api.bseIntraday");
            return smartAPIRequestHandler.getRequest(this.apiKey, url, accessToken);
        } catch (SmartAPIException ex) {
            log.error("{} while bseIntraday {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in bseIntraday %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while bseIntraday {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in bseIntraday %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        } catch (JSONException ex) {
            log.error("{} while bseIntraday {}", JSON_EXCEPTION_OCCURRED, ex.getMessage());
            throw new JSONException(String.format("%s in bseIntraday %s",
                    JSON_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }

    public JSONObject oIBuildup(JSONObject params) throws SmartAPIException, IOException {
        try {
            String url = routes.get("api.oIBuildup");
            return smartAPIRequestHandler.postRequest(this.apiKey, url, params, accessToken);
        } catch (SmartAPIException ex) {
            log.error("{} while oIBuildup {}", SMART_API_EXCEPTION_OCCURRED, ex.toString());
            throw new SmartAPIException(String.format("%s in oIBuildup %s",
                    SMART_API_EXCEPTION_ERROR_MSG, ex));
        } catch (IOException ex) {
            log.error("{} while oIBuildup {}", IO_EXCEPTION_OCCURRED, ex.getMessage());
            throw new IOException(String.format("%s in oIBuildup %s",
                    IO_EXCEPTION_ERROR_MSG, ex.getMessage()));
        } catch (JSONException ex) {
            log.error("{} while oIBuildup {}", JSON_EXCEPTION_OCCURRED, ex.getMessage());
            throw new JSONException(String.format("%s in oIBuildup %s",
                    JSON_EXCEPTION_ERROR_MSG, ex.getMessage()));
        }
    }
}
