package com.py.trading.dto;

import java.time.LocalDateTime;

public class PaperOrderResult {

    private String orderId;
    private String uniqueOrderId;
    private String status = "SUCCESS";
    private String simulatedStatus = "SIMULATED_FILLED";
    private String tradingSymbol;
    private String transactionType;
    private Integer quantity;
    private Double requestedPrice;
    private Double executedPrice;
    private Double orderValue;
    private Double balanceRemaining;
    private Double realizedPnl = 0.0;
    private boolean simulated = true;
    private String remarks;
    private LocalDateTime executedAt;

    public PaperOrderResult() {}

    public String getOrderId() {
        return orderId;
    }

    public void setOrderId(String orderId) {
        this.orderId = orderId;
    }

    public String getUniqueOrderId() {
        return uniqueOrderId;
    }

    public void setUniqueOrderId(String uniqueOrderId) {
        this.uniqueOrderId = uniqueOrderId;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getSimulatedStatus() {
        return simulatedStatus;
    }

    public void setSimulatedStatus(String simulatedStatus) {
        this.simulatedStatus = simulatedStatus;
    }

    public String getTradingSymbol() {
        return tradingSymbol;
    }

    public void setTradingSymbol(String tradingSymbol) {
        this.tradingSymbol = tradingSymbol;
    }

    public String getTransactionType() {
        return transactionType;
    }

    public void setTransactionType(String transactionType) {
        this.transactionType = transactionType;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }

    public Double getRequestedPrice() {
        return requestedPrice;
    }

    public void setRequestedPrice(Double requestedPrice) {
        this.requestedPrice = requestedPrice;
    }

    public Double getExecutedPrice() {
        return executedPrice;
    }

    public void setExecutedPrice(Double executedPrice) {
        this.executedPrice = executedPrice;
    }

    public Double getOrderValue() {
        return orderValue;
    }

    public void setOrderValue(Double orderValue) {
        this.orderValue = orderValue;
    }

    public Double getBalanceRemaining() {
        return balanceRemaining;
    }

    public void setBalanceRemaining(Double balanceRemaining) {
        this.balanceRemaining = balanceRemaining;
    }

    public Double getRealizedPnl() {
        return realizedPnl;
    }

    public void setRealizedPnl(Double realizedPnl) {
        this.realizedPnl = realizedPnl;
    }

    public boolean isSimulated() {
        return simulated;
    }

    public void setSimulated(boolean simulated) {
        this.simulated = simulated;
    }

    public String getRemarks() {
        return remarks;
    }

    public void setRemarks(String remarks) {
        this.remarks = remarks;
    }

    public LocalDateTime getExecutedAt() {
        return executedAt;
    }

    public void setExecutedAt(LocalDateTime executedAt) {
        this.executedAt = executedAt;
    }
}
