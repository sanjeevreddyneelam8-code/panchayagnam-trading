package com.py.trading.repository;

import com.py.trading.entity.PaperAccountBalanceEntity;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PaperAccountBalanceRepository extends JpaRepository<PaperAccountBalanceEntity, Long> {

    Optional<PaperAccountBalanceEntity> findByPyUserIdAndDematAccountId(Long pyUserId, Long dematAccountId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT b FROM PaperAccountBalanceEntity b WHERE b.pyUserId = :pyUserId AND b.dematAccountId = :dematAccountId")
    Optional<PaperAccountBalanceEntity> findByPyUserIdAndDematAccountIdForUpdate(
            @Param("pyUserId") Long pyUserId,
            @Param("dematAccountId") Long dematAccountId);
}
