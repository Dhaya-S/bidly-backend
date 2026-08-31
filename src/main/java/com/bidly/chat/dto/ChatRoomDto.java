package com.bidly.chat.dto;

import java.time.Instant;
import java.util.UUID;

public class ChatRoomDto {
    private UUID id;
    private UUID listingId;
    private String listingTitle;
    private String listingImageUrl;
    private double listingPrice;
    private UUID buyerId;
    private String buyerName;
    private UUID sellerId;
    private String sellerName;
    private String status;
    private Instant lastMessageAt;
    private Instant createdAt;
    private String lastMessagePreview;

    public UUID getId()                            { return id; }
    public void setId(UUID id)                     { this.id = id; }
    public UUID getListingId()                     { return listingId; }
    public void setListingId(UUID v)               { this.listingId = v; }
    public String getListingTitle()                { return listingTitle; }
    public void setListingTitle(String v)          { this.listingTitle = v; }
    public String getListingImageUrl()             { return listingImageUrl; }
    public void setListingImageUrl(String v)       { this.listingImageUrl = v; }
    public double getListingPrice()                { return listingPrice; }
    public void setListingPrice(double v)          { this.listingPrice = v; }
    public UUID getBuyerId()                       { return buyerId; }
    public void setBuyerId(UUID v)                 { this.buyerId = v; }
    public String getBuyerName()                   { return buyerName; }
    public void setBuyerName(String v)             { this.buyerName = v; }
    public UUID getSellerId()                      { return sellerId; }
    public void setSellerId(UUID v)                { this.sellerId = v; }
    public String getSellerName()                  { return sellerName; }
    public void setSellerName(String v)            { this.sellerName = v; }
    public String getStatus()                      { return status; }
    public void setStatus(String v)                { this.status = v; }
    public Instant getLastMessageAt()              { return lastMessageAt; }
    public void setLastMessageAt(Instant v)        { this.lastMessageAt = v; }
    public Instant getCreatedAt()                  { return createdAt; }
    public void setCreatedAt(Instant v)            { this.createdAt = v; }
    public String getLastMessagePreview()          { return lastMessagePreview; }
    public void setLastMessagePreview(String v)    { this.lastMessagePreview = v; }
}
