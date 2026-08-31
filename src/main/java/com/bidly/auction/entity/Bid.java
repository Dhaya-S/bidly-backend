package com.bidly.auction.entity;

import com.bidly.address.entity.DeliveryAddress;
import com.bidly.common.entity.BaseEntity;
import com.bidly.listing.entity.Listing;
import com.bidly.user.entity.User;
import jakarta.persistence.*;

import java.math.BigDecimal;

@Entity
@Table(name = "bids", indexes = {
        @Index(name = "idx_bids_listing", columnList = "listing_id"),
        @Index(name = "idx_bids_bidder", columnList = "bidder_id"),
        @Index(name = "idx_bids_status", columnList = "status"),
        @Index(name = "idx_bids_listing_amount", columnList = "listing_id, amount")
})
public class Bid extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "listing_id", nullable = false)
    private Listing listing;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "bidder_id", nullable = false)
    private User bidder;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "delivery_address_id")
    private DeliveryAddress deliveryAddress;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private BidStatus status = BidStatus.ACTIVE;

    public enum BidStatus {
        ACTIVE, OUTBID, WON, LOST, WITHDRAWN
    }

    public Bid() {}

    public Bid(Listing listing, User bidder, BigDecimal amount, DeliveryAddress deliveryAddress) {
        this.listing = listing;
        this.bidder = bidder;
        this.amount = amount;
        this.deliveryAddress = deliveryAddress;
        this.status = BidStatus.ACTIVE;
    }

    public Listing getListing() { return listing; }
    public void setListing(Listing listing) { this.listing = listing; }

    public User getBidder() { return bidder; }
    public void setBidder(User bidder) { this.bidder = bidder; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public DeliveryAddress getDeliveryAddress() { return deliveryAddress; }
    public void setDeliveryAddress(DeliveryAddress deliveryAddress) { this.deliveryAddress = deliveryAddress; }

    public BidStatus getStatus() { return status; }
    public void setStatus(BidStatus status) { this.status = status; }
}
