package com.py.demataccount.entity;


import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.py.crypto.EncryptedStringConverter;
import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "py_broker_token_table")
public class PyBrokerToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "broker_account_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private PyBrokerAccountEntity brokerAccount;

    @Convert(converter = EncryptedStringConverter.class)
    @Column(name = "access_token", columnDefinition = "TEXT")
    private String accessToken;        // AES-256-GCM encrypted

    @Convert(converter = EncryptedStringConverter.class)
    @Column(name = "refresh_token", columnDefinition = "TEXT")
    private String refreshToken;       // AES-256-GCM encrypted

    @Convert(converter = EncryptedStringConverter.class)
    @Column(name = "feed_token", length = 500)
    private String feedToken;          // Angel One WebSocket feed token - AES-256-GCM encrypted

    @Column(name = "token_type", length = 50)
    private String tokenType;          // Bearer etc

    @Column(name = "expires_at")
    private LocalDateTime expiresAt;   // Token expiry time

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

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
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public PyBrokerAccountEntity getBrokerAccount() { return brokerAccount; }
    public void setBrokerAccount(PyBrokerAccountEntity brokerAccount) { this.brokerAccount = brokerAccount; }

    public String getAccessToken() { return accessToken; }
    public void setAccessToken(String accessToken) { this.accessToken = accessToken; }

    public String getRefreshToken() { return refreshToken; }
    public void setRefreshToken(String refreshToken) { this.refreshToken = refreshToken; }

    public String getFeedToken() { return feedToken; }
    public void setFeedToken(String feedToken) { this.feedToken = feedToken; }

    public String getTokenType() { return tokenType; }
    public void setTokenType(String tokenType) { this.tokenType = tokenType; }

    public LocalDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(LocalDateTime expiresAt) { this.expiresAt = expiresAt; }

    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}
