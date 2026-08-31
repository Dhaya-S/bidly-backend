package com.bidly.listing.entity;

import com.bidly.category.entity.Category;
import com.bidly.common.entity.BaseEntity;
import com.bidly.user.entity.User;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Core Listing entity — supports both Direct Buy and Auction bidding with detailed specs.
 */
@Entity
@Table(name = "listings", indexes = {
        @Index(name = "idx_listings_seller", columnList = "seller_id"),
        @Index(name = "idx_listings_category", columnList = "category_id"),
        @Index(name = "idx_listings_status", columnList = "status"),
        @Index(name = "idx_listings_city", columnList = "city"),
        @Index(name = "idx_listings_method", columnList = "selling_method")
})
public class Listing extends BaseEntity {

    @Column(nullable = false, length = 200)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal price;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id", nullable = false)
    private Category category;

    @Column(length = 100)
    private String subcategory;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "seller_id", nullable = false)
    private User seller;

    @Column(length = 100)
    private String city;

    @Column(length = 100)
    private String state;

    @Column(length = 100)
    private String locality;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Condition condition = Condition.LIKE_NEW;

    @Column(name = "purchase_date", length = 50)
    private String purchaseDate;

    @Column(name = "has_damage", nullable = false)
    private boolean hasDamage = false;

    @Column(name = "damage_details", columnDefinition = "TEXT")
    private String damageDetails;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ListingStatus status = ListingStatus.ACTIVE;

    @Enumerated(EnumType.STRING)
    @Column(name = "selling_method", nullable = false, length = 20)
    private SellingMethod sellingMethod = SellingMethod.DIRECT_BUY;

    @Column(name = "selling_scope", nullable = false, length = 50)
    private String sellingScope = "GLOBAL";

    @Column(name = "community_id")
    private UUID communityId;

    @Column(name = "community_name", length = 150)
    private String communityName;

    @Column(name = "target_radius_km")
    private Integer targetRadiusKm;

    @Column(name = "starting_bid", precision = 12, scale = 2)
    private BigDecimal startingBid;

    @Column(name = "current_bid", precision = 12, scale = 2)
    private BigDecimal currentBid;

    @Column(name = "bid_increment", precision = 12, scale = 2)
    private BigDecimal bidIncrement;

    @Column(name = "auction_end_time")
    private Instant auctionEndTime;

    @Column(name = "primary_image_url", columnDefinition = "TEXT")
    private String primaryImageUrl;

    @Column(name = "reel_url", columnDefinition = "TEXT")
    private String reelUrl;

    @Column(name = "rating")
    private Double rating = 4.5;

    @Column(name = "distance_km")
    private Double distanceKm = 2.0;

    @Column(name = "is_featured", nullable = false)
    private boolean featured = false;

    @Column(name = "views_count")
    private long viewsCount = 0;

    @Column(name = "likes_count", nullable = false)
    private int likesCount = 0;

    @Column(name = "bids_count", nullable = false)
    private int bidsCount = 0;

    @Column(name = "latitude")
    private Double latitude;

    @Column(name = "longitude")
    private Double longitude;

    @OneToMany(mappedBy = "listing", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("sortOrder ASC")
    @org.hibernate.annotations.BatchSize(size = 50)
    private List<ListingMedia> media = new ArrayList<>();

    public Listing() {}

    public enum Condition {
        NEW, LIKE_NEW, EXCELLENT, GOOD, FAIR, POOR, USED, REFURBISHED
    }

    public enum ListingStatus {
        ACTIVE, SOLD, EXPIRED, DELETED
    }

    public enum SellingMethod {
        DIRECT_BUY, AUCTION
    }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public BigDecimal getPrice() { return price; }
    public void setPrice(BigDecimal price) { this.price = price; }

    public Category getCategory() { return category; }
    public void setCategory(Category category) { this.category = category; }

    public String getSubcategory() { return subcategory; }
    public void setSubcategory(String subcategory) { this.subcategory = subcategory; }

    public User getSeller() { return seller; }
    public void setSeller(User seller) { this.seller = seller; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }

    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public String getLocality() { return locality; }
    public void setLocality(String locality) { this.locality = locality; }

    public Condition getCondition() { return condition; }
    public void setCondition(Condition condition) { this.condition = condition; }

    public String getPurchaseDate() { return purchaseDate; }
    public void setPurchaseDate(String purchaseDate) { this.purchaseDate = purchaseDate; }

    public boolean isHasDamage() { return hasDamage; }
    public void setHasDamage(boolean hasDamage) { this.hasDamage = hasDamage; }

    public String getDamageDetails() { return damageDetails; }
    public void setDamageDetails(String damageDetails) { this.damageDetails = damageDetails; }

    public ListingStatus getStatus() { return status; }
    public void setStatus(ListingStatus status) { this.status = status; }

    public SellingMethod getSellingMethod() { return sellingMethod; }
    public void setSellingMethod(SellingMethod sellingMethod) { this.sellingMethod = sellingMethod; }

    public String getSellingScope() { return sellingScope; }
    public void setSellingScope(String sellingScope) { this.sellingScope = sellingScope; }

    public UUID getCommunityId() { return communityId; }
    public void setCommunityId(UUID communityId) { this.communityId = communityId; }

    public String getCommunityName() { return communityName; }
    public void setCommunityName(String communityName) { this.communityName = communityName; }

    public Integer getTargetRadiusKm() { return targetRadiusKm; }
    public void setTargetRadiusKm(Integer targetRadiusKm) { this.targetRadiusKm = targetRadiusKm; }

    public BigDecimal getStartingBid() { return startingBid; }
    public void setStartingBid(BigDecimal startingBid) { this.startingBid = startingBid; }

    public BigDecimal getCurrentBid() { return currentBid; }
    public void setCurrentBid(BigDecimal currentBid) { this.currentBid = currentBid; }

    public BigDecimal getBidIncrement() { return bidIncrement; }
    public void setBidIncrement(BigDecimal bidIncrement) { this.bidIncrement = bidIncrement; }

    public Instant getAuctionEndTime() { return auctionEndTime; }
    public void setAuctionEndTime(Instant auctionEndTime) { this.auctionEndTime = auctionEndTime; }

    public String getPrimaryImageUrl() { return primaryImageUrl; }
    public void setPrimaryImageUrl(String primaryImageUrl) { this.primaryImageUrl = primaryImageUrl; }

    public String getReelUrl() { return reelUrl; }
    public void setReelUrl(String reelUrl) { this.reelUrl = reelUrl; }

    public Double getRating() { return rating; }
    public void setRating(Double rating) { this.rating = rating; }

    public Double getDistanceKm() { return distanceKm; }
    public void setDistanceKm(Double distanceKm) { this.distanceKm = distanceKm; }

    public boolean isFeatured() { return featured; }
    public void setFeatured(boolean featured) { this.featured = featured; }

    public long getViewsCount() { return viewsCount; }
    public void setViewsCount(long viewsCount) { this.viewsCount = viewsCount; }

    public Double getLatitude() { return latitude; }
    public void setLatitude(Double latitude) { this.latitude = latitude; }

    public Double getLongitude() { return longitude; }
    public void setLongitude(Double longitude) { this.longitude = longitude; }

    public int getLikesCount() { return likesCount; }
    public void setLikesCount(int likesCount) { this.likesCount = likesCount; }

    public int getBidsCount() { return bidsCount; }
    public void setBidsCount(int bidsCount) { this.bidsCount = bidsCount; }

    public List<ListingMedia> getMedia() { return media; }
    public void setMedia(List<ListingMedia> media) { this.media = media; }
}
