package com.bidly.offer.entity;

import com.bidly.common.entity.BaseEntity;
import com.bidly.listing.entity.Listing;
import com.bidly.user.entity.User;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "offers", indexes = {
        @Index(name = "idx_offers_listing_buyer", columnList = "listing_id,buyer_id"),
        @Index(name = "idx_offers_seller", columnList = "seller_id"),
        @Index(name = "idx_offers_status", columnList = "status")
})
public class Offer extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "listing_id", nullable = false)
    private Listing listing;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "buyer_id", nullable = false)
    private User buyer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "seller_id", nullable = false)
    private User seller;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Column(name = "counter_amount", precision = 12, scale = 2)
    private BigDecimal counterAmount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private OfferStatus status = OfferStatus.PENDING;

    @Column(columnDefinition = "TEXT")
    private String message;

    @Column(name = "expires_at")
    private Instant expiresAt;

    public enum OfferStatus {
        PENDING, ACCEPTED, REJECTED, COUNTERED, CANCELLED, EXPIRED
    }

    public Offer() {}

    public Offer(Listing listing, User buyer, User seller, BigDecimal amount, String message) {
        this.listing = listing;
        this.buyer = buyer;
        this.seller = seller;
        this.amount = amount;
        this.message = message;
        this.status = OfferStatus.PENDING;
    }

    public Listing getListing() { return listing; }
    public void setListing(Listing listing) { this.listing = listing; }

    public User getBuyer() { return buyer; }
    public void setBuyer(User buyer) { this.buyer = buyer; }

    public User getSeller() { return seller; }
    public void setSeller(User seller) { this.seller = seller; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public BigDecimal getCounterAmount() { return counterAmount; }
    public void setCounterAmount(BigDecimal counterAmount) { this.counterAmount = counterAmount; }

    public OfferStatus getStatus() { return status; }
    public void setStatus(OfferStatus status) { this.status = status; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public Instant getExpiresAt() { return expiresAt; }
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }
}
