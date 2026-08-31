package com.bidly.auction.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public class BidHistoryItemDto {
    private UUID id;
    private UUID bidderId;
    private String bidderName;
    private String bidderInitials;
    private BigDecimal amount;
    private Instant createdAt;
    private String relativeTime;
    private boolean isHighest;
    private boolean isCurrentUser;

    public BidHistoryItemDto() {}

    public BidHistoryItemDto(UUID id, UUID bidderId, String bidderName, String bidderInitials, BigDecimal amount, Instant createdAt, String relativeTime, boolean isHighest, boolean isCurrentUser) {
        this.id = id;
        this.bidderId = bidderId;
        this.bidderName = bidderName;
        this.bidderInitials = bidderInitials;
        this.amount = amount;
        this.createdAt = createdAt;
        this.relativeTime = relativeTime;
        this.isHighest = isHighest;
        this.isCurrentUser = isCurrentUser;
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getBidderId() { return bidderId; }
    public void setBidderId(UUID bidderId) { this.bidderId = bidderId; }

    public String getBidderName() { return bidderName; }
    public void setBidderName(String bidderName) { this.bidderName = bidderName; }

    public String getBidderInitials() { return bidderInitials; }
    public void setBidderInitials(String bidderInitials) { this.bidderInitials = bidderInitials; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public String getRelativeTime() { return relativeTime; }
    public void setRelativeTime(String relativeTime) { this.relativeTime = relativeTime; }

    public boolean isHighest() { return isHighest; }
    public void setHighest(boolean highest) { isHighest = highest; }

    public boolean isCurrentUser() { return isCurrentUser; }
    public void setCurrentUser(boolean currentUser) { isCurrentUser = currentUser; }
}
