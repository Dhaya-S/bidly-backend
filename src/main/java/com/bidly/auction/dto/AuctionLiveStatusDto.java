package com.bidly.auction.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public class AuctionLiveStatusDto {
    private UUID listingId;
    private BigDecimal currentHighestBid;
    private BigDecimal minNextBid;
    private int totalBids;
    private int watchingCount;
    private long secondsRemaining;
    private String timeLeftFormatted;
    private String status;
    private boolean isAuctionEnded;
    private boolean isCurrentUserWinning;
    private boolean isCurrentUserOutbid;
    private BigDecimal currentUserBid;
    private Integer currentUserRank;
    private BigDecimal behindByAmount;
    private UUID highestBidderId;
    private String highestBidderName;
    private Instant serverTimestamp = Instant.now();
    private List<BidHistoryItemDto> liveBidFeed;

    public AuctionLiveStatusDto() {}

    public UUID getListingId() { return listingId; }
    public void setListingId(UUID listingId) { this.listingId = listingId; }

    public BigDecimal getCurrentHighestBid() { return currentHighestBid; }
    public void setCurrentHighestBid(BigDecimal currentHighestBid) { this.currentHighestBid = currentHighestBid; }

    public BigDecimal getMinNextBid() { return minNextBid; }
    public void setMinNextBid(BigDecimal minNextBid) { this.minNextBid = minNextBid; }

    public int getTotalBids() { return totalBids; }
    public void setTotalBids(int totalBids) { this.totalBids = totalBids; }

    public int getWatchingCount() { return watchingCount; }
    public void setWatchingCount(int watchingCount) { this.watchingCount = watchingCount; }

    public long getSecondsRemaining() { return secondsRemaining; }
    public void setSecondsRemaining(long secondsRemaining) { this.secondsRemaining = secondsRemaining; }

    public String getTimeLeftFormatted() { return timeLeftFormatted; }
    public void setTimeLeftFormatted(String timeLeftFormatted) { this.timeLeftFormatted = timeLeftFormatted; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public boolean isAuctionEnded() { return isAuctionEnded; }
    public void setAuctionEnded(boolean auctionEnded) { isAuctionEnded = auctionEnded; }

    public boolean isCurrentUserWinning() { return isCurrentUserWinning; }
    public void setCurrentUserWinning(boolean currentUserWinning) { isCurrentUserWinning = currentUserWinning; }

    public boolean isCurrentUserOutbid() { return isCurrentUserOutbid; }
    public void setCurrentUserOutbid(boolean currentUserOutbid) { isCurrentUserOutbid = currentUserOutbid; }

    public BigDecimal getCurrentUserBid() { return currentUserBid; }
    public void setCurrentUserBid(BigDecimal currentUserBid) { this.currentUserBid = currentUserBid; }

    public Integer getCurrentUserRank() { return currentUserRank; }
    public void setCurrentUserRank(Integer currentUserRank) { this.currentUserRank = currentUserRank; }

    public BigDecimal getBehindByAmount() { return behindByAmount; }
    public void setBehindByAmount(BigDecimal behindByAmount) { this.behindByAmount = behindByAmount; }

    public UUID getHighestBidderId() { return highestBidderId; }
    public void setHighestBidderId(UUID highestBidderId) { this.highestBidderId = highestBidderId; }

    public String getHighestBidderName() { return highestBidderName; }
    public void setHighestBidderName(String highestBidderName) { this.highestBidderName = highestBidderName; }

    public Instant getServerTimestamp() { return serverTimestamp; }
    public void setServerTimestamp(Instant serverTimestamp) { this.serverTimestamp = serverTimestamp; }

    public List<BidHistoryItemDto> getLiveBidFeed() { return liveBidFeed; }
    public void setLiveBidFeed(List<BidHistoryItemDto> liveBidFeed) { this.liveBidFeed = liveBidFeed; }
}
