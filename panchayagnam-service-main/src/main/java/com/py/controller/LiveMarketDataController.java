package com.py.controller;

import com.py.brokers.angel.client.Routes;
import com.py.brokers.angel.http.ApiRequestHandler;
import com.py.common.enums.BrokerType;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.*;

@RestController
@RequestMapping("/api/v1/market")
public class LiveMarketDataController {

    private static final Logger log = LoggerFactory.getLogger(LiveMarketDataController.class);

    @Autowired(required = false)
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @Autowired(required = false)
    private ApiRequestHandler apiRequestHandler;

    @Autowired(required = false)
    private Routes routes;

    @Autowired(required = false)
    private com.py.trading.service.PaperTradingService paperTradingService;

    @Autowired(required = false)
    private org.springframework.core.env.Environment environment;

    private static final Set<String> NSE_INDICES = Set.of(
            "NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "INDIAVIX");
    private static final Set<String> BSE_INDICES = Set.of("SENSEX", "BANKEX");

    private static final List<String> DEFAULT_SYMBOLS = List.of(
            "NIFTY", "BANKNIFTY", "SENSEX", "INDIAVIX", "FINNIFTY", "MIDCPNIFTY",
            "RELIANCE", "HDFCBANK", "INFY", "TCS", "SBIN", "ICICIBANK",
            "BHARTIARTL", "ITC", "LT", "KOTAKBANK", "AXISBANK", "BAJFINANCE",
            "TATAMOTORS", "MARUTI", "SUNPHARMA", "ADANIENT", "WIPRO",
            "HCLTECH", "TITAN", "TATASTEEL", "IDEA", "YESBANK"
    );

    private static final Map<String, String> ANGEL_NSE_TOKENS = new LinkedHashMap<>();
    static {
        ANGEL_NSE_TOKENS.put("99926000", "NIFTY");
        ANGEL_NSE_TOKENS.put("99926009", "BANKNIFTY");
        ANGEL_NSE_TOKENS.put("99926037", "FINNIFTY");
        ANGEL_NSE_TOKENS.put("99926074", "MIDCPNIFTY");
        ANGEL_NSE_TOKENS.put("99926017", "INDIAVIX");
        ANGEL_NSE_TOKENS.put("2885", "RELIANCE");
        ANGEL_NSE_TOKENS.put("1333", "HDFCBANK");
        ANGEL_NSE_TOKENS.put("1594", "INFY");
        ANGEL_NSE_TOKENS.put("11536", "TCS");
        ANGEL_NSE_TOKENS.put("3045", "SBIN");
        ANGEL_NSE_TOKENS.put("4963", "ICICIBANK");
        ANGEL_NSE_TOKENS.put("10604", "BHARTIARTL");
        ANGEL_NSE_TOKENS.put("1660", "ITC");
        ANGEL_NSE_TOKENS.put("11483", "LT");
        ANGEL_NSE_TOKENS.put("1922", "KOTAKBANK");
        ANGEL_NSE_TOKENS.put("5900", "AXISBANK");
        ANGEL_NSE_TOKENS.put("317", "BAJFINANCE");
        ANGEL_NSE_TOKENS.put("3456", "TATAMOTORS");
        ANGEL_NSE_TOKENS.put("10999", "MARUTI");
        ANGEL_NSE_TOKENS.put("3351", "SUNPHARMA");
        ANGEL_NSE_TOKENS.put("25", "ADANIENT");
        ANGEL_NSE_TOKENS.put("3787", "WIPRO");
        ANGEL_NSE_TOKENS.put("7229", "HCLTECH");
        ANGEL_NSE_TOKENS.put("3506", "TITAN");
        ANGEL_NSE_TOKENS.put("3499", "TATASTEEL");
        ANGEL_NSE_TOKENS.put("14366", "IDEA");
        ANGEL_NSE_TOKENS.put("11915", "YESBANK");
    }

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(4))
            .build();

    private final ExecutorService executor = Executors.newFixedThreadPool(10);

    private volatile Map<String, Map<String, Object>> cachedDefaultQuotes = new ConcurrentHashMap<>();
    private volatile long lastCacheEpochMs = 0L;
    private volatile String lastSource = "LIVE_NSE";
    private static final long CACHE_TTL_MS = 3500L;

    @GetMapping("/mode")
    public ResponseEntity<Map<String, Object>> getTradingMode() {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("paperTradingEnabled", paperTradingService != null && paperTradingService.isPaperTradingEnabled());
        body.put("liveTradingEnabled", paperTradingService == null || paperTradingService.isLiveTradingEnabled());
        body.put("activeProfiles", environment != null ? Arrays.asList(environment.getActiveProfiles()) : List.of());
        return ResponseEntity.ok(body);
    }

    @GetMapping("/quotes")
    public ResponseEntity<Map<String, Object>> getLiveQuotes(
            @RequestParam(required = false) String symbols) {

        Map<String, Map<String, Object>> result;

        if (symbols == null || symbols.isBlank()) {
            long now = System.currentTimeMillis();
            if (now - lastCacheEpochMs > CACHE_TTL_MS || cachedDefaultQuotes.isEmpty()) {
                Map<String, Map<String, Object>> fresh = fetchAllLiveQuotes(DEFAULT_SYMBOLS);
                if (!fresh.isEmpty()) {
                    cachedDefaultQuotes = fresh;
                    lastCacheEpochMs = now;
                }
            }
            result = cachedDefaultQuotes;
        } else {
            List<String> requested = new ArrayList<>();
            for (String raw : symbols.split(",")) {
                String clean = raw.trim().toUpperCase();
                if (!clean.isEmpty()) requested.add(clean);
            }
            result = fetchAllLiveQuotes(requested);
        }

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("status", "SUCCESS");
        body.put("source", lastSource);
        body.put("updatedAt", System.currentTimeMillis());
        body.put("count", result.size());
        body.put("data", result);
        return ResponseEntity.ok(body);
    }

    private Map<String, Map<String, Object>> fetchAllLiveQuotes(List<String> symbols) {
        // 1. Primary: Angel One SmartAPI live batch market quote (official exchange feed, zero cloud IP blocks)
        Map<String, Map<String, Object>> quotes = fetchFromAngelOneBatch(symbols);
        if (!quotes.isEmpty()) {
            lastSource = "ANGELONE_LIVE_NSE";
        }

        // 2. Fill any missing symbols (or all symbols if no Angel One session yet) from Groww live NSE/BSE feed
        List<String> missing = new ArrayList<>();
        for (String sym : symbols) {
            if (!quotes.containsKey(sym)) {
                missing.add(sym);
            }
        }
        if (!missing.isEmpty()) {
            Map<String, Map<String, Object>> growwQuotes = fetchFromGrowwBatch(missing);
            if (!growwQuotes.isEmpty()) {
                quotes.putAll(growwQuotes);
                if (quotes.size() == growwQuotes.size()) {
                    lastSource = "GROWW_LIVE_NSE";
                }
            }
        }

        return quotes;
    }

    private Map<String, Map<String, Object>> fetchFromAngelOneBatch(List<String> symbols) {
        Map<String, Map<String, Object>> out = new LinkedHashMap<>();
        if (pyBrokerAccountRepository == null || apiRequestHandler == null || routes == null) {
            return out;
        }
        try {
            List<PyBrokerAccountEntity> accounts = pyBrokerAccountRepository.findAll();
            PyBrokerAccountEntity angelAcc = null;
            for (PyBrokerAccountEntity acc : accounts) {
                if (acc.getBrokerType() == BrokerType.ANGELONE
                        && Boolean.TRUE.equals(acc.getActive())
                        && acc.getSecret() != null
                        && acc.getToken() != null
                        && acc.getToken().getAccessToken() != null
                        && !acc.getToken().getAccessToken().isBlank()
                        && !acc.getToken().getAccessToken().startsWith("PAPER-")) {
                    angelAcc = acc;
                    break;
                }
            }
            if (angelAcc == null) {
                return out;
            }

            Set<String> requestedSet = new HashSet<>(symbols);
            JSONArray nseTokens = new JSONArray();
            for (Map.Entry<String, String> e : ANGEL_NSE_TOKENS.entrySet()) {
                if (requestedSet.contains(e.getValue())) {
                    nseTokens.put(e.getKey());
                }
            }
            JSONArray bseTokens = new JSONArray();
            if (requestedSet.contains("SENSEX")) {
                bseTokens.put("99919000");
            }
            if (nseTokens.length() == 0 && bseTokens.length() == 0) {
                return out;
            }

            JSONObject exchangeTokens = new JSONObject();
            if (nseTokens.length() > 0) exchangeTokens.put("NSE", nseTokens);
            if (bseTokens.length() > 0) exchangeTokens.put("BSE", bseTokens);

            JSONObject payload = new JSONObject();
            payload.put("mode", "OHLC");
            payload.put("exchangeTokens", exchangeTokens);

            JSONObject resp = apiRequestHandler.postRequest(
                    angelAcc.getSecret().getApiKey(),
                    routes.get("api.market.data"),
                    payload,
                    angelAcc.getToken().getAccessToken());

            if (resp == null || !resp.optBoolean("status", false)) {
                return out;
            }
            JSONObject data = resp.optJSONObject("data");
            if (data == null) return out;
            JSONArray fetched = data.optJSONArray("fetched");
            if (fetched == null) return out;

            for (int i = 0; i < fetched.length(); i++) {
                JSONObject item = fetched.optJSONObject(i);
                if (item == null) continue;
                String token = item.optString("symbolToken", "");
                String symKey = "99919000".equals(token) ? "SENSEX" : ANGEL_NSE_TOKENS.get(token);
                if (symKey == null) continue;

                double ltp = item.optDouble("ltp", 0.0);
                if (ltp <= 0.0) continue;
                double close = item.optDouble("close", ltp);
                double change = ltp - close;
                double changePct = close > 0 ? (change / close) * 100.0 : 0.0;

                Map<String, Object> q = new LinkedHashMap<>();
                q.put("symbol", symKey);
                q.put("ltp", round2(ltp));
                q.put("prevClose", round2(close));
                q.put("change", round2(change));
                q.put("changePct", round2(changePct));
                q.put("high", round2(item.optDouble("high", ltp)));
                q.put("low", round2(item.optDouble("low", ltp)));
                q.put("volume", item.optLong("tradeVolume", 0L));
                out.put(symKey, q);
            }
        } catch (Throwable e) {
            log.debug("AngelOne live batch quote skipped: {}", e.getMessage());
        }
        return out;
    }

    private Map<String, Map<String, Object>> fetchFromGrowwBatch(List<String> symbols) {
        Map<String, CompletableFuture<Map<String, Object>>> futures = new LinkedHashMap<>();
        for (String sym : symbols) {
            futures.put(sym, CompletableFuture.supplyAsync(() -> fetchGrowwSingle(sym), executor));
        }

        Map<String, Map<String, Object>> quotes = new LinkedHashMap<>();
        for (Map.Entry<String, CompletableFuture<Map<String, Object>>> entry : futures.entrySet()) {
            try {
                Map<String, Object> q = entry.getValue().get(5, TimeUnit.SECONDS);
                if (q != null && !q.isEmpty()) {
                    quotes.put(entry.getKey(), q);
                }
            } catch (Exception ignored) {
            }
        }
        return quotes;
    }

    private Map<String, Object> fetchGrowwSingle(String symbol) {
        try {
            String encoded = URLEncoder.encode(symbol, StandardCharsets.UTF_8);
            String url;
            boolean isIndex = false;
            if (NSE_INDICES.contains(symbol)) {
                url = "https://groww.in/v1/api/stocks_data/v1/accord_points/exchange/NSE/segment/CASH/latest_indices_ohlc/" + encoded;
                isIndex = true;
            } else if (BSE_INDICES.contains(symbol)) {
                url = "https://groww.in/v1/api/stocks_data/v1/accord_points/exchange/BSE/segment/CASH/latest_indices_ohlc/" + encoded;
                isIndex = true;
            } else {
                url = "https://groww.in/v1/api/stocks_data/v1/tr_live_prices/exchange/NSE/segment/CASH/" + encoded + "/latest";
            }

            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                    .header("Accept", "application/json")
                    .timeout(Duration.ofSeconds(4))
                    .GET()
                    .build();

            HttpResponse<String> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() != 200 || resp.body() == null || resp.body().isBlank()) {
                return null;
            }

            JSONObject json = new JSONObject(resp.body());
            double ltp = isIndex ? json.optDouble("value", 0.0) : json.optDouble("ltp", 0.0);
            if (ltp <= 0.0) return null;

            double close = json.optDouble("close", ltp);
            double change = json.has("dayChange") ? json.optDouble("dayChange", ltp - close) : (ltp - close);
            double changePct = json.has("dayChangePerc")
                    ? json.optDouble("dayChangePerc", close > 0 ? (change / close) * 100.0 : 0.0)
                    : (close > 0 ? (change / close) * 100.0 : 0.0);

            Map<String, Object> out = new LinkedHashMap<>();
            out.put("symbol", symbol);
            out.put("ltp", round2(ltp));
            out.put("prevClose", round2(close));
            out.put("change", round2(change));
            out.put("changePct", round2(changePct));
            out.put("high", round2(json.optDouble("high", ltp)));
            out.put("low", round2(json.optDouble("low", ltp)));
            out.put("volume", json.optLong("volume", 0L));
            return out;
        } catch (Exception e) {
            log.debug("Groww quote fetch skipped for {}: {}", symbol, e.getMessage());
            return null;
        }
    }

    private double round2(double v) {
        return Math.round(v * 100.0) / 100.0;
    }
}
