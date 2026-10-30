package com.py.utils;

import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.Map;
import java.util.concurrent.CompletableFuture;

@Service
public class ZerodhaMicroserviceClient {

    private static final Logger log = LoggerFactory.getLogger(ZerodhaMicroserviceClient.class);

    private final WebClient.Builder webClientBuilder;

    public ZerodhaMicroserviceClient(WebClient.Builder webClientBuilder) {
        this.webClientBuilder = webClientBuilder;
    }

    private WebClient clientFor(String baseUrl) {
        return webClientBuilder
                .baseUrl(baseUrl)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(10 * 1024 * 1024))
                .build();
    }

    public JSONObject login(String baseUrl, String clientId, String apiKey, String apiSecret, String requestToken) {
        log.info("Zerodha login request | baseUrl={} clientId={}", baseUrl, clientId);

        Map<String, String> body = Map.of(
                "clientId", clientId != null ? clientId : "",
                "apiKey", apiKey != null ? apiKey : "",
                "apiSecret", apiSecret != null ? apiSecret : "",
                "requestToken", requestToken != null ? requestToken : ""
        );

        String raw = clientFor(baseUrl).post()
                .uri("/api/zerodha/login")
                .bodyValue(body)
                .retrieve()
                .onStatus(HttpStatusCode::isError, res ->
                        res.bodyToMono(String.class).map(b -> new RuntimeException("Zerodha login failed: " + b)))
                .bodyToMono(String.class)
                .block();

        return new JSONObject(raw != null ? raw : "{}");
    }

    public CompletableFuture<JSONObject> getRms(String baseUrl, String clientId, String apiKey, String accessToken) {
        Map<String, String> body = Map.of(
                "clientId", clientId != null ? clientId : "",
                "apiKey", apiKey != null ? apiKey : "",
                "accessToken", accessToken != null ? accessToken : ""
        );

        return clientFor(baseUrl).post()
                .uri("/api/zerodha/rms")
                .bodyValue(body)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> getPositions(String baseUrl, String clientId, String apiKey, String accessToken) {
        Map<String, String> body = Map.of(
                "clientId", clientId != null ? clientId : "",
                "apiKey", apiKey != null ? apiKey : "",
                "accessToken", accessToken != null ? accessToken : ""
        );

        return clientFor(baseUrl).post()
                .uri("/api/zerodha/positions")
                .bodyValue(body)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> getHoldings(String baseUrl, String clientId, String apiKey, String accessToken) {
        Map<String, String> body = Map.of(
                "clientId", clientId != null ? clientId : "",
                "apiKey", apiKey != null ? apiKey : "",
                "accessToken", accessToken != null ? accessToken : ""
        );

        return clientFor(baseUrl).post()
                .uri("/api/zerodha/holdings")
                .bodyValue(body)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> getOrderHistory(String baseUrl, String clientId, String apiKey, String accessToken) {
        Map<String, String> body = Map.of(
                "clientId", clientId != null ? clientId : "",
                "apiKey", apiKey != null ? apiKey : "",
                "accessToken", accessToken != null ? accessToken : ""
        );

        return clientFor(baseUrl).post()
                .uri("/api/zerodha/order/history")
                .bodyValue(body)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> placeOrder(String baseUrl, Map<String, Object> orderPayload) {
        return clientFor(baseUrl).post()
                .uri("/api/zerodha/order/place")
                .bodyValue(orderPayload)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> modifyOrder(String baseUrl, Map<String, Object> orderPayload) {
        return clientFor(baseUrl).post()
                .uri("/api/zerodha/order/modify")
                .bodyValue(orderPayload)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> cancelOrder(String baseUrl, Map<String, Object> orderPayload) {
        return clientFor(baseUrl).post()
                .uri("/api/zerodha/order/cancel")
                .bodyValue(orderPayload)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }
}
