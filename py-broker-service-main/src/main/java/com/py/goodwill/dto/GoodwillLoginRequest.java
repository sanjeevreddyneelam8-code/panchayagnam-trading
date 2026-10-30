package com.py.goodwill.dto;

import lombok.Data;

@Data
public class GoodwillLoginRequest {
    private String clientId;
    private String apiKey;
    private String apiSecret;
    private String password;
}
