package com.py.common.enums;

import com.fasterxml.jackson.annotation.JsonCreator;

public enum BrokerType {
    ANGELONE,
    MOTILAL,
    DHAN,
    UPSTOX,
    PROFITMART,
    GOODWILL,
    ZERODHA,
    GROWW;

    @JsonCreator
    public static BrokerType fromString(String value) {
        if (value == null) return null;
        String upper = value.trim().toUpperCase().replace(" ", "").replace("_", "");
        if (upper.contains("GOODW")) return GOODWILL;
        if (upper.contains("ANGEL")) return ANGELONE;
        if (upper.contains("MOTILAL")) return MOTILAL;
        if (upper.contains("DHAN")) return DHAN;
        if (upper.contains("UPSTOX")) return UPSTOX;
        if (upper.contains("PROFIT")) return PROFITMART;
        if (upper.contains("ZERODHA") || upper.contains("KITE")) return ZERODHA;
        if (upper.contains("GROWW")) return GROWW;
        for (BrokerType b : values()) {
            if (b.name().equalsIgnoreCase(value.trim())) return b;
        }
        throw new IllegalArgumentException("Unknown BrokerType: " + value);
    }
}

