package com.py.utils;

import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.concurrent.CompletableFuture;

@Service
public class ProfitmartMicroserviceClient {

    private final WebClient.Builder webClientBuilder;
    private static final Logger log = LoggerFactory.getLogger(ProfitmartMicroserviceClient.class);

    public ProfitmartMicroserviceClient(WebClient.Builder webClientBuilder) {
        this.webClientBuilder = webClientBuilder;
    }

    private WebClient clientFor(String baseUrl) {
        return webClientBuilder
                .clone()
                .baseUrl(baseUrl)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .codecs(configurer -> configurer
                .defaultCodecs()
                .maxInMemorySize(10 * 1024 * 1024))
                .build();
    }

    // ─── common helpers ──────────────────────────────────────────────────────
    private JSONObject blockObject(String baseUrl, String uri, JSONObject body) {
        String response = clientFor(baseUrl).post()
                .uri(uri)
                .bodyValue(body.toString())
                .retrieve()
                .onStatus(HttpStatusCode::isError, res
                        -> res.bodyToMono(String.class).map(err -> {
                    log.error("Profitmart error | uri={} | error={}", uri, err);
                    return new RuntimeException("Profitmart call failed: " + err);
                }))
                .bodyToMono(String.class)
                .block();
        return new JSONObject(response);
    }

    private CompletableFuture<JSONObject> asyncObject(String baseUrl, String uri, JSONObject body) {
        return clientFor(baseUrl).post()
                .uri(uri)
                .bodyValue(body.toString())
                .retrieve()
                .onStatus(HttpStatusCode::isError, res
                        -> res.bodyToMono(String.class).map(err -> {
                    log.error("Profitmart error | uri={} | error={}", uri, err);
                    return new RuntimeException("Profitmart call failed: " + err);
                }))
                .bodyToMono(String.class)
                .map(JSONObject::new)
                .toFuture();
    }

    private CompletableFuture<JSONArray> asyncArray(String baseUrl, String uri, JSONObject body) {
        return clientFor(baseUrl).post()
                .uri(uri)
                .bodyValue(body.toString())
                .retrieve()
                .onStatus(HttpStatusCode::isError, res
                        -> res.bodyToMono(String.class).map(err -> {
                    log.error("Profitmart error | uri={} | error={}", uri, err);
                    return new RuntimeException("Profitmart call failed: " + err);
                }))
                .bodyToMono(String.class)
                .map(JSONArray::new)
                .toFuture();
    }

    // ─── LOGIN ───────────────────────────────────────────────────────────────
    public JSONObject login(String baseUrl, String userId, String code, String checksum) {
        log.info("Profitmart login | baseUrl={} userId={} code={}", baseUrl, userId, code);

        JSONObject body = new JSONObject();
        if (userId != null && !userId.isBlank()) {
            body.put("userId", userId);
        }
        body.put("code", code);
        body.put("checksum", checksum);

        JSONObject response = blockObject(baseUrl, "/api/profitmart/login", body);
        log.info("Profitmart login success | code={} | stat={}", code, response.optString("stat"));
        return response;
    }

    public JSONObject login(String baseUrl, String code, String checksum) {
        return login(baseUrl, null, code, checksum);
    }

    public JSONObject loginWithCredentials(String baseUrl, String userId, String password,
                                           String twoFa, String vendorCode, String apiSecret, String imei) {
        log.info("Profitmart credentials login | baseUrl={} userId={}", baseUrl, userId);

        JSONObject body = new JSONObject();
        body.put("userId", userId != null ? userId : "");
        body.put("password", password != null ? password : "");
        body.put("twoFa", twoFa != null ? twoFa : "");
        body.put("vendorCode", vendorCode != null ? vendorCode : "");
        body.put("apiSecret", apiSecret != null ? apiSecret : "");
        body.put("imei", imei != null ? imei : "EasyTrade");

        JSONObject response = blockObject(baseUrl, "/api/profitmart/login", body);
        log.info("Profitmart credentials login response | userId={} | stat={}", userId, response.optString("stat"));
        return response;
    }

    // ─── LOGOUT ──────────────────────────────────────────────────────────────
    public JSONObject logout(String baseUrl, String userId, String susertoken) {
        log.info("Profitmart logout | baseUrl={} userId={}", baseUrl, userId);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);

        JSONObject response = blockObject(baseUrl, "/api/profitmart/logout", body);
        log.info("Profitmart logout success | userId={}", userId);
        return response;
    }

    // ─── PLACE ORDER ─────────────────────────────────────────────────────────
    // API ref: POST /NorenWClientAPI/PlaceOrder
    //
    // Key fixes vs original:
    //   ✅ actid   — required by API spec, same value as uid for retail accounts
    //   ✅ trantype — API expects "B" or "S", caller must pass correct value
    //   ✅ prctyp  — API values: LMT / MKT / SL-LMT / SL-MKT / DS / 2L / 3L
    //   ✅ prd     — API values: C / M / H / I / B / F / S / P
    //   ✅ amo     — only send when value is "Yes"; omit field entirely otherwise
    //   ✅ ret     — API values: DAY / EOS / IOC
    // ─────────────────────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> placeOrder(
            String baseUrl,
            String userId, // uid  — logged-in user id  (also used as actid)
            String susertoken, // session token from login
            String exchange, // exch — NSE / NFO / BSE / MCX / CDS / BFO / BCD
            String tradingSymbol, // tsym — unique contract id (URL-encode if needed)
            String tranType, // trantype — "B" (BUY) or "S" (SELL)
            int quantity, // qty
            int discloseQty, // dscqty — max 10% NSE, 50% MCX; pass 0 if unused
            String priceType, // prctyp — LMT / MKT / SL-LMT / SL-MKT
            double price, // prc
            Double triggerPrice, // trgprc — required for SL / SL-M orders; null otherwise
            String productType, // prd — C/M/H/I/B/F/S/P
            String retention, // ret — DAY / EOS / IOC
            String remarks, // remarks — user tag; send "" if unused
            String amo // amo — pass "Yes" for AMO orders; pass null to omit
    ) {
        log.info("Profitmart place order | baseUrl={} tsym={} qty={} side={} prctyp={} prd={}",
                baseUrl, tradingSymbol, quantity, tranType, priceType, productType);

        JSONObject body = new JSONObject();

        // ── mandatory fields ──────────────────────────────────────────────────
        body.put("uid", userId);
        body.put("actid", userId);          // ✅ required by API; same as uid for retail
        body.put("exch", exchange);
        body.put("tsym", tradingSymbol);
        body.put("qty", quantity);
        body.put("prc", price);
        body.put("prd", productType);     // C / M / H / I / B / F / S / P
        body.put("trantype", tranType);        // ✅ "B" or "S"
        body.put("prctyp", priceType);       // LMT / MKT / SL-LMT / SL-MKT
        body.put("ret", retention != null ? retention : "DAY");
        body.put("susertoken", susertoken);

        // ── optional fields ───────────────────────────────────────────────────
        if (triggerPrice != null && triggerPrice > 0) {
            body.put("trgprc", triggerPrice);   // only for SL / SL-M
        }

        if (discloseQty > 0) {
            body.put("dscqty", discloseQty);
        }

        if (remarks != null && !remarks.isEmpty()) {
            body.put("remarks", remarks);
        }

        // ✅ amo: API says send "Yes" for AMO; do NOT send field if not AMO
        if ("Yes".equalsIgnoreCase(amo)) {
            body.put("amo", "Yes");
        }

        return asyncObject(baseUrl, "/api/profitmart/order/place", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart place order failed | tsym={} | error={}",
                                tradingSymbol, ex.getMessage());
                    } else {
                        log.info("Profitmart place order success | tsym={} | stat={} | norenordno={}",
                                tradingSymbol,
                                res.optString("stat"),
                                res.optString("norenordno"));
                    }
                });
    }

    // ─── MODIFY ORDER ────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> modifyOrder(String baseUrl, String userId,
            String susertoken, String orderNo, String exchange,
            String tradingSymbol, int newQuantity, String newPriceType,
            double newPrice, Double newTriggerPrice, String retention, String amo) {

        log.info("Profitmart modify order | baseUrl={} orderNo={} qty={} price={}",
                baseUrl, orderNo, newQuantity, newPrice);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);
        body.put("orderNo", orderNo);
        body.put("exchange", exchange);
        body.put("tradingSymbol", tradingSymbol);
        body.put("newQuantity", newQuantity);
        body.put("newPriceType", newPriceType);
        body.put("newPrice", newPrice);

        if (newTriggerPrice != null && newTriggerPrice > 0) {
            body.put("newTriggerPrice", newTriggerPrice);
        }

        body.put("retention", retention != null ? retention : "DAY");

        // ✅ same amo rule — only send if "Yes"
        if ("Yes".equalsIgnoreCase(amo)) {
            body.put("amo", "Yes");
        }

        return asyncObject(baseUrl, "/api/profitmart/order/modify", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart modify order failed | orderNo={} | error={}",
                                orderNo, ex.getMessage());
                    } else {
                        log.info("Profitmart modify order success | orderNo={}", orderNo);
                    }
                });
    }

    // ─── CANCEL ORDER ────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> cancelOrder(String baseUrl, String userId,
            String susertoken, String orderNo) {

        log.info("Profitmart cancel order | baseUrl={} orderNo={}", baseUrl, orderNo);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);
        body.put("orderNo", orderNo);

        return asyncObject(baseUrl, "/api/profitmart/order/cancel", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart cancel order failed | orderNo={} | error={}",
                                orderNo, ex.getMessage());
                    } else {
                        log.info("Profitmart cancel order success | orderNo={}", orderNo);
                    }
                });
    }

    // ─── ORDER BOOK ──────────────────────────────────────────────────────────
    public CompletableFuture<JSONArray> getOrderBook(String baseUrl,
            String userId, String susertoken) {

        log.info("Profitmart order book | baseUrl={} userId={}", baseUrl, userId);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);

        return asyncArray(baseUrl, "/api/profitmart/order/book", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart order book failed | userId={} | error={}",
                                userId, ex.getMessage());
                    } else {
                        log.info("Profitmart order book success | userId={} | count={}",
                                userId, res.length());
                    }
                });
    }

    // ─── TRADE BOOK ──────────────────────────────────────────────────────────
    public CompletableFuture<JSONArray> getTradeBook(String baseUrl,
            String userId, String susertoken) {

        log.info("Profitmart trade book | baseUrl={} userId={}", baseUrl, userId);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);

        return asyncArray(baseUrl, "/api/profitmart/order/trades", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart trade book failed | userId={} | error={}",
                                userId, ex.getMessage());
                    } else {
                        log.info("Profitmart trade book success | userId={} | count={}",
                                userId, res.length());
                    }
                });
    }

    // ─── ORDER HISTORY ───────────────────────────────────────────────────────
    public CompletableFuture<JSONArray> getOrderHistory(String baseUrl,
            String userId, String susertoken, String orderNo) {

        log.info("Profitmart order history | baseUrl={} orderNo={}", baseUrl, orderNo);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);
        body.put("orderNo", orderNo);

        return asyncArray(baseUrl, "/api/profitmart/order/history", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart order history failed | orderNo={} | error={}",
                                orderNo, ex.getMessage());
                    } else {
                        log.info("Profitmart order history success | orderNo={} | count={}",
                                orderNo, res.length());
                    }
                });
    }

    // ─── HOLDINGS ────────────────────────────────────────────────────────────
    public CompletableFuture<JSONArray> getHoldings(String baseUrl,
            String userId, String susertoken) {

        log.info("Profitmart holdings | baseUrl={} userId={}", baseUrl, userId);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);

        return asyncArray(baseUrl, "/api/profitmart/holdings", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart holdings failed | userId={} | error={}",
                                userId, ex.getMessage());
                    } else {
                        log.info("Profitmart holdings success | userId={} | count={}",
                                userId, res.length());
                    }
                });
    }

    // ─── POSITIONS ───────────────────────────────────────────────────────────
    public CompletableFuture<JSONArray> getPositions(String baseUrl,
            String userId, String susertoken) {

        log.info("Profitmart positions | baseUrl={} userId={}", baseUrl, userId);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);

        return asyncArray(baseUrl, "/api/profitmart/positions", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart positions failed | userId={} | error={}",
                                userId, ex.getMessage());
                    } else {
                        log.info("Profitmart positions success | userId={} | count={}",
                                userId, res.length());
                    }
                });
    }

    // ─── LIMITS ──────────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> getLimits(String baseUrl,
            String userId, String susertoken) {

        log.info("Profitmart limits | baseUrl={} userId={}", baseUrl, userId);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);

        return asyncObject(baseUrl, "/api/profitmart/limits", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart limits failed | userId={} | error={}",
                                userId, ex.getMessage());
                    } else {
                        log.info("Profitmart limits success | userId={} | cash={}",
                                userId, res.optString("cash"));
                    }
                });
    }

    // ─── SEARCH SCRIP ────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> searchScrip(String baseUrl,
            String userId, String susertoken,
            String exchange, String searchText) {

        log.info("Profitmart search scrip | baseUrl={} exchange={} text={}",
                baseUrl, exchange, searchText);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);
        body.put("exchange", exchange);
        body.put("searchText", searchText);

        return asyncObject(baseUrl, "/api/profitmart/search", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart search failed | text={} | error={}",
                                searchText, ex.getMessage());
                    } else {
                        log.info("Profitmart search success | text={}", searchText);
                    }
                });
    }

    // ─── QUOTES ──────────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> getQuotes(String baseUrl,
            String userId, String susertoken,
            String exchange, String token) {

        log.info("Profitmart quotes | baseUrl={} exchange={} token={}",
                baseUrl, exchange, token);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);
        body.put("exchange", exchange);
        body.put("token", token);

        return asyncObject(baseUrl, "/api/profitmart/quotes", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart quotes failed | token={} | error={}",
                                token, ex.getMessage());
                    } else {
                        log.info("Profitmart quotes success | token={} | ltp={}",
                                token, res.optString("lp"));
                    }
                });
    }

    // ─── SECURITY INFO ───────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> getSecurityInfo(String baseUrl,
            String userId, String susertoken,
            String exchange, String token) {

        log.info("Profitmart security info | baseUrl={} exchange={} token={}",
                baseUrl, exchange, token);

        JSONObject body = new JSONObject();
        body.put("userId", userId);
        body.put("susertoken", susertoken);
        body.put("exchange", exchange);
        body.put("token", token);

        return asyncObject(baseUrl, "/api/profitmart/security-info", body)
                .whenComplete((res, ex) -> {
                    if (ex != null) {
                        log.error("Profitmart security info failed | token={} | error={}",
                                token, ex.getMessage());
                    } else {
                        log.info("Profitmart security info success | token={} | tsym={}",
                                token, res.optString("tsym"));
                    }
                });
    }
}
