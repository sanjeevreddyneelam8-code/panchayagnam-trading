package com.py.trading.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "order_request_idempotency",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_user_acc_idempotency", columnNames = {"py_user_id", "demat_account_id", "idempotency_key"})
    },
    indexes = {
        @Index(name = "idx_idempotency_key", columnList = "idempotency_key")
    }
)
public class OrderRequestIdempotencyEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "idempotency_key", nullable = false, length = 128)
    private String idempotencyKey;

    @Column(name = "py_user_id", nullable = false)
    private Long pyUserId;

    @Column(name = "demat_account_id", nullable = false)
    private Long dematAccountId;

    @Column(name = "request_hash", nullable = false, length = 64)
    private String requestHash;

    @Column(name = "status", nullable = false, length = 30)
    private String status; // IN_PROGRESS, COMPLETED, FAILED

    @Column(name = "order_id", length = 100)
    private String orderId;

    @Column(name = "http_status_code")
    private Integer httpStatusCode = 200;

    @Column(name = "response_payload", columnDefinition = "TEXT")
    private String responsePayload;

    @Column(name = "error_message", length = 1000)
    private String errorMessage;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt = LocalDateTime.now();

    public OrderRequestIdempotencyEntity() {}

    public OrderRequestIdempotencyEntity(Long pyUserId, Long dematAccountId, String idempotencyKey, String requestHash) {
        this.pyUserId = pyUserId;
        this.dematAccountId = dematAccountId;
        this.idempotencyKey = idempotencyKey;
        this.requestHash = requestHash;
        this.status = "IN_PROGRESS";
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    public void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getIdempotencyKey() {
        return idempotencyKey;
    }

    public void setIdempotencyKey(String idempotencyKey) {
        this.idempotencyKey = idempotencyKey;
    }

    public Long getPyUserId() {
        return pyUserId;
    }

    public void setPyUserId(Long pyUserId) {
        this.pyUserId = pyUserId;
    }

    public Long getDematAccountId() {
        return dematAccountId;
    }

    public void setDematAccountId(Long dematAccountId) {
        this.dematAccountId = dematAccountId;
    }

    public String getRequestHash() {
        return requestHash;
    }

    public void setRequestHash(String requestHash) {
        this.requestHash = requestHash;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getOrderId() {
        return orderId;
    }

    public void setOrderId(String orderId) {
        this.orderId = orderId;
    }

    public Integer getHttpStatusCode() {
        return httpStatusCode;
    }

    public void setHttpStatusCode(Integer httpStatusCode) {
        this.httpStatusCode = httpStatusCode;
    }

    public String getResponsePayload() {
        return responsePayload;
    }

    public void setResponsePayload(String responsePayload) {
        this.responsePayload = responsePayload;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
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
}
