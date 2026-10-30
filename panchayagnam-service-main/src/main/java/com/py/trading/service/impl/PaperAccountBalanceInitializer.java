package com.py.trading.service.impl;

import com.py.trading.entity.PaperAccountBalanceEntity;
import com.py.trading.repository.PaperAccountBalanceRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

/**
 * Dedicated helper component for initializing paper account balances.
 * Uses REQUIRES_NEW transaction propagation so that concurrent insert conflicts
 * (e.g. unique constraint violations) are isolated to their own transaction
 * and DO NOT mark the caller's main transaction as rollback-only on PostgreSQL.
 */
@Component
public class PaperAccountBalanceInitializer {

    private static final Logger log = LoggerFactory.getLogger(PaperAccountBalanceInitializer.class);

    private final PaperAccountBalanceRepository balanceRepository;

    public PaperAccountBalanceInitializer(PaperAccountBalanceRepository balanceRepository) {
        this.balanceRepository = balanceRepository;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public PaperAccountBalanceEntity initializeIfAbsent(Long pyUserId, Long dematAccountId, Double initialBalance) {
        Optional<PaperAccountBalanceEntity> existing = balanceRepository.findByPyUserIdAndDematAccountId(pyUserId, dematAccountId);
        if (existing.isPresent()) {
            return existing.get();
        }
        try {
            return balanceRepository.saveAndFlush(new PaperAccountBalanceEntity(pyUserId, dematAccountId, initialBalance));
        } catch (DataIntegrityViolationException dive) {
            log.info("Concurrent balance initialization handled in isolated sub-transaction for pyUserId={}, dematAccountId={}",
                    pyUserId, dematAccountId);
            return balanceRepository.findByPyUserIdAndDematAccountId(pyUserId, dematAccountId)
                    .orElseThrow(() -> dive);
        }
    }
}
