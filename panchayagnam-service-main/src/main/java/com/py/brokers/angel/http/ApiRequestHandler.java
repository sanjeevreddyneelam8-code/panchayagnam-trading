package com.py.brokers.angel.http;

import com.py.brokers.angel.exception.SmartAPIException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.util.concurrent.TimeUnit;
import okhttp3.HttpUrl;
import org.json.JSONException;
import org.json.JSONObject;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.logging.HttpLoggingInterceptor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 *
 * @author abcom
 */
@Component
public class ApiRequestHandler {

    private OkHttpClient client;
    private String USER_AGENT = "javasmartapiconnect/3.0.0";
    private static final Logger log = LoggerFactory.getLogger(ApiRequestHandler.class);

    public ApiRequestHandler() {
        OkHttpClient.Builder builder = new OkHttpClient.Builder();
        builder.connectTimeout(10000, TimeUnit.MILLISECONDS);

        HttpLoggingInterceptor logging = new HttpLoggingInterceptor();
        logging.setLevel(HttpLoggingInterceptor.Level.BODY);

        client = builder.build();
    }

    public JSONObject postRequest(String apiKey, String url, JSONObject params)
            throws IOException, JSONException, SmartAPIException {

        Request request = createPostRequest(apiKey, url, params);
        try {
            Response response = client.newCall(request).execute();
            String body = response.body().string();
            ObjectMapper objectMapper = new ObjectMapper();
            JsonNode jsonNode = objectMapper.readTree(body);
            if (jsonNode.get("status") == null) {
                log.error("Error in POST request. Request URL: {}, Request Headers: {}, Request Body: {},Response : {}",
                        url, request.headers(), params, body);
            }
            return new ApiResponseHandler().handle(response, body);
        } catch (Exception e) {
            log.error("Error in POST request. Request URL: {}, Request Headers: {}, Request Body: {},Response : {}",
                    url, request.headers(), params, e.getMessage());
            throw e;
        }

    }

    private String resolveClientPublicIp() {
        String ip = getPublicIp();
        if (ip != null && ip.matches("^\\d+\\.\\d+\\.\\d+\\.\\d+$")) {
            return ip;
        }
        return "13.235.14.89";
    }

    public Request createPostRequest(String apiKey, String url, JSONObject params) {
        try {

            MediaType JSON = MediaType.parse("application/json; charset=utf-8");
            RequestBody body = RequestBody.create(params.toString(), JSON);

            Request request = new Request.Builder().url(url).post(body)
                    .header("Content-Type", "application/json")
                    .header("Accept", "application/json")
                    .header("X-ClientLocalIP", "192.168.1.1")
                    .header("X-ClientPublicIP", resolveClientPublicIp())
                    .header("X-MACAddress", "00:00:00:00:00:00")
                    .header("X-PrivateKey", apiKey)
                    .header("X-UserType", "USER")
                    .header("X-SourceID", "WEB").build();
            return request;
        } catch (Exception e) {
            log.error("Exception in createPostRequest: {}", e.getMessage());
            return null;
        }
    }

    public JSONObject getRequest(String apiKey, String url, String accessToken)
            throws IOException, SmartAPIException, JSONException {
        Request request = createGetRequest(apiKey, url, accessToken);
        try {
            Response response = client.newCall(request).execute();
            String body = response.body().string();
            ObjectMapper objectMapper = new ObjectMapper();
            JsonNode jsonNode = objectMapper.readTree(body);
            if (jsonNode.get("status") == null) {
                log.error("Error in GET request. Request URL: {}, Request Headers: {},Response : {}",
                        url, request.headers(), body);
            }
            return new ApiResponseHandler().handle(response, body);
        } catch (Exception e) {
            log.error("Error in GET request. Request URL: {}, Request Headers: {},Response : {}",
                    url, request.headers(), e.getMessage());
            throw e;
        }
    }

    public Request createGetRequest(String apiKey, String url, String accessToken) throws IOException {

        HttpUrl.Builder httpBuilder = HttpUrl.parse(url).newBuilder();
        return new Request.Builder().url(httpBuilder.build()).header("User-Agent", USER_AGENT)
                .header("Authorization", "Bearer " + accessToken)
                .header("Content-Type", "application/json")
                .header("Accept", "application/json")
                .header("X-ClientLocalIP", "192.168.1.1")
                .header("X-ClientPublicIP", resolveClientPublicIp())
                .header("X-MACAddress", "00:00:00:00:00:00")
                .header("X-PrivateKey", apiKey)
                .header("X-UserType", "USER")
                .header("X-SourceID", "WEB").build();
    }

    private String cachedPublicIp = null;

    private String getPublicIp() {
        if (cachedPublicIp == null) {
            try {
                Request ipRequest = new Request.Builder()
                        .url("https://api.ipify.org")
                        .build();
                Response ipResponse = client.newCall(ipRequest).execute();
                cachedPublicIp = ipResponse.body().string().trim();
                log.info("Public IP resolved and cached: {}", cachedPublicIp);
            } catch (Exception e) {
                log.warn("Could not fetch public IP: {}", e.getMessage());
                cachedPublicIp = "unknown";
            }
        }
        return cachedPublicIp;
    }

    public JSONObject postRequest(String apiKey, String url, JSONObject params, String accessToken)
            throws IOException, SmartAPIException, JSONException {
        Request request = createPostRequest(apiKey, url, params, accessToken);

        log.info("API call outgoing | publicIp={} targetUrl={}", getPublicIp(), url);

        try {
            Response response = client.newCall(request).execute();
            String body = response.body().string();
            ObjectMapper objectMapper = new ObjectMapper();
            JsonNode jsonNode = objectMapper.readTree(body);
            if (jsonNode.get("status") == null) {
                log.error("Error in POST request. Request URL: {}, Request Headers: {}, Request Body: {}, Response: {}",
                        url, request.headers(), params, body);
            }
            return new ApiResponseHandler().handle(response, body);
        } catch (Exception e) {
            log.error("Error in POST request. Request URL: {}, Request Headers: {}, Request Body: {}, Response: {}",
                    url, request.headers(), params, e.getMessage());
            throw e;
        }
    }

    public Request createPostRequest(String apiKey, String url, JSONObject params, String accessToken) {
        try {

            MediaType JSON = MediaType.parse("application/json; charset=utf-8");
            RequestBody body = RequestBody.create(params.toString(), JSON);

            String privateKey = apiKey;

            Request request = new Request.Builder().url(url).post(body)
                    .header("Authorization", "Bearer " + accessToken)
                    .header("Content-Type", "application/json")
                    .header("Accept", "application/json")
                    .header("X-ClientLocalIP", "192.168.1.1")
                    .header("X-ClientPublicIP", resolveClientPublicIp())
                    .header("X-MACAddress", "00:00:00:00:00:00")
                    .header("X-PrivateKey", apiKey)
                    .header("X-UserType", "USER")
                    .header("X-SourceID", "WEB").build();
            return request;
        } catch (Exception e) {
            log.error(e.getMessage());
            return null;
        }
    }

    public String postRequestJSONObject(String apiKey, String url, JSONObject params, String accessToken)
            throws IOException, SmartAPIException, JSONException {
        Request request = createPostRequest(apiKey, url, params, accessToken);
        try {
            Response response = client.newCall(request).execute();
            String body = response.body().string();
            ObjectMapper objectMapper = new ObjectMapper();
            JsonNode jsonNode = objectMapper.readTree(body);
            if (jsonNode.get("status") == null) {
                log.error("Error in POST request. Request URL: {}, Request Headers: {}, Request Body: {},Response : {}",
                        url, request.headers(), params, body);
            }
            return new ApiResponseHandler().handler(response, body);
        } catch (Exception e) {
            log.error("Error in POST request. Request URL: {}, Request Headers: {}, Request Body: {},Response : {}",
                    url, request.headers(), params, e.getMessage());
            throw e;
        }
    }
}
