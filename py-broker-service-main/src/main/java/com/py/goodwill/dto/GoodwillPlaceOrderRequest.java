package com.py.goodwill.dto;

import lombok.Data;

@Data
public class GoodwillPlaceOrderRequest {
    private String clientId;
    private String accessToken;
    private String exchangeSegment;
    private Integer exchangeInstrumentId;
    private String productType;
    private String orderType;
    private String orderSide;
    private String timeInForce;
    private Integer disclosedQuantity;
    private Integer orderQuantity;
    private Double limitPrice;
    private Double stopPrice;
    private String orderUniqueIdentifier;
}
