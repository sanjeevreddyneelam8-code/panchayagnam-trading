package com.py.zerodha.controller;

import com.py.zerodha.dto.*;
import com.py.zerodha.service.ZerodhaApiService;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/zerodha")
@CrossOrigin(origins = "*")
public class ZerodhaBrokerController {

    private static final Logger log = LoggerFactory.getLogger(ZerodhaBrokerController.class);

    @Autowired
    private ZerodhaApiService zerodhaApiService;

    @PostMapping("/login")
    public ResponseEntity<String> login(@RequestBody ZerodhaLoginRequest request) {
        log.info("Zerodha login | clientId={}", request.getClientId());
        JSONObject response = zerodhaApiService.login(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/rms")
    public ResponseEntity<String> getMargins(@RequestBody ZerodhaBaseRequest request) {
        log.info("Zerodha margins/RMS | clientId={}", request.getClientId());
        JSONObject response = zerodhaApiService.getMargins(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/place")
    public ResponseEntity<String> placeOrder(@RequestBody ZerodhaPlaceOrderRequest request) {
        log.info("Zerodha place order | clientId={} symbol={}", request.getClientId(), request.getTradingsymbol());
        JSONObject response = zerodhaApiService.placeOrder(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/modify")
    public ResponseEntity<String> modifyOrder(@RequestBody ZerodhaModifyOrderRequest request) {
        log.info("Zerodha modify order | clientId={} orderId={}", request.getClientId(), request.getOrderId());
        JSONObject response = zerodhaApiService.modifyOrder(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/cancel")
    public ResponseEntity<String> cancelOrder(@RequestBody ZerodhaCancelOrderRequest request) {
        log.info("Zerodha cancel order | clientId={} orderId={}", request.getClientId(), request.getOrderId());
        JSONObject response = zerodhaApiService.cancelOrder(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/positions")
    public ResponseEntity<String> getPositions(@RequestBody ZerodhaBaseRequest request) {
        log.info("Zerodha positions | clientId={}", request.getClientId());
        JSONObject response = zerodhaApiService.getPositions(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/holdings")
    public ResponseEntity<String> getHoldings(@RequestBody ZerodhaBaseRequest request) {
        log.info("Zerodha holdings | clientId={}", request.getClientId());
        JSONObject response = zerodhaApiService.getHoldings(request);
        return ResponseEntity.ok(response.toString());
    }

    @PostMapping("/order/history")
    public ResponseEntity<String> getOrderHistory(@RequestBody ZerodhaBaseRequest request) {
        log.info("Zerodha order history | clientId={}", request.getClientId());
        JSONObject response = zerodhaApiService.getOrderBook(request);
        return ResponseEntity.ok(response.toString());
    }
}
