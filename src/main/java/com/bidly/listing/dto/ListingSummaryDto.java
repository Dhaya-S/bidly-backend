package com.bidly.listing.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public class ListingSummaryDto {
    private UUID id;
    private String title;
    private String description;
    private BigDecimal price;
    private String primaryImageUrl;
    private List<String> imageUrls = new ArrayList<>();
    private List<MediaItemDto> mediaItems = new ArrayList<>();
    private String city;
    private String state;
    private String locality;
    private String condition;
    private String sellingMethod; // DIRECT_BUY, AUCTION
    private String sellingScope;  // GLOBAL, COMMUNITIES, CUSTOM_RADIUS
    private UUID communityId;
    private String communityName;
    private String subcategory;
    private String purchaseDate;
    private boolean hasDamage;
    private String damageDetails;
    private BigDecimal startingBid;
    private BigDecimal currentBid;
    private BigDecimal bidIncrement;
    private Instant auctionEndTime;
    private String reelUrl;
    private Double rating;
    private Double distanceKm;
    private boolean isWishlisted;
    private String sellerName;
    private UUID sellerId;
    private String categoryName;
    private int likesCount;
    private int bidsCount;

    @com.fasterxml.jackson.annotation.JsonProperty("isLikedByMe")
    private boolean isLikedByMe;

    public ListingSummaryDto() {}

    public int getLikesCount() { return likesCount; }
    public void setLikesCount(int likesCount) { this.likesCount = likesCount; }

    public int getBidsCount() { return bidsCount; }
    public void setBidsCount(int bidsCount) { this.bidsCount = bidsCount; }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public BigDecimal getPrice() { return price; }
    public void setPrice(BigDecimal price) { this.price = price; }

    public String getPrimaryImageUrl() { return primaryImageUrl; }
    public void setPrimaryImageUrl(String primaryImageUrl) { this.primaryImageUrl = primaryImageUrl; }

    public List<String> getImageUrls() { return imageUrls; }
    public void setImageUrls(List<String> imageUrls) { this.imageUrls = imageUrls; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }

    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public String getLocality() { return locality; }
    public void setLocality(String locality) { this.locality = locality; }

    public String getCondition() { return condition; }
    public void setCondition(String condition) { this.condition = condition; }

    public String getSellingMethod() { return sellingMethod; }
    public void setSellingMethod(String sellingMethod) { this.sellingMethod = sellingMethod; }

    public String getSellingScope() { return sellingScope; }
    public void setSellingScope(String sellingScope) { this.sellingScope = sellingScope; }

    public String getSubcategory() { return subcategory; }
    public void setSubcategory(String subcategory) { this.subcategory = subcategory; }

    public String getPurchaseDate() { return purchaseDate; }
    public void setPurchaseDate(String purchaseDate) { this.purchaseDate = purchaseDate; }

    public boolean isHasDamage() { return hasDamage; }
    public void setHasDamage(boolean hasDamage) { this.hasDamage = hasDamage; }

    public String getDamageDetails() { return damageDetails; }
    public void setDamageDetails(String damageDetails) { this.damageDetails = damageDetails; }

    public BigDecimal getStartingBid() { return startingBid; }
    public void setStartingBid(BigDecimal startingBid) { this.startingBid = startingBid; }

    public BigDecimal getCurrentBid() { return currentBid; }
    public void setCurrentBid(BigDecimal currentBid) { this.currentBid = currentBid; }

    public BigDecimal getBidIncrement() { return bidIncrement; }
    public void setBidIncrement(BigDecimal bidIncrement) { this.bidIncrement = bidIncrement; }

    public Instant getAuctionEndTime() { return auctionEndTime; }
    public void setAuctionEndTime(Instant auctionEndTime) { this.auctionEndTime = auctionEndTime; }

    public String getReelUrl() { return reelUrl; }
    public void setReelUrl(String reelUrl) { this.reelUrl = reelUrl; }

    public Double getRating() { return rating; }
    public void setRating(Double rating) { this.rating = rating; }

    public Double getDistanceKm() { return distanceKm; }
    public void setDistanceKm(Double distanceKm) { this.distanceKm = distanceKm; }

    public boolean isWishlisted() { return isWishlisted; }
    public void setWishlisted(boolean wishlisted) { isWishlisted = wishlisted; }

    public String getSellerName() { return sellerName; }
    public void setSellerName(String sellerName) { this.sellerName = sellerName; }

    public UUID getSellerId() { return sellerId; }
    public void setSellerId(UUID sellerId) { this.sellerId = sellerId; }

    public String getCategoryName() { return categoryName; }
    public void setCategoryName(String categoryName) { this.categoryName = categoryName; }

    public UUID getCommunityId() { return communityId; }
    public void setCommunityId(UUID communityId) { this.communityId = communityId; }

    public String getCommunityName() { return communityName; }
    public void setCommunityName(String communityName) { this.communityName = communityName; }

    public boolean isLikedByMe() { return isLikedByMe; }
    public void setLikedByMe(boolean likedByMe) { isLikedByMe = likedByMe; }

    public List<MediaItemDto> getMediaItems() { return mediaItems; }
    public void setMediaItems(List<MediaItemDto> mediaItems) { this.mediaItems = mediaItems; }

    public static class MediaItemDto {
        private String url;
        private String type; // IMAGE or VIDEO
        private int sortOrder;

        public MediaItemDto() {}

        public MediaItemDto(String url, String type, int sortOrder) {
            this.url = url;
            this.type = type;
            this.sortOrder = sortOrder;
        }

        public String getUrl() { return url; }
        public void setUrl(String url) { this.url = url; }

        public String getType() { return type; }
        public void setType(String type) { this.type = type; }

        public int getSortOrder() { return sortOrder; }
        public void setSortOrder(int sortOrder) { this.sortOrder = sortOrder; }
    }
}
