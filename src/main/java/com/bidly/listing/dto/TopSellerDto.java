package com.bidly.listing.dto;

import java.util.UUID;

public class TopSellerDto {
    private UUID id;
    private String name;
    private String avatarUrl;
    private String initials;
    private String colorHex;
    private int listingsCount;
    private Double rating;

    public TopSellerDto() {}

    public TopSellerDto(UUID id, String name, String avatarUrl, String initials, String colorHex, int listingsCount, Double rating) {
        this.id = id;
        this.name = name;
        this.avatarUrl = avatarUrl;
        this.initials = initials;
        this.colorHex = colorHex;
        this.listingsCount = listingsCount;
        this.rating = rating;
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }

    public String getInitials() { return initials; }
    public void setInitials(String initials) { this.initials = initials; }

    public String getColorHex() { return colorHex; }
    public void setColorHex(String colorHex) { this.colorHex = colorHex; }

    public int getListingsCount() { return listingsCount; }
    public void setListingsCount(int listingsCount) { this.listingsCount = listingsCount; }

    public Double getRating() { return rating; }
    public void setRating(Double rating) { this.rating = rating; }
}
