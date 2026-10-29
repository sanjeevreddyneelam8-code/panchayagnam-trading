package com.py.demataccount.entity;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.py.crypto.EncryptedStringConverter;
import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "py_broker_secret_table")
public class PyBrokerSecret {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "broker_account_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private PyBrokerAccountEntity brokerAccount;

    @Convert(converter = EncryptedStringConverter.class)
    @Column(name = "api_key", length = 500)
    private String apiKey;             // AES-256-GCM encrypted

    @Convert(converter = EncryptedStringConverter.class)
    @Column(name = "api_secret", length = 500)
    private String apiSecret;          // AES-256-GCM encrypted

    @Column(name = "app_id", length = 255)
    private String appId;              // Some brokers need app ID

    @Convert(converter = EncryptedStringConverter.class)
    @Column(name = "password", length = 500)
    private String password;           // AES-256-GCM encrypted

    @Convert(converter = EncryptedStringConverter.class)
    @Column(name = "totp_secret", length = 500)
    private String totpSecret;         // Zerodha/AngelOne TOTP secret - AES-256-GCM encrypted

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "vender_info")
    private String venderInfo;

    @Convert(converter = EncryptedStringConverter.class)
    @Column(name = "DOB", length = 500)
    private String twoFa;
    
    @Convert(converter = EncryptedStringConverter.class)
    @Column(name ="Mobile", length = 500)
    private String mobileNo;
    
    @Column(name ="Redirect_Url")
    private String redirectUrl;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public PyBrokerAccountEntity getBrokerAccount() {
        return brokerAccount;
    }

    public void setBrokerAccount(PyBrokerAccountEntity brokerAccount) {
        this.brokerAccount = brokerAccount;
    }

    public String getApiKey() {
        return apiKey;
    }

    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }

    public String getApiSecret() {
        return apiSecret;
    }

    public void setApiSecret(String apiSecret) {
        this.apiSecret = apiSecret;
    }

    public String getAppId() {
        return appId;
    }

    public void setAppId(String appId) {
        this.appId = appId;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getTotpSecret() {
        return totpSecret;
    }

    public void setTotpSecret(String totpSecret) {
        this.totpSecret = totpSecret;
    }

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean isActive) {
        this.isActive = isActive;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    /**
     * @return the venderInfo
     */
    public String getVenderInfo() {
        return venderInfo;
    }

    /**
     * @param venderInfo the venderInfo to set
     */
    public void setVenderInfo(String venderInfo) {
        this.venderInfo = venderInfo;
    }

    /**
     * @return the twoFa
     */
    public String getTwoFa() {
        return twoFa;
    }

    /**
     * @param twoFa the twoFa to set
     */
    public void setTwoFa(String twoFa) {
        this.twoFa = twoFa;
    }

    /**
     * @return the mobileNo
     */
    public String getMobileNo() {
        return mobileNo;
    }

    /**
     * @param mobileNo the mobileNo to set
     */
    public void setMobileNo(String mobileNo) {
        this.mobileNo = mobileNo;
    }

    /**
     * @return the redirectUrl
     */
    public String getRedirectUrl() {
        return redirectUrl;
    }

    /**
     * @param redirectUrl the redirectUrl to set
     */
    public void setRedirectUrl(String redirectUrl) {
        this.redirectUrl = redirectUrl;
    }
}
