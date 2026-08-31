package com.bidly.offer.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;

public class CreateOfferRequest {

    @NotNull(message = "Offer amount is required")
    @Positive(message = "Offer amount must be positive")
    private BigDecimal amount;

    private String message;

    public CreateOfferRequest() {}

    public CreateOfferRequest(BigDecimal amount, String message) {
        this.amount = amount;
        this.message = message;
    }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
}
