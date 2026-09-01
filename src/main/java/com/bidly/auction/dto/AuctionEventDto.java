package com.bidly.auction.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public class AuctionEventDto {

    private String eventType; // BID_PLACED, OUTBID, BID_WITHDRAWN, AUCTION_ENDED, AUCTION_STATE_SYNC
    private UUID listingId;
    private BigDecimal highestBid;
    private UUID highestBidderId;
    private String highestBidderDisplayName;
    private int totalBids;
    private BigDecimal minimumNextBid;
    private BigDecimal bidIncrement;
    private Instant auctionEndTime;
    private long secondsRemaining;
    private String auctionStatus;
    private Instant serverTimestamp;
    private List<BidHistoryItemDto> recentBids;
    private Integer watchingCount;

    public AuctionEventDto() {}

    public AuctionEventDto(
            String eventType,
            UUID listingId,
            BigDecimal highestBid,
            UUID highestBidderId,
            String highestBidderDisplayName,
            int totalBids,
            BigDecimal minimumNextBid,
            BigDecimal bidIncrement,
            Instant auctionEndTime,
            long secondsRemaining,
            String auctionStatus,
            Instant serverTimestamp,
            List<BidHistoryItemDto> recentBids,
            Integer watchingCount) {
        this.eventType = eventType;
        this.listingId = listingId;
        this.highestBid = highestBid;
        this.highestBidderId = highestBidderId;
        this.highestBidderDisplayName = highestBidderDisplayName;
        this.totalBids = totalBids;
        this.minimumNextBid = minimumNextBid;
        this.bidIncrement = bidIncrement;
        this.auctionEndTime = auctionEndTime;
        this.secondsRemaining = secondsRemaining;
        this.auctionStatus = auctionStatus;
        this.serverTimestamp = serverTimestamp;
        this.recentBids = recentBids;
        this.watchingCount = watchingCount;
    }

    public String getEventType() { return eventType; }
    public void setEventType(String eventType) { this.eventType = eventType; }

    public UUID getListingId() { return listingId; }
    public void setListingId(UUID listingId) { this.listingId = listingId; }

    public BigDecimal getHighestBid() { return highestBid; }
    public void setHighestBid(BigDecimal highestBid) { this.highestBid = highestBid; }

    public UUID getHighestBidderId() { return highestBidderId; }
    public void setHighestBidderId(UUID highestBidderId) { this.highestBidderId = highestBidderId; }

    public String getHighestBidderDisplayName() { return highestBidderDisplayName; }
    public void setHighestBidderDisplayName(String highestBidderDisplayName) { this.highestBidderDisplayName = highestBidderDisplayName; }

    public int getTotalBids() { return totalBids; }
    public void setTotalBids(int totalBids) { this.totalBids = totalBids; }

    public BigDecimal getMinimumNextBid() { return minimumNextBid; }
    public void setMinimumNextBid(BigDecimal minimumNextBid) { this.minimumNextBid = minimumNextBid; }

    public BigDecimal getBidIncrement() { return bidIncrement; }
    public void setBidIncrement(BigDecimal bidIncrement) { this.bidIncrement = bidIncrement; }

    public Instant getAuctionEndTime() { return auctionEndTime; }
    public void setAuctionEndTime(Instant auctionEndTime) { this.auctionEndTime = auctionEndTime; }

    public long getSecondsRemaining() { return secondsRemaining; }
    public void setSecondsRemaining(long secondsRemaining) { this.secondsRemaining = secondsRemaining; }

    public String getAuctionStatus() { return auctionStatus; }
    public void setAuctionStatus(String auctionStatus) { this.auctionStatus = auctionStatus; }

    public Instant getServerTimestamp() { return serverTimestamp; }
    public void setServerTimestamp(Instant serverTimestamp) { this.serverTimestamp = serverTimestamp; }

    public List<BidHistoryItemDto> getRecentBids() { return recentBids; }
    public void setRecentBids(List<BidHistoryItemDto> recentBids) { this.recentBids = recentBids; }

    public Integer getWatchingCount() { return watchingCount; }
    public void setWatchingCount(Integer watchingCount) { this.watchingCount = watchingCount; }
}
