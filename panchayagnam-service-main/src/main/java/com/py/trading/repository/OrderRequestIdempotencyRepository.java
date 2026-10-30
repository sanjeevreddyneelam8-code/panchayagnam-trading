package com.py.trading.repository;

import com.py.trading.entity.OrderRequestIdempotencyEntity;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface OrderRequestIdempotencyRepository extends JpaRepository<OrderRequestIdempotencyEntity, Long> {

    Optional<OrderRequestIdempotencyEntity> findByPyUserIdAndDematAccountIdAndIdempotencyKey(
            Long pyUserId, Long dematAccountId, String idempotencyKey);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT i FROM OrderRequestIdempotencyEntity i WHERE i.pyUserId = :pyUserId AND i.dematAccountId = :dematAccountId AND i.idempotencyKey = :idempotencyKey")
    Optional<OrderRequestIdempotencyEntity> findForUpdate(
            @Param("pyUserId") Long pyUserId,
            @Param("dematAccountId") Long dematAccountId,
            @Param("idempotencyKey") String idempotencyKey);
}
