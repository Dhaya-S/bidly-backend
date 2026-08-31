package com.bidly.offer.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;

public class CounterOfferRequest {

    @NotNull(message = "Counter offer amount is required")
    @Positive(message = "Counter offer amount must be positive")
    private BigDecimal counterAmount;

    private String message;

    public CounterOfferRequest() {}

    public CounterOfferRequest(BigDecimal counterAmount, String message) {
        this.counterAmount = counterAmount;
        this.message = message;
    }

    public BigDecimal getCounterAmount() { return counterAmount; }
    public void setCounterAmount(BigDecimal counterAmount) { this.counterAmount = counterAmount; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
}
