package com.bidly.listing.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

public class CreateListingRequest {

    @NotBlank(message = "Category is required")
    private String category;

    private String subcategory;

    @NotBlank(message = "Title is required")
    private String title;

    private String purchaseDate;

    @NotBlank(message = "Description is required")
    private String description;

    @NotNull(message = "Price is required")
    private BigDecimal price;

    private String condition = "LIKE_NEW";

    private boolean hasDamage = false;

    private String damageDetails;

    private String sellingScope = "GLOBAL";

    private java.util.UUID communityId;
    private String communityName;

    private Integer targetRadiusKm;

    private String sellingMethod = "DIRECT_BUY";

    private BigDecimal startingBid;

    private BigDecimal bidIncrement;

    private Instant auctionEndTime;

    private String reelUrl;

    private List<String> mediaUrls = new ArrayList<>();

    private String city;
    private String state;
    private String locality;
    private Double latitude;
    private Double longitude;

    public CreateListingRequest() {}

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public String getSubcategory() { return subcategory; }
    public void setSubcategory(String subcategory) { this.subcategory = subcategory; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getPurchaseDate() { return purchaseDate; }
    public void setPurchaseDate(String purchaseDate) { this.purchaseDate = purchaseDate; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public BigDecimal getPrice() { return price; }
    public void setPrice(BigDecimal price) { this.price = price; }

    public String getCondition() { return condition; }
    public void setCondition(String condition) { this.condition = condition; }

    public boolean isHasDamage() { return hasDamage; }
    public void setHasDamage(boolean hasDamage) { this.hasDamage = hasDamage; }

    public String getDamageDetails() { return damageDetails; }
    public void setDamageDetails(String damageDetails) { this.damageDetails = damageDetails; }

    public String getSellingScope() { return sellingScope; }
    public void setSellingScope(String sellingScope) { this.sellingScope = sellingScope; }

    public Integer getTargetRadiusKm() { return targetRadiusKm; }
    public void setTargetRadiusKm(Integer targetRadiusKm) { this.targetRadiusKm = targetRadiusKm; }

    public String getSellingMethod() { return sellingMethod; }
    public void setSellingMethod(String sellingMethod) { this.sellingMethod = sellingMethod; }

    public BigDecimal getStartingBid() { return startingBid; }
    public void setStartingBid(BigDecimal startingBid) { this.startingBid = startingBid; }

    public BigDecimal getBidIncrement() { return bidIncrement; }
    public void setBidIncrement(BigDecimal bidIncrement) { this.bidIncrement = bidIncrement; }

    public Instant getAuctionEndTime() { return auctionEndTime; }
    public void setAuctionEndTime(Instant auctionEndTime) { this.auctionEndTime = auctionEndTime; }

    public String getReelUrl() { return reelUrl; }
    public void setReelUrl(String reelUrl) { this.reelUrl = reelUrl; }

    public List<String> getMediaUrls() { return mediaUrls; }
    public void setMediaUrls(List<String> mediaUrls) { this.mediaUrls = mediaUrls; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }

    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public String getLocality() { return locality; }
    public void setLocality(String locality) { this.locality = locality; }

    public Double getLatitude() { return latitude; }
    public void setLatitude(Double latitude) { this.latitude = latitude; }

    public Double getLongitude() { return longitude; }
    public void setLongitude(Double longitude) { this.longitude = longitude; }

    private String sellerId;
    private String sellerName;
    private String sellerPhone;

    public java.util.UUID getCommunityId() { return communityId; }
    public void setCommunityId(java.util.UUID communityId) { this.communityId = communityId; }

    public String getCommunityName() { return communityName; }
    public void setCommunityName(String communityName) { this.communityName = communityName; }

    public String getSellerId() { return sellerId; }
    public void setSellerId(String sellerId) { this.sellerId = sellerId; }

    public String getSellerName() { return sellerName; }
    public void setSellerName(String sellerName) { this.sellerName = sellerName; }

    public String getSellerPhone() { return sellerPhone; }
    public void setSellerPhone(String sellerPhone) { this.sellerPhone = sellerPhone; }
}
