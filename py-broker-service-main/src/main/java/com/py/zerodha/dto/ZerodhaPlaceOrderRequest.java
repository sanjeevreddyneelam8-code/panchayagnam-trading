package com.py.zerodha.dto;

import lombok.Data;

@Data
public class ZerodhaPlaceOrderRequest {
    private String clientId;
    private String apiKey;
    private String accessToken;
    private String exchange;
    private String tradingsymbol;
    private String transactionType;
    private String orderType;
    private Integer quantity;
    private String product;
    private Double price;
    private Double triggerPrice;
    private String validity;
    private Integer disclosedQuantity;
    private String tag;
}
