package com.bidly.auction.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public class AuctionDetailsDto {
    private UUID listingId;
    private String title;
    private String productCondition;
    private String primaryImageUrl;
    private List<String> imageUrls;
    private BigDecimal startingBid;
    private BigDecimal currentHighestBid;
    private BigDecimal minNextBid;
    private BigDecimal minBidIncrement;
    private Instant auctionEndTime;
    private long secondsRemaining;
    private String timeLeftFormatted;
    private int totalBids;
    private int watchingCount;
    private UUID highestBidderId;
    private String highestBidderName;
    private String highestBidderTime;
    private String status; // ACTIVE, ENDED, WON, LOST
    private boolean isAuctionEnded;
    private boolean isCurrentUserWinning;
    private BigDecimal currentUserBid;
    private Integer currentUserRank;
    private int winProbability; // Calculated competitive score (e.g. 10-95%)
    private BigDecimal platformFee; // 2% platform fee
    private BigDecimal totalPayable; // bid + platform fee
    private UUID sellerId;
    private String sellerName;
    private Double sellerRating;
    private int sellerReviewsCount;
    private int sellerSalesCount;
    private String city;
    private String state;
    private List<BidHistoryItemDto> recentBids;

    public AuctionDetailsDto() {}

    public UUID getListingId() { return listingId; }
    public void setListingId(UUID listingId) { this.listingId = listingId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getProductCondition() { return productCondition; }
    public void setProductCondition(String productCondition) { this.productCondition = productCondition; }

    public String getPrimaryImageUrl() { return primaryImageUrl; }
    public void setPrimaryImageUrl(String primaryImageUrl) { this.primaryImageUrl = primaryImageUrl; }

    public List<String> getImageUrls() { return imageUrls; }
    public void setImageUrls(List<String> imageUrls) { this.imageUrls = imageUrls; }

    public BigDecimal getStartingBid() { return startingBid; }
    public void setStartingBid(BigDecimal startingBid) { this.startingBid = startingBid; }

    public BigDecimal getCurrentHighestBid() { return currentHighestBid; }
    public void setCurrentHighestBid(BigDecimal currentHighestBid) { this.currentHighestBid = currentHighestBid; }

    public BigDecimal getMinNextBid() { return minNextBid; }
    public void setMinNextBid(BigDecimal minNextBid) { this.minNextBid = minNextBid; }

    public BigDecimal getMinBidIncrement() { return minBidIncrement; }
    public void setMinBidIncrement(BigDecimal minBidIncrement) { this.minBidIncrement = minBidIncrement; }

    public Instant getAuctionEndTime() { return auctionEndTime; }
    public void setAuctionEndTime(Instant auctionEndTime) { this.auctionEndTime = auctionEndTime; }

    public long getSecondsRemaining() { return secondsRemaining; }
    public void setSecondsRemaining(long secondsRemaining) { this.secondsRemaining = secondsRemaining; }

    public String getTimeLeftFormatted() { return timeLeftFormatted; }
    public void setTimeLeftFormatted(String timeLeftFormatted) { this.timeLeftFormatted = timeLeftFormatted; }

    public int getTotalBids() { return totalBids; }
    public void setTotalBids(int totalBids) { this.totalBids = totalBids; }

    public int getWatchingCount() { return watchingCount; }
    public void setWatchingCount(int watchingCount) { this.watchingCount = watchingCount; }

    public UUID getHighestBidderId() { return highestBidderId; }
    public void setHighestBidderId(UUID highestBidderId) { this.highestBidderId = highestBidderId; }

    public String getHighestBidderName() { return highestBidderName; }
    public void setHighestBidderName(String highestBidderName) { this.highestBidderName = highestBidderName; }

    public String getHighestBidderTime() { return highestBidderTime; }
    public void setHighestBidderTime(String highestBidderTime) { this.highestBidderTime = highestBidderTime; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public boolean isAuctionEnded() { return isAuctionEnded; }
    public void setAuctionEnded(boolean auctionEnded) { isAuctionEnded = auctionEnded; }

    public boolean isCurrentUserWinning() { return isCurrentUserWinning; }
    public void setCurrentUserWinning(boolean currentUserWinning) { isCurrentUserWinning = currentUserWinning; }

    public BigDecimal getCurrentUserBid() { return currentUserBid; }
    public void setCurrentUserBid(BigDecimal currentUserBid) { this.currentUserBid = currentUserBid; }

    public Integer getCurrentUserRank() { return currentUserRank; }
    public void setCurrentUserRank(Integer currentUserRank) { this.currentUserRank = currentUserRank; }

    public int getWinProbability() { return winProbability; }
    public void setWinProbability(int winProbability) { this.winProbability = winProbability; }

    public BigDecimal getPlatformFee() { return platformFee; }
    public void setPlatformFee(BigDecimal platformFee) { this.platformFee = platformFee; }

    public BigDecimal getTotalPayable() { return totalPayable; }
    public void setTotalPayable(BigDecimal totalPayable) { this.totalPayable = totalPayable; }

    public UUID getSellerId() { return sellerId; }
    public void setSellerId(UUID sellerId) { this.sellerId = sellerId; }

    public String getSellerName() { return sellerName; }
    public void setSellerName(String sellerName) { this.sellerName = sellerName; }

    public Double getSellerRating() { return sellerRating; }
    public void setSellerRating(Double sellerRating) { this.sellerRating = sellerRating; }

    public int getSellerReviewsCount() { return sellerReviewsCount; }
    public void setSellerReviewsCount(int sellerReviewsCount) { this.sellerReviewsCount = sellerReviewsCount; }

    public int getSellerSalesCount() { return sellerSalesCount; }
    public void setSellerSalesCount(int sellerSalesCount) { this.sellerSalesCount = sellerSalesCount; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }

    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public List<BidHistoryItemDto> getRecentBids() { return recentBids; }
    public void setRecentBids(List<BidHistoryItemDto> recentBids) { this.recentBids = recentBids; }
}
