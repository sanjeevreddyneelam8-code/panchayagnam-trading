package com.py.zerodha.dto;

import lombok.Data;

@Data
public class ZerodhaBaseRequest {
    private String clientId;
    private String apiKey;
    private String accessToken;
}
