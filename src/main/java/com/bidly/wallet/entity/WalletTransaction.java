package com.bidly.wallet.entity;

import com.bidly.common.entity.BaseEntity;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "wallet_transactions", indexes = {
        @Index(name = "idx_wallet_tx_wallet", columnList = "wallet_id"),
        @Index(name = "idx_wallet_tx_ref", columnList = "reference_id, reference_type")
})
public class WalletTransaction extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "wallet_id", nullable = false)
    private Wallet wallet;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private TransactionType type;

    @Column(name = "reference_id")
    private UUID referenceId;

    @Column(name = "reference_type", length = 50)
    private String referenceType;

    @Column(columnDefinition = "TEXT")
    private String description;

    public enum TransactionType {
        CREDIT, DEBIT, RESERVE, RELEASE, ESCROW_HOLD, ESCROW_RELEASE
    }

    public WalletTransaction() {}

    public WalletTransaction(Wallet wallet, BigDecimal amount, TransactionType type, UUID referenceId, String referenceType, String description) {
        this.wallet = wallet;
        this.amount = amount;
        this.type = type;
        this.referenceId = referenceId;
        this.referenceType = referenceType;
        this.description = description;
    }

    public Wallet getWallet() { return wallet; }
    public void setWallet(Wallet wallet) { this.wallet = wallet; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public TransactionType getType() { return type; }
    public void setType(TransactionType type) { this.type = type; }

    public UUID getReferenceId() { return referenceId; }
    public void setReferenceId(UUID referenceId) { this.referenceId = referenceId; }

    public String getReferenceType() { return referenceType; }
    public void setReferenceType(String referenceType) { this.referenceType = referenceType; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
}
