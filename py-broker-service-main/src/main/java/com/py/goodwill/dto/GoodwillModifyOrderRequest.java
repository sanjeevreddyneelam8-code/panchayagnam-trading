package com.py.goodwill.dto;

import lombok.Data;

@Data
public class GoodwillModifyOrderRequest {
    private String clientId;
    private String accessToken;
    private String appOrderId;
    private String modifiedProductType;
    private String modifiedOrderType;
    private Integer modifiedOrderQuantity;
    private Integer modifiedDisclosedQuantity;
    private Double modifiedLimitPrice;
    private Double modifiedStopPrice;
    private String modifiedTimeInForce;
}
