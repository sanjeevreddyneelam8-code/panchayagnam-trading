package com.py.goodwill.controller;

import com.py.goodwill.dto.*;
import com.py.goodwill.service.GoodwillApiService;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/goodwill")
@CrossOrigin(origins = "*")
public class GoodwillBrokerController {

    private static final Logger log = LoggerFactory.getLogger(GoodwillBrokerController.class);

    @Autowired
    private GoodwillApiService goodwillApiService;

    @PostMapping("/login")
    public ResponseEntity<String> login(@RequestBody GoodwillLoginRequest request) {
        log.info("Goodwill login | clientId={}", request.getClientId());
        JSONObject response = goodwillApiService.login(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/rms")
    public ResponseEntity<String> getLimits(@RequestBody GoodwillBaseRequest request) {
        log.info("Goodwill limits/RMS | clientId={}", request.getClientId());
        JSONObject response = goodwillApiService.getLimits(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/place")
    public ResponseEntity<String> placeOrder(@RequestBody GoodwillPlaceOrderRequest request) {
        log.info("Goodwill place order | clientId={} side={}", request.getClientId(), request.getOrderSide());
        JSONObject response = goodwillApiService.placeOrder(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/modify")
    public ResponseEntity<String> modifyOrder(@RequestBody GoodwillModifyOrderRequest request) {
        log.info("Goodwill modify order | clientId={} appOrderId={}", request.getClientId(), request.getAppOrderId());
        JSONObject response = goodwillApiService.modifyOrder(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/cancel")
    public ResponseEntity<String> cancelOrder(@RequestBody GoodwillCancelOrderRequest request) {
        log.info("Goodwill cancel order | clientId={} appOrderId={}", request.getClientId(), request.getAppOrderId());
        JSONObject response = goodwillApiService.cancelOrder(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/positions")
    public ResponseEntity<String> getPositions(@RequestBody GoodwillBaseRequest request) {
        log.info("Goodwill positions | clientId={}", request.getClientId());
        JSONObject response = goodwillApiService.getPositions(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/holdings")
    public ResponseEntity<String> getHoldings(@RequestBody GoodwillBaseRequest request) {
        log.info("Goodwill holdings | clientId={}", request.getClientId());
        JSONObject response = goodwillApiService.getHoldings(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/history")
    public ResponseEntity<String> getOrderHistory(@RequestBody GoodwillBaseRequest request) {
        log.info("Goodwill order history | clientId={}", request.getClientId());
        JSONObject response = goodwillApiService.getOrderBook(request);
        return ResponseEntity.ok(response.toString());
    }
}
