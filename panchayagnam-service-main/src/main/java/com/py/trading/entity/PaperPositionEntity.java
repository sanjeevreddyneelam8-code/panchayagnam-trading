package com.py.trading.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "paper_positions",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_paper_pos", columnNames = {"demat_account_id", "trading_symbol", "product_type"})
    }
)
public class PaperPositionEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "py_user_id", nullable = false)
    private Long pyUserId;

    @Column(name = "demat_account_id", nullable = false)
    private Long dematAccountId;

    @Column(name = "trading_symbol", nullable = false, length = 50)
    private String tradingSymbol;

    @Column(name = "symbol_token", length = 50)
    private String symbolToken;

    @Column(name = "exchange", nullable = false, length = 20)
    private String exchange = "NSE";

    @Column(name = "product_type", nullable = false, length = 30)
    private String productType = "DELIVERY";

    @Column(name = "quantity", nullable = false)
    private Integer quantity = 0;

    @Column(name = "average_buy_price", nullable = false)
    private Double averageBuyPrice = 0.0;

    @Column(name = "realized_pnl", nullable = false)
    private Double realizedPnl = 0.0;

    @Column(name = "last_simulated_price")
    private Double lastSimulatedPrice = 0.0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt = LocalDateTime.now();

    public PaperPositionEntity() {}

    public PaperPositionEntity(Long pyUserId, Long dematAccountId, String tradingSymbol,
                               String symbolToken, String exchange, String productType,
                               Integer quantity, Double averageBuyPrice) {
        this.pyUserId = pyUserId;
        this.dematAccountId = dematAccountId;
        this.tradingSymbol = tradingSymbol;
        this.symbolToken = symbolToken;
        this.exchange = exchange != null ? exchange : "NSE";
        this.productType = productType != null ? productType : "DELIVERY";
        this.quantity = quantity != null ? quantity : 0;
        this.averageBuyPrice = averageBuyPrice != null ? averageBuyPrice : 0.0;
        this.realizedPnl = 0.0;
        this.lastSimulatedPrice = averageBuyPrice;
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

    public String getTradingSymbol() {
        return tradingSymbol;
    }

    public void setTradingSymbol(String tradingSymbol) {
        this.tradingSymbol = tradingSymbol;
    }

    public String getSymbolToken() {
        return symbolToken;
    }

    public void setSymbolToken(String symbolToken) {
        this.symbolToken = symbolToken;
    }

    public String getExchange() {
        return exchange;
    }

    public void setExchange(String exchange) {
        this.exchange = exchange;
    }

    public String getProductType() {
        return productType;
    }

    public void setProductType(String productType) {
        this.productType = productType;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }

    public Double getAverageBuyPrice() {
        return averageBuyPrice;
    }

    public void setAverageBuyPrice(Double averageBuyPrice) {
        this.averageBuyPrice = averageBuyPrice;
    }

    public Double getRealizedPnl() {
        return realizedPnl;
    }

    public void setRealizedPnl(Double realizedPnl) {
        this.realizedPnl = realizedPnl;
    }

    public Double getLastSimulatedPrice() {
        return lastSimulatedPrice;
    }

    public void setLastSimulatedPrice(Double lastSimulatedPrice) {
        this.lastSimulatedPrice = lastSimulatedPrice;
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
