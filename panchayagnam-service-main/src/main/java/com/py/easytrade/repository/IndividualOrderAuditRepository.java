package com.py.easytrade.repository;

import com.py.easytrade.entity.IndividualOrderAuditEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface IndividualOrderAuditRepository extends JpaRepository<IndividualOrderAuditEntity, Long> {
    List<IndividualOrderAuditEntity> findByClientIdOrderByExecutedAtDesc(String clientId);
    List<IndividualOrderAuditEntity> findByDematAccountIdOrderByExecutedAtDesc(Long dematAccountId);
    Optional<IndividualOrderAuditEntity> findFirstByOrderIdOrderByExecutedAtDesc(String orderId);
    Optional<IndividualOrderAuditEntity> findByOrderId(String orderId);
}
