package com.py.trading.repository;

import com.py.trading.entity.PaperPositionEntity;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PaperPositionRepository extends JpaRepository<PaperPositionEntity, Long> {

    Optional<PaperPositionEntity> findByDematAccountIdAndTradingSymbolAndProductType(
            Long dematAccountId, String tradingSymbol, String productType);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM PaperPositionEntity p WHERE p.dematAccountId = :dematAccountId AND p.tradingSymbol = :tradingSymbol AND p.productType = :productType")
    Optional<PaperPositionEntity> findByDematAccountIdAndTradingSymbolAndProductTypeForUpdate(
            @Param("dematAccountId") Long dematAccountId,
            @Param("tradingSymbol") String tradingSymbol,
            @Param("productType") String productType);

    List<PaperPositionEntity> findByDematAccountId(Long dematAccountId);

    List<PaperPositionEntity> findByPyUserIdAndDematAccountId(Long pyUserId, Long dematAccountId);
}
