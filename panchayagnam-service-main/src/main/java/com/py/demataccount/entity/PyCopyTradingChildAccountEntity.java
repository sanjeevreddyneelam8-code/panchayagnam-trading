package com.py.demataccount.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(
        name = "py_copy_trading_child_accounts",
        indexes = {
            @Index(name = "idx_py_child_user", columnList = "py_user_id"),
            @Index(name = "idx_py_child_client", columnList = "client_id")
        }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PyCopyTradingChildAccountEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "py_user_id", nullable = false)
    private Long pyUserId;

    @Column(name = "client_id", nullable = false, length = 64)
    private String clientId;

    @Column(name = "broker", nullable = false, length = 32)
    private String broker;

    @Column(name = "name", length = 100)
    private String name;

    @Column(name = "multiplier", nullable = false)
    private Double multiplier = 1.0;

    @Column(name = "copy_mode", length = 32)
    private String copyMode = "ALL";

    @Column(name = "is_active", nullable = false)
    private Boolean active = true;

    @Column(name = "max_daily_loss")
    private Double maxDailyLoss = 15000.0;

    @Column(name = "balance")
    private Double balance = 1000000.0;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
