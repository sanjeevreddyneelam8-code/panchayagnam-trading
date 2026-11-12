package com.py.ipconfig.controller;

import com.py.common.dto.ApiResponse;
import com.py.common.enums.BrokerType;
import com.py.controller.utils.ControllerResponseBuilder;
import com.py.ipconfig.dto.ValidateIpRequest;
import com.py.ipconfig.service.PyBrokerIpConfigService;
import java.util.List;
import com.py.ipconfig.dto.ConsolidatedIpReport;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/pyconfig")
@Tag(name = "pyconfig", description = "User to handle Configuration related apis")
public class PyBrokerIpConfigController {

    private static final Logger log = LogManager.getLogger(PyBrokerIpConfigController.class);

    @Autowired
    private PyBrokerIpConfigService pyBrokerIpConfigService;

    @Autowired
    private ControllerResponseBuilder responseBuilder;

    @Operation(summary = "Get all registered IP addresses",
            description = "Returns a list of all IP addresses from the py_broker_ip_config table")
    @GetMapping("/ip/all")
    public ResponseEntity<ApiResponse<List<String>>> getAllIpAddresses() {
        log.info("GET /ip/all");
        try {
            var ips = pyBrokerIpConfigService.getAllIpAddresses();
            return responseBuilder.buildSuccess(ips, "Fetched all IP addresses");
        } catch (Exception e) {
            log.error("Failed to fetch IP addresses: {}", e.getMessage(), e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ApiResponse.error(500, "Failed to fetch IP addresses"));
        }
    }

    @Operation(summary = "Get consolidated IP report",
            description = "Returns counts and per-IP details including assigned accounts and broker types")
    @GetMapping("/ip/report")
    public ResponseEntity<ApiResponse<ConsolidatedIpReport>> getIpReport() {
        log.info("GET /ip/report");
        try {
            ConsolidatedIpReport report = pyBrokerIpConfigService.getConsolidatedIpReport();
            return responseBuilder.buildSuccess(report, "Consolidated IP report");
        } catch (Exception e) {
            log.error("Failed to build IP report: {}", e.getMessage(), e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ApiResponse.error(500, "Failed to build IP report"));
        }
    }

    @Operation(summary = "Save list of IP addresses",
            description = "Accepts a JSON array of IP addresses (strings). Ports are allowed (ip:port) and will be normalized to ip.")
    @PostMapping(path = "/ip/save", consumes = "application/json")
    public ResponseEntity<ApiResponse<List<String>>> saveIpAddresses(@RequestBody List<String> ipAddresses) {
        log.info("POST /ip/save | count={}", ipAddresses == null ? 0 : ipAddresses.size());
        try {
            ApiResponse<List<String>> response = pyBrokerIpConfigService.saveIpAddresses(ipAddresses);
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (Exception e) {
            log.error("Failed to save IP addresses: {}", e.getMessage(), e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ApiResponse.error(500, "Failed to save IP addresses"));
        }
    }

    @Operation(summary = "Check health of given IPs",
            description = "Accepts a JSON array of IP addresses and checks each IP's /api/smart/health endpoint")
    @PostMapping(path = "/ip/health", consumes = "application/json")
    public ResponseEntity<ApiResponse<List<com.py.ipconfig.dto.IpHealthDto>>> checkIpsHealth(@RequestBody List<String> ipAddresses) {
        log.info("POST /ip/health | count={}", ipAddresses == null ? 0 : ipAddresses.size());
        try {
            var results = pyBrokerIpConfigService.checkIpsHealth(ipAddresses);
            return responseBuilder.buildSuccess(results, "IP health results");
        } catch (Exception e) {
            log.error("Failed to check IP health: {}", e.getMessage(), e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ApiResponse.error(500, "Failed to check IP health"));
        }
    }

    @Operation(summary = "Validate IP Config",
            description = "Checks if IP exists in DB and whether it is already assigned to a broker")
    @PostMapping(path = "/ip/validate", consumes = "application/json")
    public ResponseEntity<ApiResponse<?>> validateIp(@RequestBody ValidateIpRequest request) {
        log.info("POST /ip/validate | ip={}", request == null ? null : request.getIpAddress());
        try {
            if(request == null){
                throw new IllegalStateException("Ip Request is NULL");
            }
            ApiResponse<?> response = pyBrokerIpConfigService.validateIpForAccount(request.getIpAddress(), request.getBrokerType());
            return ResponseEntity.status(response.getStatusCode()).body(response);
        } catch (Exception e) {
            log.error("IP validation failed | ip={}: {}", request == null ? null : request.getIpAddress(), e.getMessage(), e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ApiResponse.error(500, "IP validation failed"));
        }
    }

}
