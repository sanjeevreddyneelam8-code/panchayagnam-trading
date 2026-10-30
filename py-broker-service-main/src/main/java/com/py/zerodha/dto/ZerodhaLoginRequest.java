package com.py.zerodha.dto;

import lombok.Data;

@Data
public class ZerodhaLoginRequest {
    private String clientId;
    private String apiKey;
    private String apiSecret;
    private String requestToken;
}
