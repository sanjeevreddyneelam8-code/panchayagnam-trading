package com.py.trading.service;

import com.py.brokers.angel.dto.Order;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.easytrade.dto.IndividualOrderRequest;
import com.py.trading.entity.PaperAccountBalanceEntity;
import com.py.trading.entity.PaperPositionEntity;

import java.util.List;

public interface PaperTradingEngine {

    /**
     * Executes a validated simulated paper order.
     * Prevents any broker network calls, enforces account ownership, validates balance and holdings,
     * atomically updates virtual cash and positions, and persists audit logs.
     */
    Order executePaperOrder(PyBrokerAccountEntity dematAccount, IndividualOrderRequest request, String transactionType);

    /**
     * Gets or creates the virtual balance for an account.
     */
    PaperAccountBalanceEntity getOrCreateBalance(Long pyUserId, Long dematAccountId);

    /**
     * Returns virtual positions held in the demat account.
     */
    List<PaperPositionEntity> getPositions(Long dematAccountId);
}
