package com.py.trading.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "paper_account_balances",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_paper_user_acc", columnNames = {"py_user_id", "demat_account_id"})
    }
)
public class PaperAccountBalanceEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "py_user_id", nullable = false)
    private Long pyUserId;

    @Column(name = "demat_account_id", nullable = false)
    private Long dematAccountId;

    @Column(name = "virtual_cash_balance", nullable = false)
    private Double virtualCashBalance = 1000000.0; // Default ₹10,00,000 (10 Lakh INR)

    @Column(name = "allocated_margin", nullable = false)
    private Double allocatedMargin = 0.0;

    @Column(name = "realized_pnl", nullable = false)
    private Double realizedPnl = 0.0;

    @Column(name = "unrealized_pnl", nullable = false)
    private Double unrealizedPnl = 0.0;

    @Column(name = "currency", nullable = false, length = 10)
    private String currency = "INR";

    @Version
    @Column(name = "version")
    private Long version;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt = LocalDateTime.now();

    public PaperAccountBalanceEntity() {}

    public PaperAccountBalanceEntity(Long pyUserId, Long dematAccountId, Double initialBalance) {
        this.pyUserId = pyUserId;
        this.dematAccountId = dematAccountId;
        this.virtualCashBalance = initialBalance != null ? initialBalance : 1000000.0;
        this.allocatedMargin = 0.0;
        this.realizedPnl = 0.0;
        this.unrealizedPnl = 0.0;
        this.currency = "INR";
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

    public Double getVirtualCashBalance() {
        return virtualCashBalance;
    }

    public void setVirtualCashBalance(Double virtualCashBalance) {
        this.virtualCashBalance = virtualCashBalance;
    }

    public Double getAllocatedMargin() {
        return allocatedMargin;
    }

    public void setAllocatedMargin(Double allocatedMargin) {
        this.allocatedMargin = allocatedMargin;
    }

    public Double getRealizedPnl() {
        return realizedPnl;
    }

    public void setRealizedPnl(Double realizedPnl) {
        this.realizedPnl = realizedPnl;
    }

    public Double getUnrealizedPnl() {
        return unrealizedPnl;
    }

    public void setUnrealizedPnl(Double unrealizedPnl) {
        this.unrealizedPnl = unrealizedPnl;
    }

    public String getCurrency() {
        return currency;
    }

    public void setCurrency(String currency) {
        this.currency = currency;
    }

    public Long getVersion() {
        return version;
    }

    public void setVersion(Long version) {
        this.version = version;
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
