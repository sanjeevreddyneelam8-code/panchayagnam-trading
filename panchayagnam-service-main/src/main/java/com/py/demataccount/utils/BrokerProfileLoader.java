package com.py.demataccount.utils;

import com.py.brokers.angel.client.Routes;
import com.py.brokers.angel.dto.User;
import com.py.brokers.angel.exception.SmartAPIException;
import com.py.brokers.angel.http.ApiRequestHandler;
import com.py.brokers.motilal.MotilalAccountService;
import com.py.common.enums.BrokerType;
import com.py.demataccount.dto.DematAccountAddRequest;
import com.py.demataccount.entity.PyBrokerSecret;
import org.apache.commons.codec.digest.DigestUtils;
import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.io.IOException;

/**
 * Utility class for loading and managing broker user profiles. Handles profile
 * fetching and user information standardization across brokers.
 */
@Component
public class BrokerProfileLoader {

    @Autowired
    private MotilalAccountService motilalAccountService;

    @Autowired
    private ApiRequestHandler apiRequestHandler;

    private final Routes routes = new Routes();

    private static final Logger log = LoggerFactory.getLogger(BrokerProfileLoader.class);

    /**
     * Builds user profile based on broker type and login data.
     *
     * @param brokerType the broker type
     * @param request the original account request
     * @param loginData the broker login response
     * @param secret broker secret (for profile fetching if needed)
     * @return User profile
     */
    public User buildUserProfile(BrokerType brokerType, DematAccountAddRequest request,
            JSONObject loginData, PyBrokerSecret secret) throws SmartAPIException, IOException {
        if (loginData == null) {
            User user = new User();
            user.setBrokerName(brokerType.name());
            user.setUserId(request.getClientId());
            String nick = request.getNickName();
            user.setUserName(nick != null && !nick.isBlank() ? nick : request.getClientId());
            return user;
        }
        return switch (brokerType) {
            case DHAN ->
                buildDhanUserProfile(request, loginData);
            case UPSTOX ->
                buildUpstoxUserProfile(request, loginData);
            case PROFITMART ->
                buildProfitMartUserProfile(request);
            case ZERODHA ->
                buildZerodhaUserProfile(request, loginData);
            case GOODWILL ->
                buildGoodwillUserProfile(request, loginData);
            default ->
                buildDefaultUserProfile(request, loginData, secret);
        };
    }

    private User buildZerodhaUserProfile(DematAccountAddRequest request, JSONObject loginData) {
        User user = new User();
        user.setBrokerName("ZERODHA");
        user.setUserId(request.getClientId());
        String userName = loginData != null ? loginData.optString("userName", request.getNickName()) : request.getNickName();
        user.setUserName(userName != null && !userName.isEmpty() ? userName : request.getClientId());
        log.debug("Zerodha user profile built | userId={}", user.getUserId());
        return user;
    }

    private User buildGoodwillUserProfile(DematAccountAddRequest request, JSONObject loginData) {
        User user = new User();
        user.setBrokerName("GOODWILL");
        user.setUserId(request.getClientId());
        String userName = request.getNickName();
        user.setUserName(userName != null && !userName.isEmpty() ? userName : request.getClientId());
        log.debug("Goodwill user profile built | userId={}", user.getUserId());
        return user;
    }

    /**
     * Builds Dhan-specific user profile.
     *
     * @param request the account request
     * @param loginData the login response
     * @return User profile
     */
    private User buildDhanUserProfile(DematAccountAddRequest request, JSONObject loginData) {
        User user = new User();
        user.setBrokerName("DHAN");
        user.setUserId(request.getClientId());
        user.setUserName(loginData.optString("dhanClientName", request.getClientId()));
        log.debug("Dhan user profile built | userId={}", user.getUserId());
        return user;
    }

    private User buildProfitMartUserProfile(DematAccountAddRequest request) {
        User user = new User();
        user.setBrokerName("PROFITMART");
        user.setUserId(request.getClientId());
        user.setUserName(request.getClientId());
        log.debug("Profit user profile built | userId={}", user.getUserId());
        return user;
    }

    /**
     * Builds Upstox-specific user profile.
     *
     * @param request the account request
     * @param loginData the login response
     * @return User profile
     */
    private User buildUpstoxUserProfile(DematAccountAddRequest request, JSONObject loginData) {
        User user = new User();
        user.setBrokerName("UPSTOX");
        user.setUserId(request.getClientId());
        String userName = request.getNickName();
        user.setUserName(userName != null && !userName.isEmpty() ? userName : request.getClientId());
        log.debug("Upstox user profile built | userId={}", user.getUserId());
        return user;
    }

    /**
     * Builds default user profile for AngelOne and Motilal.
     *
     * @param request the account request
     * @param loginData the login response
     * @param secret broker secret
     * @return User profile
     */
    private User buildDefaultUserProfile(DematAccountAddRequest request, JSONObject loginData,
            PyBrokerSecret secret) throws SmartAPIException, IOException {
        return switch (request.getBrokerType()) {
            case ANGELONE ->
                fetchAngelOneProfile(request.getApiKey(), loginData.getString("jwtToken"));
            case MOTILAL ->
                fetchMotilalProfile(secret, loginData);
            default ->
                throw new IllegalArgumentException(
                        "Unsupported broker: " + request.getBrokerType());
        };
    }

    private User fetchAngelOneProfile(String apiKey, String jwtToken)
            throws IOException, SmartAPIException {
        if (jwtToken == null || jwtToken.isBlank()) {
            User user = new User();
            user.setBrokerName("ANGELONE");
            return user;
        }
        try {
            return new User().parseResponse(
                    apiRequestHandler.getRequest(apiKey, routes.get("api.user.profile"), jwtToken));
        } catch (Exception e) {
            log.warn("Failed to fetch AngelOne profile from API: {}. Using fallback profile.", e.getMessage());
            User user = new User();
            user.setBrokerName("ANGELONE");
            return user;
        }
    }

    private User fetchMotilalProfile(PyBrokerSecret secret, JSONObject loginData) {
        User user = new User();
        user.setBrokerName("MOTILAL");
        if (loginData == null || !loginData.has("AuthToken")) {
            user.setUserId(secret != null && secret.getBrokerAccount() != null ? secret.getBrokerAccount().getClientId() : "");
            user.setUserName(user.getUserId());
            return user;
        }
        try {
            JSONObject json = motilalAccountService.getProfile(secret, loginData);
            if (json == null || !json.optString("status", "").equalsIgnoreCase("SUCCESS")) {
                throw new RuntimeException("Motilal profile fetch failed: "
                        + (json != null ? json.optString("message", "Unknown error") : "null response"));
            }
            JSONObject data = json.getJSONObject("data");
            user.setUserId(data.optString("clientcode", ""));
            user.setUserName(data.optString("name", ""));

            if (data.has("exchanges")) {
                JSONArray exchangesArray = data.getJSONArray("exchanges");
                String[] exchanges = new String[exchangesArray.length()];
                for (int i = 0; i < exchangesArray.length(); i++) {
                    exchanges[i] = exchangesArray.getString(i);
                }
                user.setExchanges(exchanges);
            }
            if (data.has("products")) {
                JSONArray productsArray = data.getJSONArray("products");
                String[] products = new String[productsArray.length()];
                for (int i = 0; i < productsArray.length(); i++) {
                    products[i] = productsArray.getString(i);
                }
                user.setProducts(products);
            }
            user.setMobileNo("");
            user.setEmail("");
            log.info("Motilal profile fetched for clientId={}", user.getUserId());
        } catch (Exception e) {
            log.warn("Failed to fetch Motilal profile from API: {}. Using fallback profile.", e.getMessage());
            user.setUserId(secret != null && secret.getBrokerAccount() != null ? secret.getBrokerAccount().getClientId() : "");
            user.setUserName(user.getUserId());
        }
        return user;
    }

    /**
     * Gets the effective username from request or user profile.
     *
     * @param request the account request
     * @param user the user profile
     * @return effective username to be used
     */
    public String getEffectiveUserName(DematAccountAddRequest request, User user) {
        if (request.getNickName() != null && !request.getNickName().isEmpty()) {
            return request.getNickName();
        }
        return user.getUserName();
    }

    /**
     * Generates Motilal-specific password hash.
     *
     * @param mpin the PIN from request
     * @param apiKey the API key
     * @return SHA256 hashed password
     */
    public String generateMotilalPasswordHash(String mpin, String apiKey) {
        String hashInput = mpin + apiKey;
        String hash = DigestUtils.sha256Hex(hashInput);
        log.debug("Motilal password hash generated");
        return hash;
    }
}
