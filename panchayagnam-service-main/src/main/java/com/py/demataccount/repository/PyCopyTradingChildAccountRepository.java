package com.py.demataccount.repository;

import com.py.demataccount.entity.PyCopyTradingChildAccountEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PyCopyTradingChildAccountRepository extends JpaRepository<PyCopyTradingChildAccountEntity, Long> {

    List<PyCopyTradingChildAccountEntity> findByPyUserIdOrderByCreatedAtAsc(Long pyUserId);

    Optional<PyCopyTradingChildAccountEntity> findByPyUserIdAndClientId(Long pyUserId, String clientId);

    void deleteByPyUserIdAndClientId(Long pyUserId, String clientId);

    List<PyCopyTradingChildAccountEntity> findByActiveTrue();
}
