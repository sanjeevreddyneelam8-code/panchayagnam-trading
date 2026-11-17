package com.py.utils;

import com.py.brokers.dhan.DhanAccountService;
import com.py.brokers.dhan.dto.DhanCancelOrderRequest;
import com.py.brokers.dhan.dto.DhanModifyOrderParams;
import com.py.brokers.dhan.dto.DhanModifyOrderRequest;
import com.py.brokers.dhan.dto.DhanOrderParams;
import com.py.brokers.dhan.dto.DhanPlaceOrderRequest;
import java.util.concurrent.CompletableFuture;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

@Service
public class DhanMicroserviceClient {

    private static final Logger log = LoggerFactory.getLogger(DhanMicroserviceClient.class);

    @Autowired
    private DhanAccountService dhanAccountService;

    public DhanMicroserviceClient(WebClient.Builder webClientBuilder) {
    }

    // ─── LOGIN ────────────────────────────────────────────────────────────────
    public JSONObject login(String baseUrl, String clientId,
            String mpin, String totp) {
        log.info("Dhan direct login request | clientId={}", clientId);
        return dhanAccountService.login(clientId, mpin, totp);
    }

    // ─── RMS ──────────────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> getRMS(String baseUrl,
            String clientId, String accessToken) {
        log.info("Dhan direct RMS request | clientId={}", clientId);
        return CompletableFuture.supplyAsync(() -> dhanAccountService.getFundLimit(clientId, accessToken));
    }

    // ─── PLACE ORDER ──────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> placeOrder(String baseUrl,
            DhanPlaceOrderRequest request) {
        log.info("Dhan direct place order request | clientId={} securityId={} side={}",
                request.getClientId(), request.getSecurityId(), request.getTransactionType());

        return CompletableFuture.supplyAsync(() -> {
            DhanOrderParams params = new DhanOrderParams();
            params.setDhanClientId(request.getDhanClientId() != null ? request.getDhanClientId() : request.getClientId());
            params.setCorrelationId(request.getCorrelationId());
            params.setTransactionType(request.getTransactionType());
            params.setExchangeSegment(request.getExchangeSegment());
            params.setProductType(request.getProductType());
            params.setOrderType(request.getOrderType());
            params.setValidity(request.getValidity() != null ? request.getValidity() : "DAY");
            params.setSecurityId(request.getSecurityId());
            params.setQuantity(request.getQuantity() != null ? request.getQuantity() : 1);
            params.setDisclosedQuantity(request.getDisclosedQuantity() != null ? request.getDisclosedQuantity() : 0);
            params.setPrice(request.getPrice() != null ? request.getPrice() : 0.0);
            params.setTriggerPrice(request.getTriggerPrice() != null ? request.getTriggerPrice() : 0.0);
            params.setAfterMarketOrder(request.isAfterMarketOrder());
            params.setAmoTime(request.getAmoTime());
            return dhanAccountService.placeOrder(params, request.getAccessToken());
        });
    }

    // ─── MODIFY ORDER ─────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> modifyOrder(String baseUrl,
            DhanModifyOrderRequest request) {
        log.info("Dhan direct modify order request | clientId={} orderId={}",
                request.getClientId(), request.getOrderId());

        return CompletableFuture.supplyAsync(() -> {
            DhanModifyOrderParams params = new DhanModifyOrderParams();
            params.setDhanClientId(request.getDhanClientId() != null ? request.getDhanClientId() : request.getClientId());
            params.setOrderId(request.getOrderId());
            params.setOrderType(request.getOrderType());
            params.setQuantity(request.getQuantity() != null ? request.getQuantity() : 1);
            params.setDisclosedQuantity(request.getDisclosedQuantity() != null ? request.getDisclosedQuantity() : 0);
            params.setValidity(request.getValidity() != null ? request.getValidity() : "DAY");
            params.setPrice(request.getPrice() != null ? request.getPrice() : 0.0);
            params.setTriggerPrice(request.getTriggerPrice() != null ? request.getTriggerPrice() : 0.0);
            return dhanAccountService.modifyOrder(params, request.getAccessToken());
        });
    }

    // ─── CANCEL ORDER ─────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> cancelOrder(String baseUrl,
            DhanCancelOrderRequest request) {
        log.info("Dhan direct cancel order request | clientId={} orderId={}",
                request.getClientId(), request.getOrderId());
        return CompletableFuture.supplyAsync(() ->
                dhanAccountService.cancelOrder(request.getClientId(), request.getOrderId(), request.getAccessToken()));
    }

    // ─── ORDER HISTORY ────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> getOrderHistory(String baseUrl,
            String clientId, String accessToken) {
        log.info("Dhan direct order history request | clientId={}", clientId);
        return CompletableFuture.supplyAsync(() -> dhanAccountService.getOrderBook(clientId, accessToken));
    }

    // ─── HOLDINGS ─────────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> getHoldings(String baseUrl,
            String clientId, String accessToken) {
        log.info("Dhan direct holdings request | clientId={}", clientId);
        return CompletableFuture.supplyAsync(() -> dhanAccountService.getHoldings(clientId, accessToken));
    }

    // ─── POSITIONS ────────────────────────────────────────────────────────────
    public CompletableFuture<JSONObject> getPositions(String baseUrl,
            String clientId, String accessToken) {
        log.info("Dhan direct positions request | clientId={}", clientId);
        return CompletableFuture.supplyAsync(() -> dhanAccountService.getPositions(clientId, accessToken));
    }
}