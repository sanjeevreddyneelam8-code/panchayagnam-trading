package com.py.zerodha.dto;

import lombok.Data;

@Data
public class ZerodhaCancelOrderRequest {
    private String clientId;
    private String apiKey;
    private String accessToken;
    private String orderId;
    private String variety;
}
