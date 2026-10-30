package com.py.upstox.dto;

import lombok.Data;

@Data
public class UpstoxLoginRequest {
    private String clientId;
    private String apiKey;
    private String apiSecret;
    private String code;
    private String redirectUri;
}
