package com.py.brokers.angel.client.service;

import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonToken;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Ultra-lightweight streaming loader for Angel One's OpenAPIScripMaster.json.
 * Uses Jackson streaming JsonParser (~2-3 MB RAM, safe on 512 MB Render instances)
 * to index active NSE/BSE equities, NFO/BFO index options & futures, and MCX commodities.
 */
@Service
public class AngelOneScripMasterService {

    private static final Logger log = LoggerFactory.getLogger(AngelOneScripMasterService.class);
    private static final String SCRIP_MASTER_URL =
            "https://margincalculator.angelbroking.com/OpenAPI_File/files/OpenAPIScripMaster.json";
    private static final DateTimeFormatter EXPIRY_FMT =
            DateTimeFormatter.ofPattern("ddMMMyyyy", Locale.ENGLISH);

    private static final Set<String> TRACKED_INDICES = Set.of(
            "NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "SENSEX", "BANKEX"
    );

    public static class ScripEntry {
        public final String token;
        public final String symbol;
        public final String name;
        public final String exchange;
        public final String instrumentType;
        public final String expiryStr;
        public final LocalDate expiryDate;
        public final int strike; // actual integer strike (divided by 100)
        public final int lotSize;

        public ScripEntry(String token, String symbol, String name, String exchange,
                          String instrumentType, String expiryStr, LocalDate expiryDate,
                          int strike, int lotSize) {
            this.token = token;
            this.symbol = symbol;
            this.name = name;
            this.exchange = exchange;
            this.instrumentType = instrumentType;
            this.expiryStr = expiryStr;
            this.expiryDate = expiryDate;
            this.strike = strike;
            this.lotSize = lotSize;
        }
    }

    // Equity lookup: "NSE:RELIANCE" -> ScripEntry
    private final Map<String, ScripEntry> equityMap = new ConcurrentHashMap<>();
    // Nearest futures lookup: "MCX:CRUDEOIL" or "NFO:NIFTY" -> list sorted by expiryDate asc
    private final Map<String, List<ScripEntry>> futuresMap = new ConcurrentHashMap<>();
    // Options lookup: "NIFTY" (or "CRUDEOIL") -> list sorted by expiryDate asc
    private final Map<String, List<ScripEntry>> optionsByUnderlying = new ConcurrentHashMap<>();

    private volatile long lastLoadedMs = 0L;
    private final Object loadLock = new Object();

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    public void ensureLoaded() {
        long now = System.currentTimeMillis();
        // Refresh every 6 hours
        if (!equityMap.isEmpty() && (now - lastLoadedMs) < 21_600_000L) {
            return;
        }
        synchronized (loadLock) {
            now = System.currentTimeMillis();
            if (!equityMap.isEmpty() && (now - lastLoadedMs) < 21_600_000L) {
                return;
            }
            loadStreaming();
        }
    }

    private void loadStreaming() {
        long start = System.currentTimeMillis();
        Map<String, ScripEntry> newEquities = new HashMap<>(4096);
        Map<String, List<ScripEntry>> newFutures = new HashMap<>(128);
        Map<String, List<ScripEntry>> newOptions = new HashMap<>(64);
        LocalDate today = LocalDate.now();
        LocalDate maxOptionDate = today.plusDays(65); // Keep nearest ~2 months of options to save RAM

        try {
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(SCRIP_MASTER_URL))
                    .header("User-Agent", "Mozilla/5.0")
                    .timeout(Duration.ofSeconds(25))
                    .GET()
                    .build();

            HttpResponse<InputStream> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofInputStream());
            if (resp.statusCode() != 200) {
                log.warn("OpenAPIScripMaster HTTP {}", resp.statusCode());
                return;
            }

            JsonFactory factory = new JsonFactory();
            try (InputStream is = resp.body(); JsonParser parser = factory.createParser(is)) {
                if (parser.nextToken() != JsonToken.START_ARRAY) {
                    return;
                }
                while (parser.nextToken() == JsonToken.START_OBJECT) {
                    String token = "";
                    String symbol = "";
                    String name = "";
                    String expiry = "";
                    String strikeRaw = "";
                    String lotRaw = "";
                    String instType = "";
                    String exchSeg = "";

                    while (parser.nextToken() != JsonToken.END_OBJECT) {
                        String field = parser.getCurrentName();
                        parser.nextToken();
                        if (field == null) continue;
                        switch (field) {
                            case "token" -> token = parser.getValueAsString("");
                            case "symbol" -> symbol = parser.getValueAsString("");
                            case "name" -> name = parser.getValueAsString("");
                            case "expiry" -> expiry = parser.getValueAsString("");
                            case "strike" -> strikeRaw = parser.getValueAsString("");
                            case "lotsize" -> lotRaw = parser.getValueAsString("");
                            case "instrumenttype" -> instType = parser.getValueAsString("");
                            case "exch_seg" -> exchSeg = parser.getValueAsString("");
                            default -> parser.skipChildren();
                        }
                    }

                    if (token.isEmpty() || symbol.isEmpty()) continue;
                    String ex = exchSeg.toUpperCase();
                    String symUpper = symbol.toUpperCase();
                    String nameUpper = name.toUpperCase();
                    String instUpper = instType.toUpperCase();

                    // 1. NSE / BSE Equities
                    if ("NSE".equals(ex) && symUpper.endsWith("-EQ")) {
                        String base = symUpper.substring(0, symUpper.length() - 3);
                        newEquities.put("NSE:" + base, new ScripEntry(token, symbol, nameUpper, ex, "EQ", "", null, 0, 1));
                        continue;
                    }
                    if ("BSE".equals(ex) && instUpper.isEmpty() && !nameUpper.isEmpty()) {
                        newEquities.putIfAbsent("BSE:" + nameUpper, new ScripEntry(token, symbol, nameUpper, ex, "EQ", "", null, 0, 1));
                        continue;
                    }

                    // 2. Active Futures (MCX FUTCOM + NFO/BFO FUTIDX)
                    if (("MCX".equals(ex) && "FUTCOM".equals(instUpper))
                            || (("NFO".equals(ex) || "BFO".equals(ex)) && "FUTIDX".equals(instUpper) && TRACKED_INDICES.contains(nameUpper))) {
                        LocalDate expDate = parseExpiry(expiry);
                        if (expDate != null && !expDate.isBefore(today)) {
                            int lot = parseIntSafe(lotRaw, 1);
                            ScripEntry entry = new ScripEntry(token, symbol, nameUpper, ex, instUpper, expiry.toUpperCase(), expDate, 0, lot);
                            newFutures.computeIfAbsent(ex + ":" + nameUpper, k -> new ArrayList<>()).add(entry);
                        }
                        continue;
                    }

                    // 3. Active Index Options (NFO/BFO OPTIDX) & MCX Commodity Options (OPTFUT)
                    boolean isTrackedIdxOpt = ("NFO".equals(ex) || "BFO".equals(ex))
                            && "OPTIDX".equals(instUpper)
                            && TRACKED_INDICES.contains(nameUpper);
                    boolean isMcxOpt = "MCX".equals(ex) && "OPTFUT".equals(instUpper);

                    if (isTrackedIdxOpt || isMcxOpt) {
                        LocalDate expDate = parseExpiry(expiry);
                        if (expDate != null && !expDate.isBefore(today) && !expDate.isAfter(maxOptionDate)) {
                            int strikeInt = parseStrike(strikeRaw);
                            int lot = parseIntSafe(lotRaw, 1);
                            ScripEntry entry = new ScripEntry(token, symbol, nameUpper, ex, instUpper, expiry.toUpperCase(), expDate, strikeInt, lot);
                            newOptions.computeIfAbsent(nameUpper, k -> new ArrayList<>()).add(entry);
                        }
                    }
                }
            }

            // Sort all futures & options by nearest expiry ascending
            for (List<ScripEntry> list : newFutures.values()) {
                list.sort(Comparator.comparing(e -> e.expiryDate));
            }
            for (List<ScripEntry> list : newOptions.values()) {
                list.sort(Comparator.comparing(e -> e.expiryDate));
            }

            equityMap.clear();
            equityMap.putAll(newEquities);
            futuresMap.clear();
            futuresMap.putAll(newFutures);
            optionsByUnderlying.clear();
            optionsByUnderlying.putAll(newOptions);
            lastLoadedMs = System.currentTimeMillis();

            log.info("✅ AngelOneScripMaster streamed in {}ms | equities={} futures={} optionUnderlyings={}",
                    (lastLoadedMs - start), equityMap.size(), futuresMap.size(), optionsByUnderlying.size());
        } catch (Exception e) {
            log.error("Failed to stream AngelOne OpenAPIScripMaster: {}", e.getMessage());
        }
    }

    public ScripEntry findEquity(String exchange, String rawSymbol) {
        ensureLoaded();
        if (rawSymbol == null || rawSymbol.isBlank()) return null;
        String ex = (exchange == null || exchange.isBlank()) ? "NSE" : exchange.trim().toUpperCase();
        String base = rawSymbol.trim().toUpperCase().replace("-EQ", "").split("\\s+")[0];
        ScripEntry hit = equityMap.get(ex + ":" + base);
        if (hit == null && !"NSE".equals(ex)) {
            hit = equityMap.get("NSE:" + base);
        }
        return hit;
    }

    public ScripEntry findNearestFuture(String exchange, String underlying) {
        ensureLoaded();
        if (underlying == null || underlying.isBlank()) return null;
        String ex = (exchange == null || exchange.isBlank()) ? "MCX" : exchange.trim().toUpperCase();
        String u = underlying.trim().toUpperCase().split("[\\s-]")[0];
        List<ScripEntry> list = futuresMap.get(ex + ":" + u);
        if ((list == null || list.isEmpty()) && !"NFO".equals(ex)) {
            list = futuresMap.get("NFO:" + u);
        }
        return (list != null && !list.isEmpty()) ? list.get(0) : null;
    }

    public ScripEntry findNearestOption(String underlying, int strike, String optType) {
        ensureLoaded();
        if (underlying == null || underlying.isBlank() || optType == null) return null;
        String u = underlying.trim().toUpperCase();
        String ot = optType.trim().toUpperCase();
        List<ScripEntry> list = optionsByUnderlying.get(u);
        if (list == null || list.isEmpty()) return null;

        LocalDate today = LocalDate.now();
        for (ScripEntry e : list) {
            if (e.expiryDate != null && !e.expiryDate.isBefore(today)
                    && e.strike == strike
                    && e.symbol.toUpperCase().endsWith(ot)) {
                return e;
            }
        }
        return null;
    }

    public Map<String, Object> getNearestExpiryOptionChainEntries(String underlying, double spot, double step, int halfRange) {
        ensureLoaded();
        Map<String, Object> res = new LinkedHashMap<>();
        String u = underlying.trim().toUpperCase();
        List<ScripEntry> list = optionsByUnderlying.get(u);
        if (list == null || list.isEmpty()) {
            return res;
        }

        LocalDate today = LocalDate.now();
        LocalDate nearestExpiry = null;
        String nearestExpiryStr = "";
        int lotSize = 1;
        String exchange = ("SENSEX".equals(u) || "BANKEX".equals(u)) ? "BFO" : "NFO";

        for (ScripEntry e : list) {
            if (e.expiryDate != null && !e.expiryDate.isBefore(today)) {
                nearestExpiry = e.expiryDate;
                nearestExpiryStr = e.expiryStr;
                lotSize = e.lotSize;
                exchange = e.exchange;
                break;
            }
        }
        if (nearestExpiry == null) return res;

        int atm = (int) (Math.round(spot / step) * step);
        int minStrike = (int) (atm - halfRange * step);
        int maxStrike = (int) (atm + halfRange * step);

        Map<Integer, ScripEntry> ceMap = new LinkedHashMap<>();
        Map<Integer, ScripEntry> peMap = new LinkedHashMap<>();

        for (ScripEntry e : list) {
            if (!nearestExpiry.equals(e.expiryDate)) continue;
            if (e.strike < minStrike || e.strike > maxStrike) continue;
            String symUp = e.symbol.toUpperCase();
            if (symUp.endsWith("CE")) {
                ceMap.putIfAbsent(e.strike, e);
            } else if (symUp.endsWith("PE")) {
                peMap.putIfAbsent(e.strike, e);
            }
        }

        res.put("expiry", nearestExpiryStr);
        res.put("lotSize", lotSize);
        res.put("exchange", exchange);
        res.put("atm", atm);
        res.put("ceMap", ceMap);
        res.put("peMap", peMap);
        return res;
    }

    private LocalDate parseExpiry(String raw) {
        if (raw == null || raw.isBlank()) return null;
        try {
            return LocalDate.parse(raw.trim().toUpperCase(), EXPIRY_FMT);
        } catch (Exception e) {
            return null;
        }
    }

    private int parseStrike(String raw) {
        if (raw == null || raw.isBlank()) return 0;
        try {
            double val = Double.parseDouble(raw.trim());
            // Angel One always stores strikes multiplied by 100 (e.g., 2480000.00 -> 24800, 24000.00 -> 240)
            return val > 0 ? (int) Math.round(val / 100.0) : 0;
        } catch (Exception e) {
            return 0;
        }
    }

    private int parseIntSafe(String raw, int fallback) {
        if (raw == null || raw.isBlank()) return fallback;
        try {
            return Integer.parseInt(raw.trim());
        } catch (Exception e) {
            return fallback;
        }
    }
}
