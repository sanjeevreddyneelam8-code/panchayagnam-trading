package com.py.zerodha.dto;

import lombok.Data;

@Data
public class ZerodhaModifyOrderRequest {
    private String clientId;
    private String apiKey;
    private String accessToken;
    private String orderId;
    private Integer quantity;
    private Double price;
    private Double triggerPrice;
    private String orderType;
    private String validity;
    private Integer disclosedQuantity;
}
