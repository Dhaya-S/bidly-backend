package com.bidly.offer.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public class OfferDto {

    private UUID id;
    private UUID listingId;
    private String listingTitle;
    private BigDecimal listingPrice;
    private String listingImageUrl;

    private UUID buyerId;
    private String buyerName;
    private UUID sellerId;
    private String sellerName;

    private BigDecimal amount;
    private BigDecimal counterAmount;
    private String status; // PENDING, ACCEPTED, REJECTED, COUNTERED, CANCELLED, EXPIRED
    private String message;

    private boolean isBuyer;
    private boolean isSeller;

    private UUID orderId;
    private Instant createdAt;
    private Instant expiresAt;

    public OfferDto() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getListingId() { return listingId; }
    public void setListingId(UUID listingId) { this.listingId = listingId; }

    public String getListingTitle() { return listingTitle; }
    public void setListingTitle(String listingTitle) { this.listingTitle = listingTitle; }

    public BigDecimal getListingPrice() { return listingPrice; }
    public void setListingPrice(BigDecimal listingPrice) { this.listingPrice = listingPrice; }

    public String getListingImageUrl() { return listingImageUrl; }
    public void setListingImageUrl(String listingImageUrl) { this.listingImageUrl = listingImageUrl; }

    public UUID getBuyerId() { return buyerId; }
    public void setBuyerId(UUID buyerId) { this.buyerId = buyerId; }

    public String getBuyerName() { return buyerName; }
    public void setBuyerName(String buyerName) { this.buyerName = buyerName; }

    public UUID getSellerId() { return sellerId; }
    public void setSellerId(UUID sellerId) { this.sellerId = sellerId; }

    public String getSellerName() { return sellerName; }
    public void setSellerName(String sellerName) { this.sellerName = sellerName; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public BigDecimal getCounterAmount() { return counterAmount; }
    public void setCounterAmount(BigDecimal counterAmount) { this.counterAmount = counterAmount; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public boolean isBuyer() { return isBuyer; }
    public void setBuyer(boolean buyer) { isBuyer = buyer; }

    public boolean isSeller() { return isSeller; }
    public void setSeller(boolean seller) { isSeller = seller; }

    public UUID getOrderId() { return orderId; }
    public void setOrderId(UUID orderId) { this.orderId = orderId; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getExpiresAt() { return expiresAt; }
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }
}
