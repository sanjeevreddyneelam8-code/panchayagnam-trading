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
public class UpstoxMicroserviceClient {

    private static final Logger log = LoggerFactory.getLogger(UpstoxMicroserviceClient.class);

    private final WebClient.Builder webClientBuilder;

    public UpstoxMicroserviceClient(WebClient.Builder webClientBuilder) {
        this.webClientBuilder = webClientBuilder;
    }

    private WebClient clientFor(String baseUrl) {
        return webClientBuilder
                .baseUrl(baseUrl)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(10 * 1024 * 1024))
                .build();
    }

    public JSONObject login(String baseUrl, String clientId, String apiKey, String apiSecret, String code, String redirectUri) {
        log.info("Upstox login request | baseUrl={} clientId={}", baseUrl, clientId);

        Map<String, String> body = Map.of(
                "clientId", clientId != null ? clientId : "",
                "apiKey", apiKey != null ? apiKey : "",
                "apiSecret", apiSecret != null ? apiSecret : "",
                "code", code != null ? code : "",
                "redirectUri", redirectUri != null ? redirectUri : ""
        );

        String raw = clientFor(baseUrl).post()
                .uri("/api/upstox/login")
                .bodyValue(body)
                .retrieve()
                .onStatus(HttpStatusCode::isError, res ->
                        res.bodyToMono(String.class).map(b -> new RuntimeException("Upstox login failed: " + b)))
                .bodyToMono(String.class)
                .block();

        return new JSONObject(raw != null ? raw : "{}");
    }

    public CompletableFuture<JSONObject> getFunds(String baseUrl, String clientId, String accessToken) {
        Map<String, String> body = Map.of(
                "clientId", clientId != null ? clientId : "",
                "accessToken", accessToken != null ? accessToken : ""
        );

        return clientFor(baseUrl).post()
                .uri("/api/upstox/rms")
                .bodyValue(body)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> getPositions(String baseUrl, String clientId, String accessToken) {
        Map<String, String> body = Map.of(
                "clientId", clientId != null ? clientId : "",
                "accessToken", accessToken != null ? accessToken : ""
        );

        return clientFor(baseUrl).post()
                .uri("/api/upstox/positions")
                .bodyValue(body)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> getHoldings(String baseUrl, String clientId, String accessToken) {
        Map<String, String> body = Map.of(
                "clientId", clientId != null ? clientId : "",
                "accessToken", accessToken != null ? accessToken : ""
        );

        return clientFor(baseUrl).post()
                .uri("/api/upstox/holdings")
                .bodyValue(body)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> getOrderHistory(String baseUrl, String clientId, String accessToken) {
        Map<String, String> body = Map.of(
                "clientId", clientId != null ? clientId : "",
                "accessToken", accessToken != null ? accessToken : ""
        );

        return clientFor(baseUrl).post()
                .uri("/api/upstox/order/history")
                .bodyValue(body)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> placeOrder(String baseUrl, Map<String, Object> orderPayload) {
        return clientFor(baseUrl).post()
                .uri("/api/upstox/order/place")
                .bodyValue(orderPayload)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> modifyOrder(String baseUrl, Map<String, Object> orderPayload) {
        return clientFor(baseUrl).post()
                .uri("/api/upstox/order/modify")
                .bodyValue(orderPayload)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }

    public CompletableFuture<JSONObject> cancelOrder(String baseUrl, Map<String, Object> orderPayload) {
        return clientFor(baseUrl).post()
                .uri("/api/upstox/order/cancel")
                .bodyValue(orderPayload)
                .retrieve()
                .bodyToMono(String.class)
                .map(raw -> new JSONObject(raw != null ? raw : "{}"))
                .toFuture();
    }
}
