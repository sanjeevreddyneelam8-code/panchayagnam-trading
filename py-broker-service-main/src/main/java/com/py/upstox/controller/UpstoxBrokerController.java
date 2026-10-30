package com.py.upstox.controller;

import com.py.upstox.dto.*;
import com.py.upstox.service.UpstoxApiService;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/upstox")
@CrossOrigin(origins = "*")
public class UpstoxBrokerController {

    private static final Logger log = LoggerFactory.getLogger(UpstoxBrokerController.class);

    @Autowired
    private UpstoxApiService upstoxApiService;

    @PostMapping("/login")
    public ResponseEntity<String> login(@RequestBody UpstoxLoginRequest request) {
        log.info("Upstox login | clientId={}", request.getClientId());
        JSONObject response = upstoxApiService.login(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/rms")
    public ResponseEntity<String> getFunds(@RequestBody UpstoxBaseRequest request) {
        log.info("Upstox funds/RMS | clientId={}", request.getClientId());
        JSONObject response = upstoxApiService.getFunds(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/place")
    public ResponseEntity<String> placeOrder(@RequestBody UpstoxPlaceOrderRequest request) {
        log.info("Upstox place order | clientId={} instrument={}", request.getClientId(), request.getInstrumentToken());
        JSONObject response = upstoxApiService.placeOrder(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/modify")
    public ResponseEntity<String> modifyOrder(@RequestBody UpstoxModifyOrderRequest request) {
        log.info("Upstox modify order | clientId={} orderId={}", request.getClientId(), request.getOrderId());
        JSONObject response = upstoxApiService.modifyOrder(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/cancel")
    public ResponseEntity<String> cancelOrder(@RequestBody UpstoxCancelOrderRequest request) {
        log.info("Upstox cancel order | clientId={} orderId={}", request.getClientId(), request.getOrderId());
        JSONObject response = upstoxApiService.cancelOrder(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/positions")
    public ResponseEntity<String> getPositions(@RequestBody UpstoxBaseRequest request) {
        log.info("Upstox positions | clientId={}", request.getClientId());
        JSONObject response = upstoxApiService.getPositions(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/holdings")
    public ResponseEntity<String> getHoldings(@RequestBody UpstoxBaseRequest request) {
        log.info("Upstox holdings | clientId={}", request.getClientId());
        JSONObject response = upstoxApiService.getHoldings(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/history")
    public ResponseEntity<String> getOrderHistory(@RequestBody UpstoxBaseRequest request) {
        log.info("Upstox order history | clientId={}", request.getClientId());
        JSONObject response = upstoxApiService.getOrderBook(request);
        return ResponseEntity.ok(response.toString());
    }
}
