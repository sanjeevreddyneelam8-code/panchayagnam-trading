package com.py.upstox.dto;

import lombok.Data;

@Data
public class UpstoxModifyOrderRequest {
    private String clientId;
    private String accessToken;
    private String orderId;
    private Integer quantity;
    private String validity;
    private Double price;
    private String orderType;
    private Integer disclosedQuantity;
    private Double triggerPrice;
}
