package com.py.easytrade.entity;

import com.py.common.enums.BrokerType;
import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "individual_order_audit")
public class IndividualOrderAuditEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long dematAccountId;
    private String clientId;
    private String userName;

    private String tradingSymbol;
    private String symbolToken;
    private String exchange;
    private Integer quantity;
    private Double price;
    private String orderType;
    private String productType;
    private String transactionType;   // BUY / SELL
    private String variety;           // NORMAL / STOPLOSS / AMO

    private String status;            // SUCCESS / FAILED
    private String orderId;
    private String uniqueOrderId;
    private String remarks;
    private BrokerType brokerType;
    private String idempotencyKey;
    private Boolean isSimulated = false;

    private LocalDateTime executedAt;

    /**
     * @return the id
     */
    public Long getId() {
        return id;
    }

    /**
     * @param id the id to set
     */
    public void setId(Long id) {
        this.id = id;
    }

    /**
     * @return the dematAccountId
     */
    public Long getDematAccountId() {
        return dematAccountId;
    }

    /**
     * @param dematAccountId the dematAccountId to set
     */
    public void setDematAccountId(Long dematAccountId) {
        this.dematAccountId = dematAccountId;
    }

    /**
     * @return the clientId
     */
    public String getClientId() {
        return clientId;
    }

    /**
     * @param clientId the clientId to set
     */
    public void setClientId(String clientId) {
        this.clientId = clientId;
    }

    /**
     * @return the userName
     */
    public String getUserName() {
        return userName;
    }

    /**
     * @param userName the userName to set
     */
    public void setUserName(String userName) {
        this.userName = userName;
    }

    /**
     * @return the tradingSymbol
     */
    public String getTradingSymbol() {
        return tradingSymbol;
    }

    /**
     * @param tradingSymbol the tradingSymbol to set
     */
    public void setTradingSymbol(String tradingSymbol) {
        this.tradingSymbol = tradingSymbol;
    }

    /**
     * @return the symbolToken
     */
    public String getSymbolToken() {
        return symbolToken;
    }

    /**
     * @param symbolToken the symbolToken to set
     */
    public void setSymbolToken(String symbolToken) {
        this.symbolToken = symbolToken;
    }

    /**
     * @return the exchange
     */
    public String getExchange() {
        return exchange;
    }

    /**
     * @param exchange the exchange to set
     */
    public void setExchange(String exchange) {
        this.exchange = exchange;
    }

    /**
     * @return the quantity
     */
    public Integer getQuantity() {
        return quantity;
    }

    /**
     * @param quantity the quantity to set
     */
    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }

    /**
     * @return the price
     */
    public Double getPrice() {
        return price;
    }

    /**
     * @param price the price to set
     */
    public void setPrice(Double price) {
        this.price = price;
    }

    /**
     * @return the orderType
     */
    public String getOrderType() {
        return orderType;
    }

    /**
     * @param orderType the orderType to set
     */
    public void setOrderType(String orderType) {
        this.orderType = orderType;
    }

    /**
     * @return the productType
     */
    public String getProductType() {
        return productType;
    }

    /**
     * @param productType the productType to set
     */
    public void setProductType(String productType) {
        this.productType = productType;
    }

    /**
     * @return the transactionType
     */
    public String getTransactionType() {
        return transactionType;
    }

    /**
     * @param transactionType the transactionType to set
     */
    public void setTransactionType(String transactionType) {
        this.transactionType = transactionType;
    }

    /**
     * @return the variety
     */
    public String getVariety() {
        return variety;
    }

    /**
     * @param variety the variety to set
     */
    public void setVariety(String variety) {
        this.variety = variety;
    }

    /**
     * @return the status
     */
    public String getStatus() {
        return status;
    }

    /**
     * @param status the status to set
     */
    public void setStatus(String status) {
        this.status = status;
    }

    /**
     * @return the orderId
     */
    public String getOrderId() {
        return orderId;
    }

    /**
     * @param orderId the orderId to set
     */
    public void setOrderId(String orderId) {
        this.orderId = orderId;
    }

    /**
     * @return the remarks
     */
    public String getRemarks() {
        return remarks;
    }

    /**
     * @param remarks the remarks to set
     */
    public void setRemarks(String remarks) {
        this.remarks = remarks;
    }

    /**
     * @return the executedAt
     */
    public LocalDateTime getExecutedAt() {
        return executedAt;
    }

    /**
     * @param executedAt the executedAt to set
     */
    public void setExecutedAt(LocalDateTime executedAt) {
        this.executedAt = executedAt;
    }

    /**
     * @return the uniqueOrderId
     */
    public String getUniqueOrderId() {
        return uniqueOrderId;
    }

    /**
     * @param uniqueOrderId the uniqueOrderId to set
     */
    public void setUniqueOrderId(String uniqueOrderId) {
        this.uniqueOrderId = uniqueOrderId;
    }

    /**
     * @return the brokerType
     */
    public BrokerType getBrokerType() {
        return brokerType;
    }

    /**
     * @param brokerType the brokerType to set
     */
    public void setBrokerType(BrokerType brokerType) {
        this.brokerType = brokerType;
    }

    public String getIdempotencyKey() {
        return idempotencyKey;
    }

    public void setIdempotencyKey(String idempotencyKey) {
        this.idempotencyKey = idempotencyKey;
    }

    public Boolean getIsSimulated() {
        return isSimulated;
    }

    public void setIsSimulated(Boolean isSimulated) {
        this.isSimulated = isSimulated;
    }
}
