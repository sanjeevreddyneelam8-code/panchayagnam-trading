package com.py.controller;

import com.py.brokers.angel.client.Routes;
import com.py.brokers.angel.client.service.AngelOneApisService;
import com.py.brokers.angel.dto.AngelOneRMSRequest;
import com.py.brokers.angel.http.ApiRequestHandler;
import com.py.common.enums.BrokerType;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.tokensValidation.PyTokenValidationService;
import com.py.trading.service.PaperTradingService;
import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
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
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
    private AngelOneApisService angelOneApisService;

    @Autowired(required = false)
    private PyTokenValidationService pyTokenValidationService;

    @Autowired(required = false)
    private PaperTradingService paperTradingService;

    @Autowired(required = false)
    private Environment environment;

    private static final Set<String> NSE_INDICES = Set.of(
            "NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "INDIAVIX");
    private static final Set<String> BSE_INDICES = Set.of("SENSEX", "BANKEX");

    private static final List<String> DEFAULT_SYMBOLS = List.of(
            "NIFTY", "BANKNIFTY", "SENSEX", "INDIAVIX", "FINNIFTY", "MIDCPNIFTY",
            "RELIANCE", "HDFCBANK", "INFY", "TCS", "SBIN", "ICICIBANK",
            "BHARTIARTL", "ITC", "LT", "KOTAKBANK", "AXISBANK", "BAJFINANCE",
            "TATAMOTORS", "MARUTI", "SUNPHARMA", "ADANIENT", "WIPRO",
            "HCLTECH", "TITAN", "TATASTEEL", "IDEA", "YESBANK",
            "PERSISTENT", "DIXON", "TRENT", "COFORGE", "NESTLEIND", "INDUSINDBK",
            "ABB", "BEL", "HAL", "IOC", "POLICYBZR", "POWERINDIA", "SIEMENS",
            "ZOMATO", "ETERNAL", "PNB", "JIOFIN", "HINDALCO", "JSWSTEEL"
    );

    private static final List<String> DEFAULT_COMMODITIES = List.of(
            "CRUDEOIL", "CRUDEOILM", "NATURALGAS", "NATGASMINI",
            "GOLD", "GOLDM", "GOLDPETAL", "GOLDGUINEA",
            "SILVER", "SILVERM", "SILVERMIC",
            "COPPER", "ZINC", "ZINCMINI", "ALUMINIUM", "LEAD", "NICKEL"
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
        ANGEL_NSE_TOKENS.put("18365", "PERSISTENT");
        ANGEL_NSE_TOKENS.put("21690", "DIXON");
        ANGEL_NSE_TOKENS.put("1964", "TRENT");
        ANGEL_NSE_TOKENS.put("11543", "COFORGE");
        ANGEL_NSE_TOKENS.put("17963", "NESTLEIND");
        ANGEL_NSE_TOKENS.put("5258", "INDUSINDBK");
        ANGEL_NSE_TOKENS.put("13", "ABB");
        ANGEL_NSE_TOKENS.put("383", "BEL");
        ANGEL_NSE_TOKENS.put("2303", "HAL");
        ANGEL_NSE_TOKENS.put("1624", "IOC");
        ANGEL_NSE_TOKENS.put("6656", "POLICYBZR");
        ANGEL_NSE_TOKENS.put("18457", "POWERINDIA");
        ANGEL_NSE_TOKENS.put("3150", "SIEMENS");
        ANGEL_NSE_TOKENS.put("5097", "ZOMATO");
        ANGEL_NSE_TOKENS.put("10666", "PNB");
        ANGEL_NSE_TOKENS.put("18143", "JIOFIN");
        ANGEL_NSE_TOKENS.put("1363", "HINDALCO");
        ANGEL_NSE_TOKENS.put("11723", "JSWSTEEL");
    }

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(4))
            .build();

    private final ExecutorService executor = Executors.newFixedThreadPool(12);

    private volatile Map<String, Map<String, Object>> cachedDefaultQuotes = new ConcurrentHashMap<>();
    private volatile long lastCacheEpochMs = 0L;
    private volatile String lastSource = "LIVE_NSE";
    private static final long CACHE_TTL_MS = 3500L;

    // MCX commodity active future token cache (refreshed every 6 hours)
    private final Map<String, String[]> mcxTokenCache = new ConcurrentHashMap<>(); // sym -> [token, tradingsymbol]
    private volatile long lastMcxTokenResolveMs = 0L;
    private volatile boolean mcxWarmupRunning = false;
    private volatile Map<String, Map<String, Object>> cachedCommodityQuotes = new ConcurrentHashMap<>();
    private volatile long lastCommodityCacheMs = 0L;

    // Rate limiter lock for Angel One searchScrip (max ~2 req/sec to avoid AB1004/rate-limit)
    private final Object searchRateLock = new Object();
    private volatile long lastSearchEpochMs = 0L;

    private JSONArray angelSearchScrip(String apiKey, String accessToken, String exchange, String query) {
        synchronized (searchRateLock) {
            long waitMs = 450L - (System.currentTimeMillis() - lastSearchEpochMs);
            if (waitMs > 0) {
                try {
                    Thread.sleep(waitMs);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                }
            }
            lastSearchEpochMs = System.currentTimeMillis();
            try {
                JSONObject sp = new JSONObject();
                sp.put("exchange", exchange);
                sp.put("searchscrip", query);
                JSONObject resp = apiRequestHandler.postRequest(
                        apiKey, routes.get("api.search.script.data"), sp, accessToken);
                return resp != null ? resp.optJSONArray("data") : null;
            } catch (Throwable e) {
                log.debug("searchScrip failed for {} {}: {}", exchange, query, e.getMessage());
                return null;
            }
        }
    }

    // Option chain token cache: key = underlying_atm -> { expiry, tokenMap }
    private final Map<String, Map<String, Object>> optionTokenCache = new ConcurrentHashMap<>();
    private final Map<String, Long> optionTokenCacheTime = new ConcurrentHashMap<>();
    private final Map<String, Map<String, Object>> optionChainResponseCache = new ConcurrentHashMap<>();
    private final Map<String, Long> optionChainResponseCacheTime = new ConcurrentHashMap<>();

    // Outbound public IP cache
    private volatile String cachedOutboundIp = null;
    private volatile long lastIpFetchMs = 0L;

    private String resolveOutboundIp() {
        long now = System.currentTimeMillis();
        if (cachedOutboundIp != null && (now - lastIpFetchMs) < 300_000L) {
            return cachedOutboundIp;
        }
        try {
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.ipify.org"))
                    .timeout(Duration.ofSeconds(3))
                    .GET()
                    .build();
            HttpResponse<String> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() == 200 && resp.body() != null) {
                String ip = resp.body().trim();
                if (ip.matches("^\\d+\\.\\d+\\.\\d+\\.\\d+$")) {
                    cachedOutboundIp = ip;
                    lastIpFetchMs = now;
                    return ip;
                }
            }
        } catch (Exception ignored) {
        }
        return cachedOutboundIp != null ? cachedOutboundIp : "74.220.52.132";
    }

    private PyBrokerAccountEntity findActiveAngelOneAccount(String preferredClientId) {
        if (pyBrokerAccountRepository == null) return null;
        try {
            List<PyBrokerAccountEntity> accounts = pyBrokerAccountRepository.findAll();
            PyBrokerAccountEntity fallback = null;
            for (PyBrokerAccountEntity acc : accounts) {
                if (acc.getBrokerType() == BrokerType.ANGELONE
                        && Boolean.TRUE.equals(acc.getActive())
                        && acc.getSecret() != null
                        && acc.getToken() != null
                        && acc.getToken().getAccessToken() != null
                        && !acc.getToken().getAccessToken().isBlank()
                        && !acc.getToken().getAccessToken().startsWith("PAPER-")) {
                    if (preferredClientId != null && !preferredClientId.isBlank()
                            && preferredClientId.equalsIgnoreCase(acc.getClientId())) {
                        return acc;
                    }
                    if (fallback == null) {
                        fallback = acc;
                    }
                }
            }
            return fallback;
        } catch (Exception e) {
            return null;
        }
    }

    private String getFreshToken(PyBrokerAccountEntity acc) {
        if (acc == null) return null;
        if (pyTokenValidationService != null) {
            String valid = pyTokenValidationService.getValidAccessToken(acc.getId());
            if (valid != null && !valid.isBlank() && !valid.startsWith("PAPER-")) {
                return valid;
            }
        }
        return acc.getToken() != null ? acc.getToken().getAccessToken() : null;
    }

    @GetMapping("/mode")
    public ResponseEntity<Map<String, Object>> getTradingMode() {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("paperTradingEnabled", paperTradingService != null && paperTradingService.isPaperTradingEnabled());
        body.put("liveTradingEnabled", paperTradingService == null || paperTradingService.isLiveTradingEnabled());
        body.put("activeProfiles", environment != null ? Arrays.asList(environment.getActiveProfiles()) : List.of());
        body.put("serverOutboundIp", resolveOutboundIp());
        return ResponseEntity.ok(body);
    }

    @GetMapping("/server-ip")
    public ResponseEntity<Map<String, Object>> getServerIp() {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("status", "SUCCESS");
        body.put("ip", resolveOutboundIp());
        return ResponseEntity.ok(body);
    }

    @GetMapping("/funds")
    public ResponseEntity<Map<String, Object>> getLiveFunds(
            @RequestParam(required = false) String clientId) {
        Map<String, Object> body = new LinkedHashMap<>();
        PyBrokerAccountEntity acc = findActiveAngelOneAccount(clientId);
        if (acc == null || angelOneApisService == null) {
            body.put("status", "UNAVAILABLE");
            body.put("availableCash", 0.0);
            body.put("net", 0.0);
            return ResponseEntity.ok(body);
        }
        try {
            String token = getFreshToken(acc);
            AngelOneRMSRequest rmsReq = new AngelOneRMSRequest();
            rmsReq.setApiKey(acc.getSecret().getApiKey());
            rmsReq.setAccessToken(token);
            JSONObject rms = angelOneApisService.getRMS(rmsReq);
            double availableCash = parseDoubleSafe(rms.opt("availablecash"));
            double net = parseDoubleSafe(rms.opt("net"));
            if (availableCash <= 0 && net > 0) availableCash = net;
            body.put("status", "SUCCESS");
            body.put("clientId", acc.getClientId());
            body.put("availableCash", round2(availableCash));
            body.put("net", round2(net));
            body.put("utilisedDebits", round2(parseDoubleSafe(rms.opt("utiliseddebits"))));
            body.put("collateral", round2(parseDoubleSafe(rms.opt("collateral"))));
            return ResponseEntity.ok(body);
        } catch (Exception e) {
            log.warn("Failed to fetch live RMS funds: {}", e.getMessage());
            body.put("status", "ERROR");
            body.put("message", e.getMessage());
            return ResponseEntity.ok(body);
        }
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

    @GetMapping("/commodities")
    public ResponseEntity<Map<String, Object>> getLiveCommodities() {
        long now = System.currentTimeMillis();
        if (now - lastCommodityCacheMs > CACHE_TTL_MS || cachedCommodityQuotes.isEmpty()) {
            Map<String, Map<String, Object>> fresh = fetchMcxCommoditiesLive();
            if (!fresh.isEmpty()) {
                cachedCommodityQuotes = fresh;
                lastCommodityCacheMs = now;
            }
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("status", "SUCCESS");
        body.put("source", cachedCommodityQuotes.isEmpty() ? "UNAVAILABLE" : "ANGELONE_LIVE_MCX");
        body.put("updatedAt", System.currentTimeMillis());
        body.put("count", cachedCommodityQuotes.size());
        body.put("data", cachedCommodityQuotes);
        return ResponseEntity.ok(body);
    }

    @GetMapping("/option-chain")
    public ResponseEntity<Map<String, Object>> getLiveOptionChain(
            @RequestParam(defaultValue = "NIFTY") String underlying) {
        String sym = underlying.trim().toUpperCase();
        long now = System.currentTimeMillis();
        Long lastTs = optionChainResponseCacheTime.get(sym);
        if (lastTs != null && (now - lastTs) < 5000L && optionChainResponseCache.containsKey(sym)) {
            return ResponseEntity.ok(optionChainResponseCache.get(sym));
        }

        Map<String, Object> response = buildLiveOptionChain(sym);
        if ("SUCCESS".equals(response.get("status"))) {
            optionChainResponseCache.put(sym, response);
            optionChainResponseCacheTime.put(sym, now);
        }
        return ResponseEntity.ok(response);
    }

    private Map<String, Map<String, Object>> fetchMcxCommoditiesLive() {
        Map<String, Map<String, Object>> out = new LinkedHashMap<>();
        PyBrokerAccountEntity angelAcc = findActiveAngelOneAccount(null);
        if (angelAcc == null || apiRequestHandler == null || routes == null) {
            return out;
        }
        String apiKey = angelAcc.getSecret().getApiKey();
        String accessToken = getFreshToken(angelAcc);
        if (accessToken == null || accessToken.isBlank()) {
            return out;
        }

        long now = System.currentTimeMillis();
        boolean cacheStale = (now - lastMcxTokenResolveMs) > 21_600_000L;
        if ((mcxTokenCache.size() < 12 || cacheStale) && !mcxWarmupRunning) {
            mcxWarmupRunning = true;
            // Resolve top 4 commodities immediately if cache is empty, then resolve the rest in background
            List<String> priority = List.of("CRUDEOIL", "GOLD", "SILVER", "NATURALGAS");
            if (mcxTokenCache.isEmpty()) {
                for (String comm : priority) {
                    resolveMcxSymbol(apiKey, accessToken, comm);
                }
            }
            CompletableFuture.runAsync(() -> {
                try {
                    for (String comm : DEFAULT_COMMODITIES) {
                        if (!mcxTokenCache.containsKey(comm) || cacheStale) {
                            resolveMcxSymbol(apiKey, accessToken, comm);
                        }
                    }
                    if (!mcxTokenCache.isEmpty()) {
                        lastMcxTokenResolveMs = System.currentTimeMillis();
                    }
                } finally {
                    mcxWarmupRunning = false;
                }
            }, executor);
        }

        if (mcxTokenCache.isEmpty()) {
            return out;
        }

        try {
            Map<String, String> tokenToComm = new HashMap<>();
            Map<String, String> tokenToTs = new HashMap<>();
            JSONArray mcxTokens = new JSONArray();
            for (Map.Entry<String, String[]> e : mcxTokenCache.entrySet()) {
                String tok = e.getValue()[0];
                tokenToComm.put(tok, e.getKey());
                tokenToTs.put(tok, e.getValue()[1]);
                mcxTokens.put(tok);
            }

            JSONObject exchangeTokens = new JSONObject();
            exchangeTokens.put("MCX", mcxTokens);

            JSONObject payload = new JSONObject();
            payload.put("mode", "FULL");
            payload.put("exchangeTokens", exchangeTokens);

            JSONObject resp = apiRequestHandler.postRequest(
                    apiKey, routes.get("api.market.data"), payload, accessToken);
            if (resp == null || !resp.optBoolean("status", false)) {
                return out;
            }
            JSONObject data = resp.optJSONObject("data");
            JSONArray fetched = data != null ? data.optJSONArray("fetched") : null;
            if (fetched == null) return out;

            for (int i = 0; i < fetched.length(); i++) {
                JSONObject item = fetched.optJSONObject(i);
                if (item == null) continue;
                String tok = item.optString("symbolToken", "");
                String comm = tokenToComm.get(tok);
                if (comm == null) continue;
                double ltp = item.optDouble("ltp", 0.0);
                if (ltp <= 0.0) continue;
                double close = item.optDouble("close", ltp);
                double change = ltp - close;
                double changePct = close > 0 ? (change / close) * 100.0 : 0.0;

                Map<String, Object> q = new LinkedHashMap<>();
                q.put("symbol", comm);
                q.put("tradingSymbol", tokenToTs.getOrDefault(tok, comm));
                q.put("ltp", round2(ltp));
                q.put("prevClose", round2(close));
                q.put("change", round2(change));
                q.put("changePct", round2(changePct));
                q.put("high", round2(item.optDouble("high", ltp)));
                q.put("low", round2(item.optDouble("low", ltp)));
                q.put("volume", item.optLong("tradeVolume", 0L));
                q.put("oi", item.optLong("opnInterest", 0L));
                out.put(comm, q);
            }
        } catch (Throwable e) {
            log.debug("AngelOne MCX batch quote skipped: {}", e.getMessage());
        }
        return out;
    }

    private void resolveMcxSymbol(String apiKey, String accessToken, String comm) {
        JSONArray arr = angelSearchScrip(apiKey, accessToken, "MCX", comm);
        if (arr == null || arr.length() == 0) return;
        JSONObject best = null;
        for (int i = 0; i < arr.length(); i++) {
            JSONObject item = arr.optJSONObject(i);
            if (item == null) continue;
            String ts = item.optString("tradingsymbol", "").toUpperCase();
            if (ts.startsWith(comm) && ts.endsWith("FUT")) {
                String after = ts.substring(comm.length());
                if (!after.isEmpty() && Character.isDigit(after.charAt(0))) {
                    best = item;
                    break;
                }
            }
        }
        if (best != null) {
            String tok = best.optString("symboltoken", "");
            String ts = best.optString("tradingsymbol", "");
            if (!tok.isBlank()) {
                mcxTokenCache.put(comm, new String[]{tok, ts});
            }
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> buildLiveOptionChain(String underlying) {
        Map<String, Object> out = new LinkedHashMap<>();
        PyBrokerAccountEntity angelAcc = findActiveAngelOneAccount(null);
        if (angelAcc == null || apiRequestHandler == null || routes == null) {
            out.put("status", "UNAVAILABLE");
            out.put("message", "Connect an Angel One account for live Option Chain quotes");
            return out;
        }
        String apiKey = angelAcc.getSecret().getApiKey();
        String accessToken = getFreshToken(angelAcc);
        if (accessToken == null || accessToken.isBlank()) {
            out.put("status", "UNAVAILABLE");
            return out;
        }

        // 1. Get live spot price
        Map<String, Map<String, Object>> spotMap = fetchAllLiveQuotes(List.of(underlying));
        Map<String, Object> spotQuote = spotMap.get(underlying);
        if (spotQuote == null) {
            out.put("status", "UNAVAILABLE");
            return out;
        }
        double spot = ((Number) spotQuote.get("ltp")).doubleValue();
        double spotChange = ((Number) spotQuote.getOrDefault("change", 0.0)).doubleValue();
        double spotChangePct = ((Number) spotQuote.getOrDefault("changePct", 0.0)).doubleValue();

        String exchange = ("SENSEX".equals(underlying) || "BANKEX".equals(underlying)) ? "BFO" : "NFO";
        double step = switch (underlying) {
            case "BANKNIFTY", "SENSEX", "BANKEX" -> 100.0;
            case "MIDCPNIFTY" -> 25.0;
            case "NIFTY", "FINNIFTY" -> 50.0;
            default -> spot > 3000 ? 50.0 : (spot > 1000 ? 20.0 : (spot > 500 ? 10.0 : 5.0));
        };
        double atm = Math.round(spot / step) * step;
        String cacheKey = underlying + "_" + (int) atm;

        long now = System.currentTimeMillis();
        Map<String, Object> cachedMeta = optionTokenCache.get(cacheKey);
        Long metaTime = optionTokenCacheTime.get(cacheKey);
        if (cachedMeta == null || metaTime == null || (now - metaTime) > 1_800_000L) {
            // Resolve 9 strikes (-4..+4) around ATM sequentially with rate-limit spacing
            Map<Integer, String[]> ceTokens = new LinkedHashMap<>();
            Map<Integer, String[]> peTokens = new LinkedHashMap<>();
            String detectedExpiry = "";
            Pattern expPattern = Pattern.compile("^" + Pattern.quote(underlying) + "(\\d{2}[A-Z]{3}\\d{2})\\d+(CE|PE)$");

            for (int offset = -4; offset <= 4; offset++) {
                int strikeInt = (int) (atm + (offset * step));
                JSONArray arr = angelSearchScrip(apiKey, accessToken, exchange, underlying + " " + strikeInt);
                if (arr == null || arr.length() == 0) {
                    arr = angelSearchScrip(apiKey, accessToken, exchange, underlying + strikeInt);
                }
                if (arr == null) continue;
                for (int i = 0; i < arr.length(); i++) {
                    JSONObject item = arr.optJSONObject(i);
                    if (item == null) continue;
                    String ts = item.optString("tradingsymbol", "").toUpperCase();
                    String tok = item.optString("symboltoken", "");
                    if (tok.isBlank()) continue;
                    if (ts.startsWith(underlying) && ts.endsWith(strikeInt + "CE") && !ceTokens.containsKey(strikeInt)) {
                        ceTokens.put(strikeInt, new String[]{tok, ts});
                        Matcher m = expPattern.matcher(ts);
                        if (m.matches() && detectedExpiry.isEmpty()) detectedExpiry = m.group(1);
                    } else if (ts.startsWith(underlying) && ts.endsWith(strikeInt + "PE") && !peTokens.containsKey(strikeInt)) {
                        peTokens.put(strikeInt, new String[]{tok, ts});
                        Matcher m = expPattern.matcher(ts);
                        if (m.matches() && detectedExpiry.isEmpty()) detectedExpiry = m.group(1);
                    }
                }
            }

            if (!ceTokens.isEmpty() || !peTokens.isEmpty()) {
                cachedMeta = new LinkedHashMap<>();
                cachedMeta.put("expiry", detectedExpiry);
                cachedMeta.put("ceTokens", ceTokens);
                cachedMeta.put("peTokens", peTokens);
                optionTokenCache.put(cacheKey, cachedMeta);
                optionTokenCacheTime.put(cacheKey, now);
            }
        }

        if (cachedMeta == null) {
            out.put("status", "UNAVAILABLE");
            return out;
        }

        Map<Integer, String[]> ceTokens = (Map<Integer, String[]>) cachedMeta.get("ceTokens");
        Map<Integer, String[]> peTokens = (Map<Integer, String[]>) cachedMeta.get("peTokens");
        String expiry = String.valueOf(cachedMeta.getOrDefault("expiry", ""));

        JSONArray allTokens = new JSONArray();
        for (String[] pair : ceTokens.values()) allTokens.put(pair[0]);
        for (String[] pair : peTokens.values()) allTokens.put(pair[0]);

        Map<String, JSONObject> liveByToken = new HashMap<>();
        try {
            JSONObject exTokens = new JSONObject();
            exTokens.put(exchange, allTokens);
            JSONObject payload = new JSONObject();
            payload.put("mode", "FULL");
            payload.put("exchangeTokens", exTokens);

            JSONObject resp = apiRequestHandler.postRequest(
                    apiKey, routes.get("api.market.data"), payload, accessToken);
            JSONObject data = resp != null ? resp.optJSONObject("data") : null;
            JSONArray fetched = data != null ? data.optJSONArray("fetched") : null;
            if (fetched != null) {
                for (int i = 0; i < fetched.length(); i++) {
                    JSONObject item = fetched.optJSONObject(i);
                    if (item != null) {
                        liveByToken.put(item.optString("symbolToken", ""), item);
                    }
                }
            }
        } catch (Throwable e) {
            log.debug("Option chain batch quote failed for {}: {}", underlying, e.getMessage());
        }

        List<Map<String, Object>> strikes = new ArrayList<>();
        for (int offset = -5; offset <= 5; offset++) {
            int strikeInt = (int) (atm + (offset * step));
            String[] cePair = ceTokens.get(strikeInt);
            String[] pePair = peTokens.get(strikeInt);
            JSONObject ceLive = cePair != null ? liveByToken.get(cePair[0]) : null;
            JSONObject peLive = pePair != null ? liveByToken.get(pePair[0]) : null;
            if (ceLive == null && peLive == null) continue;

            double ceLtp = ceLive != null ? ceLive.optDouble("ltp", 0.0) : 0.0;
            double ceClose = ceLive != null ? ceLive.optDouble("close", ceLtp) : ceLtp;
            double ceChg = ceLtp - ceClose;
            double ceChgPct = ceClose > 0 ? (ceChg / ceClose) * 100.0 : 0.0;
            long ceOi = ceLive != null ? ceLive.optLong("opnInterest", 0L) : 0L;
            long ceVol = ceLive != null ? ceLive.optLong("tradeVolume", 0L) : 0L;

            double peLtp = peLive != null ? peLive.optDouble("ltp", 0.0) : 0.0;
            double peClose = peLive != null ? peLive.optDouble("close", peLtp) : peLtp;
            double peChg = peLtp - peClose;
            double peChgPct = peClose > 0 ? (peChg / peClose) * 100.0 : 0.0;
            long peOi = peLive != null ? peLive.optLong("opnInterest", 0L) : 0L;
            long peVol = peLive != null ? peLive.optLong("tradeVolume", 0L) : 0L;

            Map<String, Object> row = new LinkedHashMap<>();
            row.put("strike", strikeInt);
            row.put("isAtm", offset == 0);
            row.put("callLtp", round2(ceLtp));
            row.put("callChange", round2(ceChg));
            row.put("callChangePct", round2(ceChgPct));
            row.put("callOi", round2(ceOi / 100000.0)); // in Lakhs
            row.put("callVolume", ceVol);
            row.put("callSymbol", cePair != null ? cePair[1] : (underlying + " " + strikeInt + " CE"));
            row.put("callToken", cePair != null ? cePair[0] : "");
            row.put("putLtp", round2(peLtp));
            row.put("putChange", round2(peChg));
            row.put("putChangePct", round2(peChgPct));
            row.put("putOi", round2(peOi / 100000.0)); // in Lakhs
            row.put("putVolume", peVol);
            row.put("putSymbol", pePair != null ? pePair[1] : (underlying + " " + strikeInt + " PE"));
            row.put("putToken", pePair != null ? pePair[0] : "");
            strikes.add(row);
        }

        out.put("status", strikes.isEmpty() ? "UNAVAILABLE" : "SUCCESS");
        out.put("source", "ANGELONE_LIVE_" + exchange);
        out.put("underlying", underlying);
        out.put("exchange", exchange);
        out.put("expiry", expiry);
        out.put("spot", round2(spot));
        out.put("spotChange", round2(spotChange));
        out.put("spotChangePct", round2(spotChangePct));
        out.put("atm", (int) atm);
        out.put("strikes", strikes);
        out.put("updatedAt", System.currentTimeMillis());
        return out;
    }

    private Map<String, Map<String, Object>> fetchAllLiveQuotes(List<String> symbols) {
        Map<String, Map<String, Object>> quotes = fetchFromAngelOneBatch(symbols);
        if (!quotes.isEmpty()) {
            lastSource = "ANGELONE_LIVE_NSE";
        }

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
        PyBrokerAccountEntity angelAcc = findActiveAngelOneAccount(null);
        if (angelAcc == null || apiRequestHandler == null || routes == null) {
            return out;
        }
        try {
            String accessToken = getFreshToken(angelAcc);
            if (accessToken == null || accessToken.isBlank()) return out;

            Set<String> requestedSet = new HashSet<>(symbols);
            List<String> nseTokenList = new ArrayList<>();
            for (Map.Entry<String, String> e : ANGEL_NSE_TOKENS.entrySet()) {
                if (requestedSet.contains(e.getValue())) {
                    nseTokenList.add(e.getKey());
                }
            }
            JSONArray bseTokens = new JSONArray();
            if (requestedSet.contains("SENSEX")) {
                bseTokens.put("99919000");
            }
            if (nseTokenList.isEmpty() && bseTokens.length() == 0) {
                return out;
            }

            // Angel One batch limit is 50 tokens per request
            for (int start = 0; start < Math.max(1, nseTokenList.size()); start += 45) {
                JSONArray chunk = new JSONArray();
                int end = Math.min(nseTokenList.size(), start + 45);
                for (int i = start; i < end; i++) {
                    chunk.put(nseTokenList.get(i));
                }

                JSONObject exchangeTokens = new JSONObject();
                if (chunk.length() > 0) exchangeTokens.put("NSE", chunk);
                if (start == 0 && bseTokens.length() > 0) exchangeTokens.put("BSE", bseTokens);

                JSONObject payload = new JSONObject();
                payload.put("mode", "OHLC");
                payload.put("exchangeTokens", exchangeTokens);

                JSONObject resp = apiRequestHandler.postRequest(
                        angelAcc.getSecret().getApiKey(),
                        routes.get("api.market.data"),
                        payload,
                        accessToken);

                if (resp == null || !resp.optBoolean("status", false)) {
                    continue;
                }
                JSONObject data = resp.optJSONObject("data");
                JSONArray fetched = data != null ? data.optJSONArray("fetched") : null;
                if (fetched == null) continue;

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

    private double parseDoubleSafe(Object val) {
        if (val == null || JSONObject.NULL.equals(val)) return 0.0;
        if (val instanceof Number n) return n.doubleValue();
        try {
            return Double.parseDouble(val.toString().trim());
        } catch (Exception e) {
            return 0.0;
        }
    }

    private double round2(double v) {
        return Math.round(v * 100.0) / 100.0;
    }
}
