package com.bidly.user.dto;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

public class UserDto {
    private UUID id;
    private String phone;
    private String name;
    private String email;
    private String sellerType = "INDIVIDUAL";
    private String avatarUrl;
    private String city;
    private String state;
    private boolean active = true;

    // Setup & Verification
    private boolean identityVerified = false;
    private String identityProvider;
    private int trustScore = 0;
    private String address;
    private String pincode;
    private Double latitude;
    private Double longitude;
    private int searchRadiusKm = 5;
    private boolean onboardingCompleted = false;
    private Set<String> interests = new HashSet<>();
    private Instant createdAt;

    public UserDto() {}

    public UserDto(UUID id, String phone, String name, String avatarUrl, String city, String state, boolean active) {
        this.id = id;
        this.phone = phone;
        this.name = name;
        this.avatarUrl = avatarUrl;
        this.city = city;
        this.state = state;
        this.active = active;
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getSellerType() { return sellerType; }
    public void setSellerType(String sellerType) { this.sellerType = sellerType; }

    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }

    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }

    public boolean isIdentityVerified() { return identityVerified; }
    public void setIdentityVerified(boolean identityVerified) { this.identityVerified = identityVerified; }

    public String getIdentityProvider() { return identityProvider; }
    public void setIdentityProvider(String identityProvider) { this.identityProvider = identityProvider; }

    public int getTrustScore() { return trustScore; }
    public void setTrustScore(int trustScore) { this.trustScore = trustScore; }

    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }

    public String getPincode() { return pincode; }
    public void setPincode(String pincode) { this.pincode = pincode; }

    public Double getLatitude() { return latitude; }
    public void setLatitude(Double latitude) { this.latitude = latitude; }

    public Double getLongitude() { return longitude; }
    public void setLongitude(Double longitude) { this.longitude = longitude; }

    public int getSearchRadiusKm() { return searchRadiusKm; }
    public void setSearchRadiusKm(int searchRadiusKm) { this.searchRadiusKm = searchRadiusKm; }

    public boolean isOnboardingCompleted() { return onboardingCompleted; }
    public void setOnboardingCompleted(boolean onboardingCompleted) { this.onboardingCompleted = onboardingCompleted; }

    public Set<String> getInterests() { return interests; }
    public void setInterests(Set<String> interests) { this.interests = interests; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
