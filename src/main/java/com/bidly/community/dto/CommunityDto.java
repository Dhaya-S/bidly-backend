package com.bidly.community.dto;

import java.time.Instant;
import java.util.UUID;

public class CommunityDto {
    private UUID id;
    private String name;
    private String description;
    private String iconUrl;
    private String bannerUrl;
    private String type;
    private String category;
    private String city;
    private String state;
    private String address;
    private int radiusKm = 5;
    private String rules;
    private UUID createdBy;
    private int membersCount;
    private String recentActivityText;
    private Instant recentActivityTime;
    private String userRole; // "ADMIN", "MEMBER", or null
    private boolean isAdmin;
    private boolean isJoined;
    private int unreadCount;

    public CommunityDto() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

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

    public String getUserRole() { return userRole; }
    public void setUserRole(String userRole) { this.userRole = userRole; }

    public boolean isAdmin() { return isAdmin; }
    public void setAdmin(boolean admin) { isAdmin = admin; }

    public boolean isJoined() { return isJoined; }
    public void setJoined(boolean joined) { isJoined = joined; }

    public int getUnreadCount() { return unreadCount; }
    public void setUnreadCount(int unreadCount) { this.unreadCount = unreadCount; }
}
