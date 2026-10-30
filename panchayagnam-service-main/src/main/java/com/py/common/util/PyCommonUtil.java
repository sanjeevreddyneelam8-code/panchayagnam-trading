package com.py.common.util;

import com.py.common.dto.ApiResponse;
import com.py.common.enums.BrokerType;
import com.py.demataccount.dto.DematAccountAddRequest;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.ipconfig.entity.PyBrokerIpConfigEntity;
import org.springframework.stereotype.Component;

@Component
public class PyCommonUtil {

    /**
     * Builds base URL from IP config.
     *
     * @param ipConfig the IP config entity
     * @return base URL for microservice
     */
    public static String getBaseUrl(PyBrokerIpConfigEntity ipConfig) {
        return "http://" + ipConfig.getIpAddress() + ":" + ipConfig.getPortNo();
    }

    public static String getBaseUrl(PyBrokerAccountEntity account) {
        String ipPort = account.getBrokerRegisteredIp();
        if (ipPort == null || ipPort.isBlank()) {
            throw new RuntimeException("No instance URL for clientId: " + account.getClientId());
        }
        String ipWithPort = account.getBrokerRegisteredIp();
        return "http://" + ipWithPort;
    }

    public ApiResponse<?> validateAccountRequest(DematAccountAddRequest request) {
        // Validate broker type
        if (request.getBrokerType() == null) {
            return ApiResponse.error(400, "Broker type is required");
        }

        // Validate required fields
        if (request.getClientId() == null || request.getClientId().isEmpty()) {
            return ApiResponse.error(400, "Client ID is required");
        }

        Long pyUserId = request.getPyUserId();
        if (pyUserId == null || pyUserId <= 0) {
            return ApiResponse.error(400, "Valid PyUser ID is required");
        }

        // Groww does not provide a public trading API
        if (request.getBrokerType() == BrokerType.GROWW) {
            return ApiResponse.error(400, "Groww does not provide an official trading API for third-party automated execution.");
        }

        // Validate API Key for brokers that require it
        if (request.getBrokerType() == BrokerType.ANGELONE
                || request.getBrokerType() == BrokerType.MOTILAL
                || request.getBrokerType() == BrokerType.ZERODHA
                || request.getBrokerType() == BrokerType.UPSTOX
                || request.getBrokerType() == BrokerType.GOODWILL) {
            if (request.getApiKey() == null || request.getApiKey().isEmpty()) {
                return ApiResponse.error(400, "API Key is required for " + request.getBrokerType());
            }
        }

        // Validate PIN / MPIN for brokers that authenticate with PIN
        if (request.getBrokerType() == BrokerType.ANGELONE
                || request.getBrokerType() == BrokerType.MOTILAL
                || request.getBrokerType() == BrokerType.DHAN) {
            if (request.getMpin() == null || request.getMpin().isEmpty()) {
                return ApiResponse.error(400, "PIN / MPIN is required for " + request.getBrokerType());
            }
        }

        // Validate TOTP secret for brokers that use automated TOTP generation
        if (request.getBrokerType() == BrokerType.ANGELONE
                || request.getBrokerType() == BrokerType.MOTILAL
                || request.getBrokerType() == BrokerType.DHAN) {
            if (request.getTotpReferenceKey() == null || request.getTotpReferenceKey().isEmpty()) {
                return ApiResponse.error(400, "TOTP Key is required for " + request.getBrokerType());
            }
        }

        // Validate IP for brokers that require registered gateway IP
        if (request.getBrokerType() != BrokerType.UPSTOX && request.getBrokerType() != BrokerType.ZERODHA) {
            if (request.getIp() == null || request.getIp().isEmpty()) {
                return ApiResponse.error(400, "IP address is required for " + request.getBrokerType());
            }
        }

        return ApiResponse.success("Validation passed");
    }
}

