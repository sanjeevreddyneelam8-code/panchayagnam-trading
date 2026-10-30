package com.py.controller.utils;

import com.py.brokers.angel.dto.Order;
import com.py.common.dto.ApiResponse;
import com.py.tokenrefresh.entity.TokenRefreshAuditEntity;
import com.py.brokers.motilal.entity.MotilalTokenRefreshAuditEntity;
import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Utility class for building standardized HTTP responses from controller.
 * Provides methods to construct various response types with consistent formatting.
 */
@Component
public class ControllerResponseBuilder {

    private static final Logger log = LoggerFactory.getLogger(ControllerResponseBuilder.class);

    /**
     * Builds ResponseEntity from ApiResponse with appropriate HTTP status.
     *
     * @param response the ApiResponse
     * @return ResponseEntity with correct status code
     */
    public <T> ResponseEntity<ApiResponse<T>> buildResponse(ApiResponse<T> response) {
        HttpStatus status = mapStatusCodeToHttpStatus(response.getStatusCode());
        return ResponseEntity.status(status).body(response);
    }

    /**
     * Builds success response with standard format.
     *
     * @param data the response data
     * @param message success message
     * @return ResponseEntity with success response
     */
    public <T> ResponseEntity<ApiResponse<T>> buildSuccess(T data, String message) {
        return ResponseEntity.ok(ApiResponse.success(message, data));
    }

    /**
     * Builds success response with only message.
     *
     * @param message success message
     * @return ResponseEntity with success response
     */
    public ResponseEntity<ApiResponse<?>> buildSuccess(String message) {
        return ResponseEntity.ok(ApiResponse.success(message));
    }

    /**
     * Builds error response with standard format.
     *
     * @param statusCode HTTP status code
     * @param message error message
     * @return ResponseEntity with error response
     */
    public ResponseEntity<ApiResponse<?>> buildError(int statusCode, String message) {
        HttpStatus status = mapStatusCodeToHttpStatus(statusCode);
        return ResponseEntity.status(status).body(ApiResponse.error(statusCode, message));
    }

    /**
     * Builds order response in standard format.
     *
     * @param order the order object
     * @param message success message
     * @return ResponseEntity with order response
     */
    public ResponseEntity<ApiResponse<Order>> buildOrderResponse(Order order, String message) {
        return ResponseEntity.ok(ApiResponse.success(message, order));
    }

    /**
     * Builds audit log response from AngelOne audit entities.
     *
     * @param audits list of audit entities
     * @return JSONArray with formatted audit data
     */
    public JSONArray buildAngelOneAuditJson(List<TokenRefreshAuditEntity> audits) {
        JSONArray result = new JSONArray();
        for (TokenRefreshAuditEntity audit : audits) {
            JSONObject obj = new JSONObject();
            obj.put("clientId", audit.getClientId());
            obj.put("userName", audit.getUserName());
            obj.put("status", audit.getStatus());
            obj.put("triggeredBy", audit.getTriggeredBy());
            obj.put("attemptedAt", audit.getAttemptedAt().toString());
            obj.put("completedAt", 
                    audit.getCompletedAt() != null ? audit.getCompletedAt().toString() : "");
            obj.put("durationMs", audit.getDurationMs() != null ? audit.getDurationMs() : 0);
            obj.put("remarks", audit.getRemarks() != null ? audit.getRemarks() : "");
            result.put(obj);
        }
        log.debug("AngelOne audit JSON built | count={}", audits.size());
        return result;
    }

    /**
     * Builds audit log response from Motilal audit entities.
     *
     * @param audits list of audit entities
     * @return JSONArray with formatted audit data
     */
    public JSONArray buildMotilalAuditJson(List<MotilalTokenRefreshAuditEntity> audits) {
        JSONArray result = new JSONArray();
        for (MotilalTokenRefreshAuditEntity audit : audits) {
            JSONObject obj = new JSONObject();
            obj.put("clientId", audit.getClientId());
            obj.put("userName", audit.getUserName());
            obj.put("status", audit.getStatus());
            obj.put("triggeredBy", audit.getTriggeredBy());
            obj.put("attemptedAt", audit.getAttemptedAt().toString());
            obj.put("completedAt", 
                    audit.getCompletedAt() != null ? audit.getCompletedAt().toString() : "");
            obj.put("durationMs", audit.getDurationMs() != null ? audit.getDurationMs() : 0);
            obj.put("remarks", audit.getRemarks() != null ? audit.getRemarks() : "");
            result.put(obj);
        }
        log.debug("Motilal audit JSON built | count={}", audits.size());
        return result;
    }

    /**
     * Builds standard order operation response (Buy/Sell).
     *
     * @param orderId the order ID
     * @param uniqueOrderId the unique order ID
     * @return JSONObject with order response
     */
    public JSONObject buildOrderOperationResponse(String orderId, String uniqueOrderId) {
        JSONObject response = new JSONObject();
        response.put("status", "SUCCESS");
        response.put("orderId", orderId);
        response.put("UniqueOrderId", uniqueOrderId);
        return response;
    }

    /**
     * Maps HTTP status code to HttpStatus enum.
     *
     * @param statusCode the numeric status code
     * @return corresponding HttpStatus
     */
    private HttpStatus mapStatusCodeToHttpStatus(int statusCode) {
        return switch (statusCode) {
            case 200 -> HttpStatus.OK;
            case 201 -> HttpStatus.CREATED;
            case 204 -> HttpStatus.NO_CONTENT;
            case 400 -> HttpStatus.BAD_REQUEST;
            case 401 -> HttpStatus.UNAUTHORIZED;
            case 403 -> HttpStatus.FORBIDDEN;
            case 404 -> HttpStatus.NOT_FOUND;
            case 409 -> HttpStatus.CONFLICT;
            case 500 -> HttpStatus.INTERNAL_SERVER_ERROR;
            case 502 -> HttpStatus.BAD_GATEWAY;
            case 503 -> HttpStatus.SERVICE_UNAVAILABLE;
            default -> HttpStatus.OK;
        };
    }
}
