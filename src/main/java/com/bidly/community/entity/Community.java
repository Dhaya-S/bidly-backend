package com.bidly.community.entity;

import com.bidly.common.entity.BaseEntity;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Represents a community group (college, apartment, neighborhood, interest group).
 */
@Entity
@Table(name = "communities")
public class Community extends BaseEntity {

    @Column(nullable = false, length = 150)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "icon_url")
    private String iconUrl;

    @Column(name = "banner_url")
    private String bannerUrl;

    @Column(nullable = false, length = 50)
    private String type = "NEIGHBORHOOD";

    @Column(length = 100)
    private String category = "Other";

    @Column(length = 100)
    private String city = "Chennai";

    @Column(length = 100)
    private String state = "Tamil Nadu";

    @Column(length = 255)
    private String address;

    @Column(name = "latitude")
    private Double latitude;

    @Column(name = "longitude")
    private Double longitude;

    @Column(name = "radius_km")
    private int radiusKm = 5;

    @Column(columnDefinition = "TEXT")
    private String rules;

    @Column(name = "created_by")
    private UUID createdBy;

    @Column(name = "members_count", nullable = false)
    private int membersCount = 1;

    @Column(name = "recent_activity_text", columnDefinition = "TEXT")
    private String recentActivityText;

    @Column(name = "recent_activity_time")
    private Instant recentActivityTime = Instant.now();

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    public Community() {}

    public Community(String name, String description, String iconUrl, String bannerUrl, String type, String city, String state, int membersCount, boolean active) {
        this.name = name;
        this.description = description;
        this.iconUrl = iconUrl;
        this.bannerUrl = bannerUrl;
        this.type = type;
        this.city = city;
        this.state = state;
        this.membersCount = membersCount;
        this.active = active;
    }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getIconUrl() { return iconUrl; }
    public void setIconUrl(String iconUrl) { this.iconUrl = iconUrl; }

    public String getBannerUrl() { return bannerUrl; }
    public void setBannerUrl(String bannerUrl) { this.bannerUrl = bannerUrl; }

    public String getType() { return type; }
    public void setType(String type) { this.type = type; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }

    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }

    public Double getLatitude() { return latitude; }
    public void setLatitude(Double latitude) { this.latitude = latitude; }

    public Double getLongitude() { return longitude; }
    public void setLongitude(Double longitude) { this.longitude = longitude; }

    public int getRadiusKm() { return radiusKm; }
    public void setRadiusKm(int radiusKm) { this.radiusKm = radiusKm; }

    public String getRules() { return rules; }
    public void setRules(String rules) { this.rules = rules; }

    public UUID getCreatedBy() { return createdBy; }
    public void setCreatedBy(UUID createdBy) { this.createdBy = createdBy; }

    public int getMembersCount() { return membersCount; }
    public void setMembersCount(int membersCount) { this.membersCount = membersCount; }

    public String getRecentActivityText() { return recentActivityText; }
    public void setRecentActivityText(String recentActivityText) { this.recentActivityText = recentActivityText; }

    public Instant getRecentActivityTime() { return recentActivityTime; }
    public void setRecentActivityTime(Instant recentActivityTime) { this.recentActivityTime = recentActivityTime; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }
}
