package com.py.easytrade.dto;

import lombok.Data;

@Data
public class IndividualOrderRequest {

    private Long accId;
    private String tradingSymbol;
    private String symbolToken;
    private String exchange;        // NSE / BSE
    private Integer quantity;
    private String orderType;       // MARKET / LIMIT
    private Double price;           // 0 for MARKET
    private String productType;     // INTRADAY / DELIVERY
    private String variety; // NORMAL / STOPLOSS / AMO
    private String amo;
    private Double triggerPrice = 0.0;
    private String idempotencyKey;
//    AMO Time Options
//| amoTime Value | When Order is Sent |
//|---|---|
//| PRE_OPEN | Pre-open session (9:00–9:15 AM) |
//| OPEN | Market open (9:15 AM) |
//| OPEN_30 | 30 minutes after market open |
//| OPEN_60 | 60 minutes after market open |

    /**
     * @return the accId
     */
    public Long getAccId() {
        return accId;
    }

    /**
     * @param accId the accId to set
     */
    public void setAccId(Long accId) {
        this.accId = accId;
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
     * @return the amo
     */
    public String getAmo() {
        return amo;
    }

    /**
     * @param amo the amo to set
     */
    public void setAmo(String amo) {
        this.amo = amo;
    }

    /**
     * @return the triggerPrice
     */
    public Double getTriggerPrice() {
        return triggerPrice;
    }

    /**
     * @param triggerPrice the triggerPrice to set
     */
    public void setTriggerPrice(Double triggerPrice) {
        this.triggerPrice = triggerPrice;
    }

    public String getIdempotencyKey() {
        return idempotencyKey;
    }

    public void setIdempotencyKey(String idempotencyKey) {
        this.idempotencyKey = idempotencyKey;
    }
}
