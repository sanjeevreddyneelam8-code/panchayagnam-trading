package com.py.controller;

import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    private static final Map<String, String> DEFAULT_YAHOO_SYMBOLS = new LinkedHashMap<>();
    static {
        DEFAULT_YAHOO_SYMBOLS.put("NIFTY", "^NSEI");
        DEFAULT_YAHOO_SYMBOLS.put("BANKNIFTY", "^NSEBANK");
        DEFAULT_YAHOO_SYMBOLS.put("SENSEX", "^BSESN");
        DEFAULT_YAHOO_SYMBOLS.put("INDIAVIX", "^INDIAVIX");
        DEFAULT_YAHOO_SYMBOLS.put("FINNIFTY", "NIFTY_FIN_SERVICE.NS");
        DEFAULT_YAHOO_SYMBOLS.put("MIDCPNIFTY", "NIFTY_MID_SELECT.NS");
        DEFAULT_YAHOO_SYMBOLS.put("RELIANCE", "RELIANCE.NS");
        DEFAULT_YAHOO_SYMBOLS.put("HDFCBANK", "HDFCBANK.NS");
        DEFAULT_YAHOO_SYMBOLS.put("INFY", "INFY.NS");
        DEFAULT_YAHOO_SYMBOLS.put("TCS", "TCS.NS");
        DEFAULT_YAHOO_SYMBOLS.put("SBIN", "SBIN.NS");
        DEFAULT_YAHOO_SYMBOLS.put("ICICIBANK", "ICICIBANK.NS");
        DEFAULT_YAHOO_SYMBOLS.put("BHARTIARTL", "BHARTIARTL.NS");
        DEFAULT_YAHOO_SYMBOLS.put("ITC", "ITC.NS");
        DEFAULT_YAHOO_SYMBOLS.put("LT", "LT.NS");
        DEFAULT_YAHOO_SYMBOLS.put("KOTAKBANK", "KOTAKBANK.NS");
        DEFAULT_YAHOO_SYMBOLS.put("AXISBANK", "AXISBANK.NS");
        DEFAULT_YAHOO_SYMBOLS.put("BAJFINANCE", "BAJFINANCE.NS");
        DEFAULT_YAHOO_SYMBOLS.put("TATAMOTORS", "TATAMOTORS.NS");
        DEFAULT_YAHOO_SYMBOLS.put("MARUTI", "MARUTI.NS");
        DEFAULT_YAHOO_SYMBOLS.put("SUNPHARMA", "SUNPHARMA.NS");
        DEFAULT_YAHOO_SYMBOLS.put("ADANIENT", "ADANIENT.NS");
        DEFAULT_YAHOO_SYMBOLS.put("WIPRO", "WIPRO.NS");
        DEFAULT_YAHOO_SYMBOLS.put("HCLTECH", "HCLTECH.NS");
        DEFAULT_YAHOO_SYMBOLS.put("TITAN", "TITAN.NS");
        DEFAULT_YAHOO_SYMBOLS.put("TATASTEEL", "TATASTEEL.NS");
        DEFAULT_YAHOO_SYMBOLS.put("IDEA", "IDEA.NS");
        DEFAULT_YAHOO_SYMBOLS.put("YESBANK", "YESBANK.NS");
    }

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(4))
            .build();

    private final ExecutorService executor = Executors.newFixedThreadPool(10);

    private volatile Map<String, Map<String, Object>> cachedDefaultQuotes = new ConcurrentHashMap<>();
    private volatile long lastCacheEpochMs = 0L;
    private static final long CACHE_TTL_MS = 3500L;

    @GetMapping("/quotes")
    public ResponseEntity<Map<String, Object>> getLiveQuotes(
            @RequestParam(required = false) String symbols) {

        Map<String, Map<String, Object>> result;

        if (symbols == null || symbols.isBlank()) {
            long now = System.currentTimeMillis();
            if (now - lastCacheEpochMs > CACHE_TTL_MS || cachedDefaultQuotes.isEmpty()) {
                Map<String, Map<String, Object>> fresh = fetchBatch(DEFAULT_YAHOO_SYMBOLS);
                if (!fresh.isEmpty()) {
                    cachedDefaultQuotes = fresh;
                    lastCacheEpochMs = now;
                }
            }
            result = cachedDefaultQuotes;
        } else {
            Map<String, String> requested = new LinkedHashMap<>();
            for (String raw : symbols.split(",")) {
                String clean = raw.trim().toUpperCase();
                if (clean.isEmpty()) continue;
                String mapped = DEFAULT_YAHOO_SYMBOLS.getOrDefault(
                        clean,
                        clean.startsWith("^") || clean.endsWith(".NS") || clean.endsWith(".BO")
                                ? clean
                                : clean + ".NS");
                requested.put(clean, mapped);
            }
            result = fetchBatch(requested);
        }

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("status", "SUCCESS");
        body.put("source", "LIVE_NSE");
        body.put("updatedAt", System.currentTimeMillis());
        body.put("count", result.size());
        body.put("data", result);
        return ResponseEntity.ok(body);
    }

    private Map<String, Map<String, Object>> fetchBatch(Map<String, String> symbolMap) {
        Map<String, CompletableFuture<Map<String, Object>>> futures = new LinkedHashMap<>();
        for (Map.Entry<String, String> entry : symbolMap.entrySet()) {
            futures.put(entry.getKey(), CompletableFuture.supplyAsync(
                    () -> fetchSingleQuote(entry.getKey(), entry.getValue()), executor));
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

    private Map<String, Object> fetchSingleQuote(String key, String yahooSymbol) {
        try {
            String encoded = URLEncoder.encode(yahooSymbol, StandardCharsets.UTF_8);
            String url = "https://query1.finance.yahoo.com/v8/finance/chart/" + encoded + "?interval=1m&range=1d";
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
                    .timeout(Duration.ofSeconds(4))
                    .GET()
                    .build();

            HttpResponse<String> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() != 200 || resp.body() == null || resp.body().isBlank()) {
                return null;
            }

            JSONObject json = new JSONObject(resp.body());
            JSONObject chart = json.optJSONObject("chart");
            if (chart == null) return null;
            JSONArray results = chart.optJSONArray("result");
            if (results == null || results.length() == 0) return null;
            JSONObject meta = results.getJSONObject(0).optJSONObject("meta");
            if (meta == null) return null;

            double ltp = meta.optDouble("regularMarketPrice", 0.0);
            if (ltp <= 0.0) return null;

            double prevClose = meta.optDouble("chartPreviousClose",
                    meta.optDouble("previousClose", ltp));
            double change = ltp - prevClose;
            double changePct = prevClose > 0 ? (change / prevClose) * 100.0 : 0.0;
            double dayHigh = meta.optDouble("regularMarketDayHigh", ltp);
            double dayLow = meta.optDouble("regularMarketDayLow", ltp);
            long volume = meta.optLong("regularMarketVolume", 0L);

            Map<String, Object> out = new LinkedHashMap<>();
            out.put("symbol", key);
            out.put("ltp", Math.round(ltp * 100.0) / 100.0);
            out.put("prevClose", Math.round(prevClose * 100.0) / 100.0);
            out.put("change", Math.round(change * 100.0) / 100.0);
            out.put("changePct", Math.round(changePct * 100.0) / 100.0);
            out.put("high", Math.round(dayHigh * 100.0) / 100.0);
            out.put("low", Math.round(dayLow * 100.0) / 100.0);
            out.put("volume", volume);
            return out;
        } catch (Exception e) {
            log.debug("Quote fetch skipped for {}: {}", yahooSymbol, e.getMessage());
            return null;
        }
    }
}
