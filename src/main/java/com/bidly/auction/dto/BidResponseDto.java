package com.bidly.auction.dto;

import java.math.BigDecimal;
import java.util.UUID;

public class BidResponseDto {
    private UUID bidId;
    private UUID listingId;
    private BigDecimal bidAmount;
    private BigDecimal currentHighestBid;
    private int totalBids;
    private boolean isHighestBidder;
    private String status;
    private String message;
    private AuctionDetailsDto auctionDetails;

    public BidResponseDto() {}

    public BidResponseDto(UUID bidId, UUID listingId, BigDecimal bidAmount, BigDecimal currentHighestBid, int totalBids, boolean isHighestBidder, String status, String message, AuctionDetailsDto auctionDetails) {
        this.bidId = bidId;
        this.listingId = listingId;
        this.bidAmount = bidAmount;
        this.currentHighestBid = currentHighestBid;
        this.totalBids = totalBids;
        this.isHighestBidder = isHighestBidder;
        this.status = status;
        this.message = message;
        this.auctionDetails = auctionDetails;
    }

    public UUID getBidId() { return bidId; }
    public void setBidId(UUID bidId) { this.bidId = bidId; }

    public UUID getListingId() { return listingId; }
    public void setListingId(UUID listingId) { this.listingId = listingId; }

    public BigDecimal getBidAmount() { return bidAmount; }
    public void setBidAmount(BigDecimal bidAmount) { this.bidAmount = bidAmount; }

    public BigDecimal getCurrentHighestBid() { return currentHighestBid; }
    public void setCurrentHighestBid(BigDecimal currentHighestBid) { this.currentHighestBid = currentHighestBid; }

    public int getTotalBids() { return totalBids; }
    public void setTotalBids(int totalBids) { this.totalBids = totalBids; }

    public boolean isHighestBidder() { return isHighestBidder; }
    public void setHighestBidder(boolean highestBidder) { isHighestBidder = highestBidder; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public AuctionDetailsDto getAuctionDetails() { return auctionDetails; }
    public void setAuctionDetails(AuctionDetailsDto auctionDetails) { this.auctionDetails = auctionDetails; }
}
