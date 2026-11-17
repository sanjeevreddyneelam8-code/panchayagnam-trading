package com.py.utils;

import com.py.brokers.angel.client.service.AngelOneApisService;
import com.py.brokers.angel.dto.AngelOneCancelOrderRequest;
import com.py.brokers.angel.dto.AngelOneConvertPositionRequest;
import com.py.brokers.angel.dto.AngelOneLoginRequest;
import com.py.brokers.angel.dto.AngelOneLtpRequest;
import com.py.brokers.angel.dto.AngelOneModifyOrderRequest;
import com.py.brokers.angel.dto.AngelOneOrderHistoryRequest;
import com.py.brokers.angel.dto.AngelOnePlaceOrderRequest;
import com.py.brokers.angel.dto.AngelOneRMSRequest;
import java.util.concurrent.CompletableFuture;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

@Service
public class AngelOneMicroserviceClient {

    private final WebClient.Builder webClientBuilder;
    @Autowired
    private AngelOneApisService angelOneApisService;
    private static final Logger log = LoggerFactory.getLogger(AngelOneMicroserviceClient.class);

    public AngelOneMicroserviceClient(WebClient.Builder webClientBuilder) {
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

    // ─── LOGIN ───────────────────────────────────────────────────────────────
    public JSONObject login(String baseUrl, String clientCode,
            String password, String totp, String apiKey) {
        log.info("AngelOne login request | baseUrl={} clientCode={}", baseUrl, clientCode);

        AngelOneLoginRequest request = new AngelOneLoginRequest();
        request.setClientCode(clientCode);
        request.setPassword(password);
        request.setTotp(totp);
        request.setApiKey(apiKey);

        return angelOneApisService.login(request);
    }

    // ─── PLACE ORDER ─────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> placeOrder(
            String baseUrl, AngelOnePlaceOrderRequest request) {
        log.info("AngelOne direct place order request | symbol={} qty={} type={}",
                request.getTradingsymbol(),
                request.getQuantity(), request.getTransactiontype());

        return CompletableFuture.supplyAsync(() -> angelOneApisService.placeOrder(request));
    }

    // ─── MODIFY ORDER ────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> modifyOrder(
            String baseUrl, AngelOneModifyOrderRequest request) {
        log.info("AngelOne direct modify order request | orderId={} symbol={} qty={} price={}",
                request.getOrderId(), request.getTradingSymbol(),
                request.getQuantity(), request.getPrice());

        return CompletableFuture.supplyAsync(() -> angelOneApisService.modifyOrder(request));
    }

    // ─── CANCEL ORDER ────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> cancelOrder(
            String baseUrl, AngelOneCancelOrderRequest request) {
        log.info("AngelOne direct cancel order request | orderId={} variety={}",
                request.getOrderId(), request.getVariety());

        return CompletableFuture.supplyAsync(() -> angelOneApisService.cancelOrder(request));
    }

    // ─── ORDER HISTORY ───────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> getOrderHistory(String baseUrl,
            String apiKey, String accessToken) {
        log.info("AngelOne order history request | baseUrl={}", baseUrl);

        AngelOneOrderHistoryRequest request = new AngelOneOrderHistoryRequest();
        request.setApiKey(apiKey);
        request.setAccessToken(accessToken);

        return CompletableFuture.supplyAsync(() -> angelOneApisService.getOrderHistory(request));
    }

    // ─── RMS ─────────────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> getRMS(String baseUrl,
            String apiKey, String accessToken) {
        log.info("AngelOne RMS request | baseUrl={}", baseUrl);

        AngelOneRMSRequest request = new AngelOneRMSRequest();
        request.setApiKey(apiKey);
        request.setAccessToken(accessToken);

        return CompletableFuture.supplyAsync(() -> angelOneApisService.getRMS(request));
    }

    // ─── LTP ─────────────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> getLTP(String baseUrl,
            String apiKey, String accessToken,
            String exchange, String tradingSymbol, String symbolToken) {
        log.info("AngelOne LTP request | baseUrl={} exchange={} symbol={} token={}",
                baseUrl, exchange, tradingSymbol, symbolToken);

        AngelOneLtpRequest request = new AngelOneLtpRequest();
        request.setApiKey(apiKey);
        request.setAccessToken(accessToken);
        request.setExchange(exchange);
        request.setTradingSymbol(tradingSymbol);
        request.setSymbolToken(symbolToken);

        return CompletableFuture.supplyAsync(() -> angelOneApisService.getLTP(request));
    }

    // ─── CONVERT POSITION ────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> convertPosition(String baseUrl,
            AngelOneConvertPositionRequest request) {
        log.info("AngelOne direct convert position request | symbol={} {} -> {}",
                request.getTradingsymbol(),
                request.getOldproducttype(), request.getNewproducttype());

        return CompletableFuture.supplyAsync(() -> angelOneApisService.convertPosition(request));
    }
}
