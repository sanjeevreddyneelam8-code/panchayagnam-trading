package com.py.upstox.dto;

import lombok.Data;

@Data
public class UpstoxCancelOrderRequest {
    private String clientId;
    private String accessToken;
    private String orderId;
}
