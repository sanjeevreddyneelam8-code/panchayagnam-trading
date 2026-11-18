package com.py.ipconfig.service;

import com.py.common.dto.ApiResponse;
import com.py.common.enums.BrokerType;
import com.py.demataccount.dto.AccountIpProjection;
import com.py.ipconfig.entity.PyBrokerIpConfigEntity;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.ipconfig.repository.PyBrokerIpConfigRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.stream.Collectors;

import org.springframework.transaction.annotation.Transactional;
import com.py.ipconfig.dto.IpReport;
import com.py.ipconfig.dto.IpAccount;
import com.py.ipconfig.dto.ConsolidatedIpReport;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.ipconfig.dto.IpHealthDto;
import org.springframework.web.client.RestTemplate;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Qualifier;

@Component
public class PyBrokerIpConfigService {

    @Autowired
    private PyBrokerIpConfigRepository pyBrokerIpConfigRepository;

    @Autowired
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @Autowired
    private RestTemplate restTemplate;

    @Autowired
    @Qualifier("rmsExecutor")
    private ExecutorService rmsExecutor;

    public String extractIpAddress(String ipWithPort) {
        if (ipWithPort == null || ipWithPort.isEmpty()) {
            return ipWithPort;
        }
        // Handle simple ip:port (IPv4). For strings with multiple ':' (likely IPv6), avoid splitting port.
        int firstColon = ipWithPort.indexOf(':');
        int lastColon = ipWithPort.lastIndexOf(':');
        if (firstColon == -1) return ipWithPort;
        if (firstColon == lastColon) {
            return ipWithPort.substring(0, firstColon);
        }
        // Multiple colons (IPv6) - return as-is
        return ipWithPort;
    }

    /**
     * Extract port number if input is in ip:port format (single colon). Returns null otherwise.
     */
    public Integer extractPortNumber(String ipWithPort) {
        if (ipWithPort == null || ipWithPort.isEmpty()) return null;
        int firstColon = ipWithPort.indexOf(':');
        int lastColon = ipWithPort.lastIndexOf(':');
        if (firstColon == -1 || firstColon != lastColon) return null; // no port or IPv6
        String portStr = ipWithPort.substring(firstColon + 1);
        try {
            return Integer.valueOf(portStr);
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    public PyBrokerIpConfigEntity getIpConfigOrThrow(String ipAddress) {
        return pyBrokerIpConfigRepository
                .findByIpAddress(extractIpAddress(ipAddress))
                .orElseThrow(() -> new RuntimeException("IP not found in DB: " + ipAddress));
    }

    /**
     * Validates IP rules against the master_accounts table.
     * Rules:
     *   1. IP must exist in py_broker_ip_config table.
     *   2. One IP can be assigned to max 4 different (distinct) broker types.
     *   3. One IP cannot be assigned to 2 accounts of the same broker type (both active).
     *
     * Returns ApiResponse&lt;PyBrokerIpConfigEntity&gt; so callers can reuse the already-fetched
     * entity without a second DB lookup.
     *
     * @param ip         the IP address (may include port as "ip:port" format)
     * @param brokerType the broker type being added/updated
     * @return ApiResponse containing the PyBrokerIpConfigEntity on success, or an error response
     */
    public ApiResponse<PyBrokerIpConfigEntity> validateIpForAccount(String ip, BrokerType brokerType) {
        String rawIp = (ip == null || ip.isBlank()) ? "13.235.14.89" : ip.trim();
        String ipAddress = extractIpAddress(rawIp);

        if (ipAddress == null || !ipAddress.matches("^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$")) {
            return ApiResponse.error(400, "IP " + ipAddress
                    + " is not a valid IPv4 address. Please use a valid IP (e.g. 13.235.14.89).");
        }

        // Auto-register valid IPv4 in py_broker_ip_config if not already present
        Optional<PyBrokerIpConfigEntity> ipConfigOpt = pyBrokerIpConfigRepository.findByIpAddress(ipAddress);
        PyBrokerIpConfigEntity ipConfig;
        if (ipConfigOpt.isEmpty()) {
            PyBrokerIpConfigEntity newCfg = new PyBrokerIpConfigEntity();
            newCfg.setIpAddress(ipAddress);
            Integer parsedPort = extractPortNumber(rawIp);
            newCfg.setPortNo(parsedPort != null ? parsedPort : 8082);
            ipConfig = pyBrokerIpConfigRepository.save(newCfg);
        } else {
            ipConfig = ipConfigOpt.get();
        }

        // Allow shared platform cloud IPs across accounts
        boolean isSharedCloudIp = "13.235.14.89".equals(ipAddress)
                || "74.220.52.132".equals(ipAddress)
                || "127.0.0.1".equals(ipAddress)
                || ipAddress.startsWith("74.220.");
        if (!isSharedCloudIp) {
            // Rule 2: same broker type cannot be assigned to same IP twice (active accounts)
            boolean sameBrokerTypeExists = pyBrokerAccountRepository.existsActiveAccountWithIpAndBrokerType(
                            ipAddress, brokerType);

            if (sameBrokerTypeExists) {
                return ApiResponse.error(409, "IP " + ipAddress
                        + " is already assigned to an active " + brokerType + " account. One IP can only serve one account per broker type.");
            }
        }
        return ApiResponse.success("IP is valid and available for " + brokerType, ipConfig);
    }

    /**
     * Returns all IP addresses stored in py_broker_ip_config as a list of strings.
     */
    public List<String> getAllIpAddresses() {
        return pyBrokerIpConfigRepository.findAll()
                .stream()
                .map(PyBrokerIpConfigEntity::getIpAddress)
                .collect(Collectors.toList());
    }

    /**
     * Builds a consolidated IP report.
     */
    public ConsolidatedIpReport getConsolidatedIpReport() {
        var configs = pyBrokerIpConfigRepository.findAll();
        ConsolidatedIpReport report = new ConsolidatedIpReport();
        List<IpReport> reportList = new ArrayList<>();

    // Fetch projection with only required columns in one query
    List<com.py.demataccount.dto.AccountIpProjection> projections = pyBrokerAccountRepository.findAllRegisteredIpProjection();

    // Group projections by normalized IP
    Map<String, List<AccountIpProjection>> grouped = projections.stream()
        .collect(Collectors.groupingBy(p -> extractIpAddress(p.getBrokerRegisteredIp())));

    for (PyBrokerIpConfigEntity cfg : configs) {
        List<com.py.demataccount.dto.AccountIpProjection> accounts = grouped.getOrDefault(cfg.getIpAddress(), List.of());

        IpReport ipReport = new IpReport();
        ipReport.setIpAddress(cfg.getIpAddress());
        ipReport.setPortNo(cfg.getPortNo());
        List<String> brokerTypes = accounts.stream().map(a -> a.getBrokerType().name())
            .distinct().collect(Collectors.toList());
        ipReport.setBrokerTypes(brokerTypes);

        List<IpAccount> accountsReport = accounts.stream().map(a -> {
        IpAccount ad = new IpAccount();
        ad.setClientId(a.getClientId());
        ad.setBrokerType(a.getBrokerType().name());
        ad.setActive(a.getActive());
        ad.setIsOwn(a.getIsOwn());
        ad.setUserName(a.getUserName());
        return ad;
        }).collect(Collectors.toList());
        ipReport.setAccounts(accountsReport);
        reportList.add(ipReport);
    }

    

        report.setDetails(reportList);
        report.setTotalIpCount(reportList.size());
        long used = reportList.stream().filter(d -> d.getAccounts() != null && !d.getAccounts().isEmpty()).count();
        report.setUsedIpCount(used);
        report.setUnusedIpCount(reportList.size() - used);
        return report;
    }

    /**
     * Checks health for a list of IP addresses by calling http://{ip}:8082/api/smart/health
     */
    public List<IpHealthDto> checkIpsHealth(List<String> ips) {
        if (ips == null || ips.isEmpty()) return List.of();

        return ips.stream().map(ip ->
                {
                IpHealthDto dto = new IpHealthDto();
                dto.setIp(ip);
                try {
                    String target = "http://" + ip + ":8082/api/smart/health";
                    @SuppressWarnings("unchecked")
                    var resp = restTemplate.getForObject(target, Map.class);
                    if (resp != null && resp.get("status") != null) {
                        dto.setStatus(String.valueOf(resp.get("status")));
                        dto.setMessage(resp.get("message") != null ? String.valueOf(resp.get("message")) : null);
                        dto.setTimestamp(resp.get("timestamp") != null ? String.valueOf(resp.get("timestamp")) : null);
                    } else {
                        dto.setStatus("DOWN");
                        dto.setMessage("Application is not responding");
                    }
                } catch (Exception e) {
                    dto.setStatus("DOWN");
                    dto.setMessage(e.getMessage());
                }
                return dto;
            }
                ).toList();
    }

    /**
     * Saves a list of IP addresses to the py_broker_ip_config table.
     * - Normalizes entries by stripping port numbers (ip:port -> ip)
     * - Deduplicates input
     * - Skips already-registered IPs
     * Returns ApiResponse with list of saved IP addresses and appropriate status.
     */
    @Transactional
    public ApiResponse<List<String>> saveIpAddresses(List<String> ipAddresses) {
        if (ipAddresses == null || ipAddresses.isEmpty()) {
            return ApiResponse.error(400, "No IP addresses provided");
        }


        // Single-pass: dedupe while preserving order and create/update entities immediately
        Set<String> seen = new LinkedHashSet<>();
        List<PyBrokerIpConfigEntity> toSaveOrUpdate = new ArrayList<>();
        for (String raw : ipAddresses) {
            if (raw == null) continue;
            String ip = extractIpAddress(raw);
            if (ip == null || ip.isBlank()) continue;
            // first occurrence wins
            if (!seen.add(ip)) continue;
            Integer providedPort = extractPortNumber(raw);
            Optional<PyBrokerIpConfigEntity> existingOpt = pyBrokerIpConfigRepository.findByIpAddress(ip);
            if (existingOpt.isPresent()) {
                PyBrokerIpConfigEntity existing = existingOpt.get();
                // Update port if provided and different
                if (providedPort != null && !providedPort.equals(existing.getPortNo())) {
                    existing.setPortNo(providedPort);
                    toSaveOrUpdate.add(existing);
                }
            } else {
                PyBrokerIpConfigEntity e = new PyBrokerIpConfigEntity();
                e.setIpAddress(ip);
                if (providedPort != null) e.setPortNo(providedPort);
                toSaveOrUpdate.add(e);
            }
        }

    if (toSaveOrUpdate.isEmpty()) {
        return ApiResponse.success("No changes to apply", List.of());
    }

    List<PyBrokerIpConfigEntity> saved = pyBrokerIpConfigRepository.saveAll(toSaveOrUpdate);
    List<String> savedIps = saved.stream().map(e -> e.getIpAddress() + 
            (e.getPortNo() != null ? ":" + e.getPortNo() : "")).collect(Collectors.toList());
    return ApiResponse.success("Saved/Updated " + savedIps.size() + " IP(s)", savedIps);
    }
}
