package com.py.demataccount.repository;

import com.py.common.enums.BrokerType;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.dto.BrokerTypeCountProjection;
import com.py.entity.PyUser;
import jakarta.transaction.Transactional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

@Repository
public interface PyBrokerAccountRepository extends JpaRepository<PyBrokerAccountEntity, Long> {

    // Get all broker accounts by py_id - for super admin view
    List<PyBrokerAccountEntity> findByPyUserId(Long pyId);

    List<PyBrokerAccountEntity> findByPyUserIdOrderByIsOwnDesc(Long pyId);

    // Get all active broker accounts
    List<PyBrokerAccountEntity> findByActive(Boolean active);

    // Get by clientId
    Optional<PyBrokerAccountEntity> findByClientId(String clientId);
    Optional<PyBrokerAccountEntity> findByClientIdIgnoreCase(String clientId);

    Optional<PyBrokerAccountEntity> findById(Long id);

    long countByPyUser(PyUser pyUser);

    // Count only active broker accounts for a user
    long countByPyUserAndActiveTrue(PyUser pyUser);

    List<PyBrokerAccountEntity> findByPyUserIdAndActive(Long pyId, Boolean active);

    @Query("SELECT a FROM PyBrokerAccountEntity a JOIN FETCH a.pyUser")
    List<PyBrokerAccountEntity> findAllWithUser();

    List<PyBrokerAccountEntity> findByPyUserIdAndActiveTrue(Long pyUserId);

    @Query("SELECT COUNT(a) > 0 FROM PyBrokerAccountEntity a "
            + "WHERE a.brokerRegisteredIp LIKE CONCAT(:ipPrefix, '%') "
            + "AND a.brokerType = :brokerType AND a.active = true")
    boolean existsActiveAccountWithIpAndBrokerType(
            @Param("ipPrefix") String ipPrefix,
            @Param("brokerType") BrokerType brokerType);


    @Query("SELECT a.clientId AS clientId, a.brokerType AS brokerType, a.active AS active, a.isOwn AS isOwn, a.brokerRegisteredIp AS brokerRegisteredIp FROM PyBrokerAccountEntity a WHERE a.brokerRegisteredIp IS NOT NULL")
    List<com.py.demataccount.dto.AccountIpProjection> findAllRegisteredIpProjection();

    @Query("""
            SELECT CAST(a.brokerType AS string) AS brokerType, COUNT(a) AS count
            FROM PyBrokerAccountEntity a
            WHERE a.active = true
            GROUP BY a.brokerType
            """)
    List<BrokerTypeCountProjection> countAllActivByBrokerType();

    // ── NEW: single query for ADMIN/USER — same but filtered by owner ─────────
    @Query("""
            SELECT CAST(a.brokerType AS string) AS brokerType, COUNT(a) AS count
            FROM PyBrokerAccountEntity a
            WHERE a.active = true AND a.pyUser.id = :userId
            GROUP BY a.brokerType
            """)
    List<BrokerTypeCountProjection> countActiveByBrokerTypeForUser(@Param("userId") Long userId);
    @Modifying
    @Transactional
    @Query("UPDATE PyBrokerAccountEntity a SET a.active = false, a.brokerRegisteredIp = NULL WHERE a.pyUser = :pyUser AND a.isOwn = false")
    void deactivateAllGroupsByUser(PyUser pyUser);

    List<PyBrokerAccountEntity> findByActiveTrue();
    
    List<PyBrokerAccountEntity> findByActiveAndBrokerType(Boolean active, BrokerType brokerType);
}
