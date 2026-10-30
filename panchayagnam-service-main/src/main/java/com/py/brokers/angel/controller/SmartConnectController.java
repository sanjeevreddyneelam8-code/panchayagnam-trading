package com.py.brokers.angel.controller;

import com.py.brokers.angel.dto.*;
import com.py.brokers.angel.client.SmartConnect;
import com.py.brokers.angel.exception.SmartAPIException;
import com.py.demataccount.service.PyBrokerAccountService;
import com.py.utils.ScripSearchService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.slf4j.LoggerFactory;

@RestController
@RequestMapping("/api/smart")
@CrossOrigin(origins = "*")
@Tag(name = "Angel SmartConnect", description = "Angel Broking SmartConnect APIs for trading, market data, GTT, and more")
public class SmartConnectController {

    private static final org.slf4j.Logger log = LoggerFactory.getLogger(SmartConnectController.class);

    @Autowired
    private SmartConnect smartConnect;

    @Autowired
    private ScripSearchService scripSearchService;

    @Autowired
    private PyBrokerAccountService pyBrokerAccountService;

    @Autowired
    private com.py.trading.service.PaperTradingService paperTradingService;

    @PostMapping("/session/renew")
    public ResponseEntity<?> renewAccessToken(@RequestBody Map<String, String> body) {
        TokenSet tokenSet = smartConnect.renewAccessToken(
                body.get("accessToken"),
                body.get("refreshToken")
        );
        return tokenSet != null ? ResponseEntity.ok(tokenSet) : ResponseEntity.badRequest().body("Token renewal failed");
    }

    @PostMapping("/user/profile")
    public ResponseEntity<?> getProfile(@RequestBody Map<String, String> body) {
        SmartConnect s = new SmartConnect(body.get("apiKey"), body.get("accessToken"), body.get("refreshToken"));
        User user = s.getProfile();
        return user != null ? ResponseEntity.ok(user) : ResponseEntity.badRequest().body("Failed to get profile");
    }

    @PostMapping("/session/logout")
    public ResponseEntity<?> logout() {
        JSONObject response = smartConnect.logout();
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Logout failed");
    }

    @PostMapping("/order/place")
    public ResponseEntity<?> placeOrder(@RequestBody OrderParams orderParams,
            @RequestParam(defaultValue = "regular") String variety) {
        if (paperTradingService.isPaperTradingEnabled()) {
            return ResponseEntity.badRequest().body("Direct SmartConnect order placement is disabled during paper trading. Use /pyBrokerApi/order/buy or /order/sell.");
        }
        paperTradingService.validateLiveOrderAllowed();
        Order order = smartConnect.placeOrder(orderParams, variety);
        return order != null ? ResponseEntity.ok(order) : ResponseEntity.badRequest().body("Order placement failed");
    }

    @PutMapping("/order/modify/{orderId}")
    public ResponseEntity<?> modifyOrder(@PathVariable String orderId,
            @RequestBody OrderParams orderParams,
            @RequestParam(defaultValue = "regular") String variety) {
        if (paperTradingService.isPaperTradingEnabled()) {
            return ResponseEntity.badRequest().body("Direct SmartConnect order modification is disabled during paper trading. Use /pyBrokerApi/modifyOrder.");
        }
        paperTradingService.validateLiveOrderAllowed();
        Order order = smartConnect.modifyOrder(orderId, orderParams, variety);
        return order != null ? ResponseEntity.ok(order) : ResponseEntity.badRequest().body("Order modification failed");
    }

    // ─────────────────────────────────────────────────────────────
    // 7. Cancel Order
    // DELETE /api/smart/order/cancel/{orderId}?variety=regular
    // ─────────────────────────────────────────────────────────────
    @Operation(summary = "Cancel Order", description = "Cancel an existing order by order ID")
    @DeleteMapping("/order/cancel/{orderId}")
    public ResponseEntity<?> cancelOrder(@Parameter(description = "Order ID", example = "210426000000011") @PathVariable String orderId,
            @Parameter(description = "Order variety", example = "NORMAL") @RequestParam(defaultValue = "regular") String variety) {
        if (paperTradingService.isPaperTradingEnabled()) {
            return ResponseEntity.badRequest().body("Direct SmartConnect order cancellation is disabled during paper trading. Use /pyBrokerApi/cancelOrder.");
        }
        paperTradingService.validateLiveOrderAllowed();
        Order order = smartConnect.cancelOrder(orderId, variety);
        return order != null ? ResponseEntity.ok(order) : ResponseEntity.badRequest().body("Order cancellation failed");
    }


    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 9. Get Individual Order Details
    // GET /api/smart/order/{orderId}
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get Individual Order Details", description = "Get details of a specific order")
    @GetMapping("/order/{orderId}")
    public ResponseEntity<?> getIndividualOrderDetails(@Parameter(description = "Order ID", example = "210426000000011") @PathVariable String orderId) throws IOException, SmartAPIException {
        JSONObject response = smartConnect.getIndividualOrderDetails(orderId);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Failed to get order details");
    }


    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 11. Get LTP (Last Traded Price)
    // GET /api/smart/market/ltp?exchange=NSE&tradingSymbol=SBIN-EQ&symboltoken=3045
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get LTP", description = "Get Last Traded Price for a specific instrument")
    @GetMapping("/market/ltp")
    public ResponseEntity<?> getLTP(@Parameter(description = "Exchange", example = "NSE") @RequestParam String exchange,
            @Parameter(description = "Trading symbol", example = "SBIN-EQ") @RequestParam String tradingSymbol,
            @Parameter(description = "Symbol token", example = "3045") @RequestParam String symboltoken, @RequestParam long pyUserId) {
        try {
            JSONObject response = pyBrokerAccountService.getLTP(
                    pyUserId, exchange, tradingSymbol, symboltoken);
            return response != null
                    ? ResponseEntity.ok(response.toMap())
                    : ResponseEntity.badRequest().body("Failed to get LTP");
        } catch (Exception e) {
            log.error("Get LTP failed | {}", e.getMessage(), e);
            return ResponseEntity.badRequest().body("Failed to get LTP");
        }
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 12. Get RMS (Risk Management System)
    // GET /api/smart/order/rms
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get RMS", description = "Get Risk Management System data")
    @GetMapping("/order/rms")
    public ResponseEntity<?> getRMS() {
        JSONObject response = smartConnect.getRMS();
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Failed to get RMS");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 13. Get Holding
    // GET /api/smart/order/holding
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get Holding", description = "Get current holdings")
    @GetMapping("/order/holding")
    public ResponseEntity<?> getHolding() {
        JSONObject response = smartConnect.getHolding();
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Failed to get holdings");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 14. Get All Holdings
    // GET /api/smart/order/all-holdings
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get All Holdings", description = "Get all holdings including summary")
    @GetMapping("/order/all-holdings")
    public ResponseEntity<?> getAllHolding() throws SmartAPIException, IOException {
        JSONObject response = smartConnect.getAllHolding();
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Failed to get all holdings");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 15. Get Position
    // GET /api/smart/order/position
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get Position", description = "Get current positions")
    @GetMapping("/order/position")
    public ResponseEntity<?> getPosition() {
        JSONObject response = smartConnect.getPosition();
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Failed to get positions");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 16. Convert Position
    // POST /api/smart/order/position/convert
    // Body: JSONObject params
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Convert Position", description = "Convert position from one product type to another")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(value = "{\"exchange\": \"NSE\", \"symboltoken\": \"3045\", \"tradingsymbol\": \"SBIN-EQ\", \"transactiontype\": \"BUY\", \"quantity\": 1, \"oldproducttype\": \"MIS\", \"newproducttype\": \"CNC\"}")))
    @PostMapping("/order/position/convert")
    public ResponseEntity<?> convertPosition(@RequestBody Map<String, Object> body) {
        if (paperTradingService.isPaperTradingEnabled()) {
            return ResponseEntity.badRequest().body("Direct SmartConnect position conversion is disabled during paper trading.");
        }
        paperTradingService.validateLiveOrderAllowed();
        JSONObject params = new JSONObject(body);
        JSONObject response = smartConnect.convertPosition(params);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Position conversion failed");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 17. Get Market Data
    // POST /api/smart/market/data
    // Body: { "mode": "FULL", "exchangeTokens": { "NSE": ["3045"] } }
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get Market Data", description = "Fetch market data for given instruments")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(value = "{\"mode\": \"FULL\", \"exchangeTokens\": {\"NSE\": [\"3045\"]}}")))
    @PostMapping("/market/data")
    public ResponseEntity<?> marketData(@RequestBody Map<String, Object> body) throws SmartAPIException, IOException {
        JSONObject params = new JSONObject(body);
        JSONObject response = smartConnect.marketData(params);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Failed to get market data");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 18. Get Candle Data (Historic)
    // POST /api/smart/market/candle
    // Body: { "exchange": "NSE", "symboltoken": "3045", "interval": "ONE_MINUTE", "fromdate": "...", "todate": "..." }
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get Candle Data", description = "Fetch historical candle/OHLC data")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(value = "{\"exchange\": \"NSE\", \"symboltoken\": \"3045\", \"interval\": \"ONE_MINUTE\", \"fromdate\": \"2024-01-01 09:15\", \"todate\": \"2024-01-01 15:30\"}")))
    @PostMapping("/market/candle")
    public ResponseEntity<?> candleData(@RequestBody Map<String, Object> body) {
        JSONObject params = new JSONObject(body);
        JSONArray response = smartConnect.candleData(params);
        return response != null ? ResponseEntity.ok(response.toList()) : ResponseEntity.badRequest().body("Failed to get candle data");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 19. Get OI Data
    // POST /api/smart/market/oi
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get OI Data", description = "Fetch Open Interest data")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(value = "{\"exchange\": \"NFO\", \"symboltoken\": \"3045\", \"interval\": \"ONE_MINUTE\", \"fromdate\": \"2024-01-01 09:15\", \"todate\": \"2024-01-01 15:30\"}")))
    @PostMapping("/market/oi")
    public ResponseEntity<?> oiData(@RequestBody Map<String, Object> body) {
        JSONObject params = new JSONObject(body);
        JSONArray response = smartConnect.oiData(params);
        return response != null ? ResponseEntity.ok(response.toList()) : ResponseEntity.badRequest().body("Failed to get OI data");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 20. Search Script
    // POST /api/smart/market/search-scrip
    // Body: { "exchange": "NSE", "searchscrip": "SBIN" }
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//    @PostMapping("/market/search-scrip")
//    public ResponseEntity<?> getSearchScrip(@RequestBody Map<String, Object> body) throws SmartAPIException, IOException {
//        try {
//            String searchscrip = (String) body.get("searchscrip");
//            String exchange = (String) body.get("exchange");
//
//            if (searchscrip == null || searchscrip.trim().isEmpty()) {
//                return ResponseEntity.badRequest().body("searchscrip is required");
//            }
//            String[] exchanges = (exchange != null && !exchange.trim().isEmpty())
//                    ? new String[]{exchange.trim().toUpperCase()}
//                    : new String[]{"NSE", "BSE"};
//
//            String mergedResults = new String();
//
//            for (String exch : exchanges) {
//                try {
//                    JSONObject params = new JSONObject();
//                    params.put("exchange", exch);
//                    params.put("searchscrip", searchscrip.trim());
//
//                    String response = smartConnect.getSearchScrip(params);
//                    mergedResults = mergedResults + response + "\n";
//                } catch (Exception e) {
//                }
//            }
//
//            return mergedResults != null ? ResponseEntity.ok(mergedResults) : ResponseEntity.badRequest().body("Search script failed");
//        } catch (Exception e) {
//            return ResponseEntity.badRequest().body("Search scrip failed: " + e.getMessage());
//        }
//    }
    @Operation(summary = "Search Scrip", description = "Search for equity scripts on NSE/BSE exchanges")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(
            value = "{\"exchange\": \"NSE\", \"searchscrip\": \"TATA\"}")))
    @PostMapping("/market/search-scrip")
    public ResponseEntity<?> getSearchScrip(@RequestBody Map<String, Object> body) {
        try {
            String searchscrip = (String) body.get("searchscrip");
            String exchange = (String) body.get("exchange");

            if (searchscrip == null || searchscrip.trim().isEmpty()) {
                return ResponseEntity.badRequest().body("searchscrip is required");
            }

            // ✅ Scrip master not ready yet — server just started
            if (!scripSearchService.isLoaded()) {
                return ResponseEntity.status(503)
                        .body("Scrip master is still loading, please try after few seconds");
            }

            // ✅ If exchange given use only that, else search both NSE & BSE
            String[] exchanges = (exchange != null && !exchange.trim().isEmpty())
                    ? new String[]{exchange.trim().toUpperCase()}
                    : new String[]{"NSE", "BSE","NFO"};

            JSONArray mergedResults = new JSONArray();

            // ✅ Single in-memory search — works for ALL brokers
            // Tokens are exchange-assigned, same across AngelOne, Motilal, etc.
            for (String exch : exchanges) {
                List<Map<String, String>> results = scripSearchService
                        .searchEquity(searchscrip.trim(), exch);

                for (Map<String, String> scrip : results) {
                    JSONObject obj = new JSONObject();
                    obj.put("symbolToken", scrip.get("token"));
                    obj.put("symbol", scrip.get("symbol"));
                    obj.put("tradingsymbol", scrip.get("symbol"));
                    obj.put("name", scrip.get("name"));
                    obj.put("exchange", scrip.get("exchange"));
                    obj.put("instrumentType", scrip.get("instrumentType"));
                    obj.put("lotSize", scrip.get("lotSize"));
                    obj.put("tickSize", scrip.get("tickSize"));
                    mergedResults.put(obj);
                }
            }

            JSONObject finalResponse = new JSONObject();
            finalResponse.put("status", true);
            finalResponse.put("message", mergedResults.length() > 0
                    ? "SUCCESS" : "No equity symbols found");
            finalResponse.put("totalCount", mergedResults.length());
            finalResponse.put("data", mergedResults);

            return ResponseEntity.ok(finalResponse.toString());

        } catch (Exception e) {
            Logger.getLogger(SmartConnectController.class.getName())
                    .log(Level.SEVERE, "Search scrip error: {0}", e.getMessage());
            return ResponseEntity.badRequest()
                    .body("Search scrip failed");
        }
    }

    /**
     * Parses plain text response and filters only regular buyable equity
     * symbols NSE → only -EQ suffix BSE → only symbols without any suffix ✅
     * Kept for reference — no longer used in getSearchScrip but may be needed
     * elsewhere in the controller
     */
    private JSONArray parsePlainTextResponse(String response) {
        JSONArray result = new JSONArray();

        if (response == null || response.trim().isEmpty()) {
            return result;
        }

        String[] lines = response.split("\\n");

        for (String line : lines) {
            line = line.trim();

            if (!line.matches("^\\d+\\..*")) {
                continue;
            }

            try {
                String content = line.replaceFirst("^\\d+\\.\\s*", "");
                String[] parts = content.split(",\\s*");

                JSONObject obj = new JSONObject();
                for (String part : parts) {
                    String[] kv = part.split(":\\s*", 2);
                    if (kv.length == 2) {
                        obj.put(kv[0].trim(), kv[1].trim());
                    }
                }

                String tradingsymbol = obj.optString("tradingsymbol", "");
                String exch = obj.optString("exchange", "");

                boolean isNseEquity = "NSE".equals(exch) && tradingsymbol.endsWith("-EQ");
                boolean isBseEquity = "BSE".equals(exch) && !tradingsymbol.contains("-");

                if (isNseEquity || isBseEquity) {
                    result.put(obj);
                }

            } catch (Exception e) {
                Logger.getLogger(SmartConnectController.class.getName())
                        .log(Level.WARNING, "Failed to parse line: {0}", line);
            }
        }

        return result;
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 21. GTT Create Rule
    // POST /api/smart/gtt/create
    // ─────────────────────────────────────────────────────────────
    @Operation(summary = "Create GTT Rule", description = "Create a Good Till Triggered order rule")
    @PostMapping("/gtt/create")
    public ResponseEntity<?> gttCreateRule(@RequestBody GttParams gttParams) {
        if (paperTradingService.isPaperTradingEnabled()) {
            return ResponseEntity.badRequest().body("Direct SmartConnect GTT operations are disabled during paper trading.");
        }
        paperTradingService.validateLiveOrderAllowed();
        Gtt gtt = smartConnect.gttCreateRule(gttParams);
        return gtt != null ? ResponseEntity.ok(gtt) : ResponseEntity.badRequest().body("GTT create failed");
    }

    // ─────────────────────────────────────────────────────────────
    // 22. GTT Modify Rule
    // PUT /api/smart/gtt/modify/{id}
    // ─────────────────────────────────────────────────────────────
    @Operation(summary = "Modify GTT Rule", description = "Modify an existing GTT rule")
    @PutMapping("/gtt/modify/{id}")
    public ResponseEntity<?> gttModifyRule(@Parameter(description = "GTT rule ID", example = "1001") @PathVariable Integer id, @RequestBody GttParams gttParams) {
        if (paperTradingService.isPaperTradingEnabled()) {
            return ResponseEntity.badRequest().body("Direct SmartConnect GTT operations are disabled during paper trading.");
        }
        paperTradingService.validateLiveOrderAllowed();
        Gtt gtt = smartConnect.gttModifyRule(id, gttParams);
        return gtt != null ? ResponseEntity.ok(gtt) : ResponseEntity.badRequest().body("GTT modify failed");
    }

    // ─────────────────────────────────────────────────────────────
    // 23. GTT Cancel Rule
    // DELETE /api/smart/gtt/cancel/{id}?symboltoken=XYZ&exchange=NSE
    // ─────────────────────────────────────────────────────────────
    @Operation(summary = "Cancel GTT Rule", description = "Cancel an existing GTT rule")
    @DeleteMapping("/gtt/cancel/{id}")
    public ResponseEntity<?> gttCancelRule(@Parameter(description = "GTT rule ID", example = "1001") @PathVariable Integer id,
            @Parameter(description = "Symbol token", example = "3045") @RequestParam String symboltoken,
            @Parameter(description = "Exchange", example = "NSE") @RequestParam String exchange) {
        if (paperTradingService.isPaperTradingEnabled()) {
            return ResponseEntity.badRequest().body("Direct SmartConnect GTT operations are disabled during paper trading.");
        }
        paperTradingService.validateLiveOrderAllowed();
        Gtt gtt = smartConnect.gttCancelRule(id, symboltoken, exchange);
        return gtt != null ? ResponseEntity.ok(gtt) : ResponseEntity.badRequest().body("GTT cancel failed");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 24. GTT Rule Details
    // GET /api/smart/gtt/details/{id}
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get GTT Rule Details", description = "Fetch details of a specific GTT rule")
    @GetMapping("/gtt/details/{id}")
    public ResponseEntity<?> gttRuleDetails(@Parameter(description = "GTT rule ID", example = "1001") @PathVariable Integer id) {
        JSONObject response = smartConnect.gttRuleDetails(id);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Failed to get GTT rule details");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 25. GTT Rule List
    // POST /api/smart/gtt/list
    // Body: { "status": ["NEW","CANCELLED"], "page": 1, "count": 10 }
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get GTT Rule List", description = "List GTT rules with status filter and pagination")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(value = "{\"status\": [\"NEW\", \"CANCELLED\"], \"page\": 1, \"count\": 10}")))
    @PostMapping("/gtt/list")
    public ResponseEntity<?> gttRuleList(@RequestBody Map<String, Object> body) {
        List<String> status = (List<String>) body.get("status");
        Integer page = (Integer) body.get("page");
        Integer count = (Integer) body.get("count");
        JSONArray response = smartConnect.gttRuleList(status, page, count);
        return response != null ? ResponseEntity.ok(response.toList()) : ResponseEntity.badRequest().body("Failed to get GTT rule list");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 26. Get Margin Details
    // POST /api/smart/margin/details
    // Body: List<MarginParams>
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get Margin Details", description = "Calculate margin required for given orders")
    @PostMapping("/margin/details")
    public ResponseEntity<?> getMarginDetails(@RequestBody List<MarginParams> marginParams) throws IOException, SmartAPIException {
        JSONObject response = smartConnect.getMarginDetails(marginParams);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Failed to get margin details");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 27. Estimate Charges
    // POST /api/smart/order/estimate-charges
    // Body: List<EstimateChargesParams>
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Estimate Charges", description = "Estimate brokerage and other charges for orders")
    @PostMapping("/order/estimate-charges")
    public ResponseEntity<?> estimateCharges(@RequestBody List<EstimateChargesParams> params) throws IOException, SmartAPIException {
        JSONObject response = smartConnect.estimateCharges(params);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Failed to estimate charges");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 28. Verify DIS
    // POST /api/smart/dis/verify
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Verify DIS", description = "Verify Delivery Instruction Slip")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(value = "{\"isin\": \"INE062A01020\", \"quantity\": 1}")))
    @PostMapping("/dis/verify")
    public ResponseEntity<?> verifyDis(@RequestBody Map<String, Object> body) throws SmartAPIException, IOException {
        JSONObject params = new JSONObject(body);
        JSONObject response = smartConnect.verifyDis(params);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Verify DIS failed");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 29. Generate TPIN
    // POST /api/smart/dis/generate-tpin
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Generate TPIN", description = "Generate TPIN for CDSL authorization")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(value = "{\"dpId\": \"12345\", \"reqId\": \"req-001\"}")))
    @PostMapping("/dis/generate-tpin")
    public ResponseEntity<?> generateTPIN(@RequestBody Map<String, Object> body) throws SmartAPIException, IOException {
        JSONObject params = new JSONObject(body);
        JSONObject response = smartConnect.generateTPIN(params);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Generate TPIN failed");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 30. Get Transaction Status
    // POST /api/smart/dis/transaction-status
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get Transaction Status", description = "Get DIS transaction status")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(value = "{\"reqId\": \"req-001\"}")))
    @PostMapping("/dis/transaction-status")
    public ResponseEntity<?> getTranStatus(@RequestBody Map<String, Object> body) throws SmartAPIException, IOException {
        JSONObject params = new JSONObject(body);
        JSONObject response = smartConnect.getTranStatus(params);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Get transaction status failed");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 31. Option Greek
    // POST /api/smart/option/greek
    // Body: { "name": "NIFTY", "expirydate": "27APR2023" }
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get Option Greek", description = "Fetch option greeks for a specific instrument")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(value = "{\"name\": \"NIFTY\", \"expirydate\": \"27APR2025\"}")))
    @PostMapping("/option/greek")
    public ResponseEntity<?> optionGreek(@RequestBody Map<String, Object> body) throws SmartAPIException, IOException {
        JSONObject params = new JSONObject(body);
        JSONObject response = smartConnect.optionGreek(params);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Option Greek failed");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 32. Gainers / Losers
    // POST /api/smart/market/gainers-losers
    // Body: { "datatype": "PercPriceLosers", "expirytype": "NEAR" }
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get Gainers/Losers", description = "Fetch top gainers and losers")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(value = "{\"datatype\": \"PercPriceLosers\", \"expirytype\": \"NEAR\"}")))
    @PostMapping("/market/gainers-losers")
    public ResponseEntity<?> gainersLosers(@RequestBody Map<String, Object> body) throws SmartAPIException, IOException {
        JSONObject params = new JSONObject(body);
        JSONObject response = smartConnect.gainersLosers(params);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Gainers/Losers failed");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 33. Put Call Ratio
    // GET /api/smart/market/put-call-ratio
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get Put Call Ratio", description = "Fetch the current Put/Call ratio")
    @GetMapping("/market/put-call-ratio")
    public ResponseEntity<?> putCallRatio() throws IOException, SmartAPIException {
        JSONObject response = smartConnect.putCallRatio();
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("Failed to get Put Call Ratio");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 34. NSE Intraday
    // GET /api/smart/market/nse-intraday
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "NSE Intraday Data", description = "Get NSE intraday data")
    @GetMapping("/market/nse-intraday")
    public ResponseEntity<?> nseIntraday() throws IOException, SmartAPIException {
        JSONObject response = smartConnect.nseIntraday();
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("NSE Intraday failed");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 35. BSE Intraday
    // GET /api/smart/market/bse-intraday
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "BSE Intraday Data", description = "Get BSE intraday data")
    @GetMapping("/market/bse-intraday")
    public ResponseEntity<?> bseIntraday() throws IOException, SmartAPIException {
        JSONObject response = smartConnect.bseIntraday();
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("BSE Intraday failed");
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // 36. OI Buildup
    // POST /api/smart/market/oi-buildup
    // Body: { "expirytype": "NEAR", "datatype": "Long Build Up" }
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @Operation(summary = "Get OI Buildup", description = "Fetch Open Interest buildup data")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(content = @Content(examples = @ExampleObject(value = "{\"expirytype\": \"NEAR\", \"datatype\": \"Long Build Up\"}")))
    @PostMapping("/market/oi-buildup")
    public ResponseEntity<?> oIBuildup(@RequestBody Map<String, Object> body) throws SmartAPIException, IOException {
        JSONObject params = new JSONObject(body);
        JSONObject response = smartConnect.oIBuildup(params);
        return response != null ? ResponseEntity.ok(response.toMap()) : ResponseEntity.badRequest().body("OI Buildup failed");
    }
}
