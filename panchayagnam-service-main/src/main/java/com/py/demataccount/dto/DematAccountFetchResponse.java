package com.py.demataccount.dto;

import com.py.common.dto.BrokerRmsDto;
import com.py.common.enums.BrokerType;
import java.time.LocalDateTime;
import java.util.List;

public class DematAccountFetchResponse {

    private Long id;
    private String userName;
    private String clientId;
    private BrokerType brokerType;
    private Double availableCash;
    private boolean active;
    private LocalDateTime createdDate;
    private boolean isAdmin = false;
    private String mpin;
    private String apiKey;
    private String totpKey;
    private String password;
    private String dob;
    private List<Long> childIds;
    private String assignedTo;
    private boolean isOwnAccount = false;
    private String apiSecretKey;
    private String ip;
    private BrokerRmsDto rms;   // ← unified RMS for all brokers
    private String mobileNumber;
    private boolean hasPassword;
    private boolean hasTotpKey;
    private boolean hasApiKey;
    private boolean hasApiSecretKey;
    private boolean hasMpin;
    private String lastLoginStatus;
    private String lastLoginError;
    private LocalDateTime lastLoginAttempt;

    // ── existing getters & setters unchanged ─────────────────────────────

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }

    public String getClientId() { return clientId; }
    public void setClientId(String clientId) { this.clientId = clientId; }

    public BrokerType getBrokerType() { return brokerType; }
    public void setBrokerType(BrokerType brokerType) { this.brokerType = brokerType; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }

    public Double getAvailableCash() { return availableCash; }
    public void setAvailableCash(Double availableCash) { this.availableCash = availableCash; }

    public LocalDateTime getCreatedDate() { return createdDate; }
    public void setCreatedDate(LocalDateTime createdDate) { this.createdDate = createdDate; }

    public boolean isIsAdmin() { return isAdmin; }
    public void setIsAdmin(boolean isAdmin) { this.isAdmin = isAdmin; }

    public String getMpin() { return mpin; }
    public void setMpin(String mpin) { this.mpin = mpin; }

    public String getApiKey() { return apiKey; }
    public void setApiKey(String apiKey) { this.apiKey = apiKey; }

    public String getTotpKey() { return totpKey; }
    public void setTotpKey(String totpKey) { this.totpKey = totpKey; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    public String getDob() { return dob; }
    public void setDob(String dob) { this.dob = dob; }

    public List<Long> getChildIds() { return childIds; }
    public void setChildIds(List<Long> childIds) { this.childIds = childIds; }

    public String getAssignedTo() { return assignedTo; }
    public void setAssignedTo(String assignedTo) { this.assignedTo = assignedTo; }

    public boolean isIsOwnAccount() { return isOwnAccount; }
    public void setIsOwnAccount(boolean isOwnAccount) { this.isOwnAccount = isOwnAccount; }

    public String getApiSecretKey() { return apiSecretKey; }
    public void setApiSecretKey(String apiSecretKey) { this.apiSecretKey = apiSecretKey; }

    public String getIp() { return ip; }
    public void setIp(String ip) { this.ip = ip; }

    // ── new rms getter & setter ───────────────────────────────────────────
    public BrokerRmsDto getRms() { return rms; }
    public void setRms(BrokerRmsDto rms) { this.rms = rms; }

    /**
     * @return the mobileNumber
     */
    public String getMobileNumber() {
        return mobileNumber;
    }

    /**
     * @param mobileNumber the mobileNumber to set
     */
    public void setMobileNumber(String mobileNumber) {
        this.mobileNumber = mobileNumber;
    }

    public boolean isHasPassword() { return hasPassword; }
    public void setHasPassword(boolean hasPassword) { this.hasPassword = hasPassword; }

    public boolean isHasTotpKey() { return hasTotpKey; }
    public void setHasTotpKey(boolean hasTotpKey) { this.hasTotpKey = hasTotpKey; }

    public boolean isHasApiKey() { return hasApiKey; }
    public void setHasApiKey(boolean hasApiKey) { this.hasApiKey = hasApiKey; }

    public boolean isHasApiSecretKey() { return hasApiSecretKey; }
    public void setHasApiSecretKey(boolean hasApiSecretKey) { this.hasApiSecretKey = hasApiSecretKey; }

    public boolean isHasMpin() { return hasMpin; }
    public void setHasMpin(boolean hasMpin) { this.hasMpin = hasMpin; }

    public String getLastLoginStatus() { return lastLoginStatus; }
    public void setLastLoginStatus(String lastLoginStatus) { this.lastLoginStatus = lastLoginStatus; }

    public String getLastLoginError() { return lastLoginError; }
    public void setLastLoginError(String lastLoginError) { this.lastLoginError = lastLoginError; }

    public LocalDateTime getLastLoginAttempt() { return lastLoginAttempt; }
    public void setLastLoginAttempt(LocalDateTime lastLoginAttempt) { this.lastLoginAttempt = lastLoginAttempt; }
}