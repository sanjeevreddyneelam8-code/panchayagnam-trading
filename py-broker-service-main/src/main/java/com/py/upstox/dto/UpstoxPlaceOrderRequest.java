package com.py.upstox.dto;

import lombok.Data;

@Data
public class UpstoxPlaceOrderRequest {
    private String clientId;
    private String accessToken;
    private Integer quantity;
    private String product;
    private String validity;
    private Double price;
    private String tag;
    private String instrumentToken;
    private String orderType;
    private String transactionType;
    private Integer disclosedQuantity;
    private Double triggerPrice;
    private Boolean isAmo;
}
