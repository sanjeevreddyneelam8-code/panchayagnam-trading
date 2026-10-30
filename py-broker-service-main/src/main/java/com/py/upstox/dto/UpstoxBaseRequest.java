package com.py.upstox.dto;

import lombok.Data;

@Data
public class UpstoxBaseRequest {
    private String clientId;
    private String accessToken;
}
