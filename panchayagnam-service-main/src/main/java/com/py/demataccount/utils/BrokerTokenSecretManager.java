package com.py.demataccount.utils;

import com.py.common.enums.BrokerType;
import com.py.demataccount.dto.DematAccountAddRequest;
import com.py.demataccount.entity.PyBrokerSecret;
import com.py.demataccount.entity.PyBrokerToken;
import org.json.JSONObject;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

/**
 * Utility class for managing broker tokens and secrets.
 * Handles token initialization and secret management across different broker types.
 */
@Component
public class BrokerTokenSecretManager {

    /**
     * Creates and initializes a broker secret from request.
     *
     * @param request the account add request
     * @return initialized PyBrokerSecret
     */
    public PyBrokerSecret createSecret(DematAccountAddRequest request) {
        PyBrokerSecret secret = new PyBrokerSecret();
        secret.setApiKey(request.getApiKey());
        secret.setApiSecret(request.getApiSecretKey());
        secret.setTotpSecret(request.getTotpReferenceKey());
        secret.setPassword(request.getMpin());
        secret.setVenderInfo(request.getVendorInfo());
        secret.setTwoFa(request.getTwoFa());
        secret.setMobileNo(request.getMobileNumber());
        secret.setRedirectUrl(request.getRedirectUri());
        return secret;
    }

    /**
     * Updates an existing broker secret.
     *
     * @param secret the secret to update
     * @param request the new data from request
     */
    public void updateSecret(PyBrokerSecret secret, DematAccountAddRequest request) {
        secret.setApiKey(request.getApiKey());
        secret.setApiSecret(request.getApiSecretKey());
        secret.setPassword(request.getMpin());
        secret.setTotpSecret(request.getTotpReferenceKey());
        secret.setVenderInfo(request.getVendorInfo());
        secret.setTwoFa(request.getTwoFa());
        secret.setMobileNo(request.getMobileNumber());
    }

    /**
     * Creates and initializes a broker token from login data.
     *
     * @param loginData the login response data from broker
     * @param brokerType the broker type
     * @return initialized PyBrokerToken
     */
    public PyBrokerToken createToken(JSONObject loginData, BrokerType brokerType) {
        PyBrokerToken token = new PyBrokerToken();
        populateTokenFromLoginData(token, loginData, brokerType);
        token.setExpiresAt(getTokenExpiry(brokerType));
        return token;
    }

    /**
     * Updates an existing broker token with new login data.
     *
     * @param token the token to update
     * @param loginData the new login data
     * @param brokerType the broker type
     */
    public void updateToken(PyBrokerToken token, JSONObject loginData, BrokerType brokerType) {
        populateTokenFromLoginData(token, loginData, brokerType);
        token.setExpiresAt(getTokenExpiry(brokerType));
    }

    /**
     * Populates token fields based on broker-specific login data.
     *
     * @param token the token entity
     * @param loginData the login response
     * @param brokerType the broker type
     */
    private void populateTokenFromLoginData(PyBrokerToken token, JSONObject loginData, BrokerType brokerType) {
        switch (brokerType) {
            case ANGELONE:
                token.setAccessToken(loginData.getString("jwtToken"));
                token.setRefreshToken(loginData.optString("refreshToken", ""));
                token.setFeedToken(loginData.optString("feedToken", ""));
                break;

            case MOTILAL:
                token.setAccessToken(loginData.getString("AccessToken"));
                token.setRefreshToken(loginData.getString("AuthToken"));
                break;

            case DHAN:
                token.setAccessToken(loginData.getString("accessToken"));
                token.setRefreshToken("");
                token.setFeedToken("");
                break;

            case UPSTOX:
                token.setAccessToken(loginData.getString("accessToken"));
                token.setRefreshToken("");
                token.setFeedToken("");
                break;
            case PROFITMART:
                token.setAccessToken("");
                token.setRefreshToken((""));
                token.setFeedToken("");
                break;
            default:
                throw new IllegalArgumentException("Unsupported broker type: " + brokerType);
        }
    }

    /**
     * Calculates token expiry time based on broker type.
     *
     * @param brokerType the broker type
     * @return expiry LocalDateTime
     */
    public LocalDateTime getTokenExpiry(BrokerType brokerType) {
        // Token validity differs by broker.
        // NOTE: In Phase 1, existing expiry behavior is preserved unchanged pending formal
        // broker-specific session rule verification with live accounts.
        LocalDateTime now = LocalDateTime.now();
        return switch (brokerType) {
            case ANGELONE ->
                now.plusDays(365);  // AngelOne tokens valid for ~1 year
            case MOTILAL ->
                now.plusDays(365);  // Motilal tokens valid for ~1 year
            case DHAN ->
                now.plusDays(365);  // Dhan tokens valid for ~1 year
            case UPSTOX ->
                now.plusDays(1);    // Upstox tokens valid for ~1 day
            default ->
                now.plusDays(1);    // Default: 1 day
        };
    }
}
