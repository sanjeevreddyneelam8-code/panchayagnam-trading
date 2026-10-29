package com.py.brokers.upstox.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

import java.util.concurrent.CompletableFuture;

/**
 * Service for Upstox Broker Integration.
 *
 * NOTE: Automated Selenium browser scraping and hardcoded credentials have been completely
 * removed for security and SEBI regulatory compliance. Upstox account login will be enabled
 * via official OAuth 2.0 Authorization Code flow in Phase 2.
 */
@RestController
public class UpstoxAuthService {

    private static final Logger log = LoggerFactory.getLogger(UpstoxAuthService.class);

    private CompletableFuture<String> tokenFuture = new CompletableFuture<>();

    @GetMapping("/get-token-auto")
    public String runAutomation() {
        log.warn("[SECURITY] Upstox automated browser login requested but is permanently disabled.");
        return "DISABLED: Automated browser scraping for Upstox is permanently disabled for security "
                + "and regulatory compliance. Official OAuth 2.0 flow will be introduced in Phase 2.";
    }

    @GetMapping("/callback")
    public void callback(@RequestParam String code) {
        log.info("Upstox callback received — code captured for token exchange.");
        if (tokenFuture != null) {
            tokenFuture.complete(code);
        }
    }

    /**
     * Entry point called during broker login operations.
     * In Phase 1, automated browser scraping is removed. An explicit, graceful error
     * is returned until the official OAuth 2.0 flow is implemented in Phase 2.
     */
    public String getUpstoxtoken(String apikey, String clientSecret, String redirectUrl) {
        log.warn("[SECURITY] Upstox login attempted for apiKey={}, but automated browser scraping is disabled.",
                apikey != null && apikey.length() > 4 ? "****" + apikey.substring(apikey.length() - 4) : "****");
        return "FAILED: Upstox automated browser login is disabled for security and regulatory compliance. "
                + "Official OAuth 2.0 flow will be introduced in Phase 2.";
    }

    public void exchangeCodeForToken(String code, String apikey, String clientSecret, String redirectUrl) {
        String tokenUrl = "https://api.upstox.com/v2/login/authorization/token";
        RestTemplate rest = new RestTemplate();

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("code", code);
        params.add("client_id", apikey);
        params.add("client_secret", clientSecret);
        params.add("redirect_uri", redirectUrl);
        params.add("grant_type", "authorization_code");

        try {
            HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(params, headers);
            ResponseEntity<java.util.Map> response = rest.postForEntity(tokenUrl, request, java.util.Map.class);
            if (response.getBody() != null) {
                String token = (String) response.getBody().get("access_token");
                if (tokenFuture != null) {
                    tokenFuture.complete(token);
                }
            }
        } catch (Exception e) {
            log.error("Failed to exchange Upstox authorization code: {}", e.getMessage());
            if (tokenFuture != null) {
                tokenFuture.completeExceptionally(e);
            }
        }
    }
}
