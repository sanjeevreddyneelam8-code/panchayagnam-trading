package com.py.goodwill.dto;

import lombok.Data;

@Data
public class GoodwillCancelOrderRequest {
    private String clientId;
    private String accessToken;
    private String appOrderId;
}
