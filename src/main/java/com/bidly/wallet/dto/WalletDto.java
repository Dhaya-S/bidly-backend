package com.bidly.wallet.dto;

import java.math.BigDecimal;
import java.util.UUID;

public class WalletDto {
    private UUID id;
    private BigDecimal balance;
    private BigDecimal reservedBalance;
    private BigDecimal availableBalance;

    public WalletDto() {}

    public WalletDto(UUID id, BigDecimal balance, BigDecimal reservedBalance, BigDecimal availableBalance) {
        this.id = id;
        this.balance = balance;
        this.reservedBalance = reservedBalance;
        this.availableBalance = availableBalance;
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public BigDecimal getBalance() { return balance; }
    public void setBalance(BigDecimal balance) { this.balance = balance; }

    public BigDecimal getReservedBalance() { return reservedBalance; }
    public void setReservedBalance(BigDecimal reservedBalance) { this.reservedBalance = reservedBalance; }

    public BigDecimal getAvailableBalance() { return availableBalance; }
    public void setAvailableBalance(BigDecimal availableBalance) { this.availableBalance = availableBalance; }
}
