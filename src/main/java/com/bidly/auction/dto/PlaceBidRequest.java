package com.bidly.auction.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public class PlaceBidRequest {

    @NotNull(message = "Bid amount is required")
    @DecimalMin(value = "1.00", message = "Bid amount must be at least 1.00")
    private BigDecimal amount;

    private UUID deliveryAddressId;

    public PlaceBidRequest() {}

    public PlaceBidRequest(BigDecimal amount, UUID deliveryAddressId) {
        this.amount = amount;
        this.deliveryAddressId = deliveryAddressId;
    }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public UUID getDeliveryAddressId() { return deliveryAddressId; }
    public void setDeliveryAddressId(UUID deliveryAddressId) { this.deliveryAddressId = deliveryAddressId; }
}
