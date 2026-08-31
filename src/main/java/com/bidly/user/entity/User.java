package com.bidly.user.entity;

import com.bidly.common.entity.BaseEntity;
import jakarta.persistence.*;

import java.util.HashSet;
import java.util.Set;

/**
 * Represents a Bidly user — identified by phone number, authenticated via OTP.
 */
@Entity
@Table(name = "users",
        uniqueConstraints = @UniqueConstraint(name = "uk_users_phone", columnNames = "phone"))
public class User extends BaseEntity {

    @Column(nullable = false, length = 20)
    private String phone;

    @Column(length = 100)
    private String name;

    @Column(length = 150)
    private String email;

    @Column(name = "seller_type", length = 50)
    private String sellerType = "INDIVIDUAL";

    @Column(name = "avatar_url")
    private String avatarUrl;

    @Column(length = 100)
    private String city;

    @Column(length = 100)
    private String state;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    // ── Setup & Verification Fields ─────────────────────────
    @Column(name = "is_identity_verified", nullable = false)
    private boolean identityVerified = false;

    @Column(name = "identity_provider", length = 50)
    private String identityProvider;

    @Column(name = "trust_score")
    private int trustScore = 0;

    @Column(name = "address", columnDefinition = "TEXT")
    private String address;

    @Column(name = "pincode", length = 20)
    private String pincode;

    @Column(name = "latitude")
    private Double latitude;

    @Column(name = "longitude")
    private Double longitude;

    @Column(name = "search_radius_km")
    private int searchRadiusKm = 5;

    @Column(name = "onboarding_completed", nullable = false)
    private boolean onboardingCompleted = false;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "user_interests", joinColumns = @JoinColumn(name = "user_id"))
    @Column(name = "category_name")
    private Set<String> interests = new HashSet<>();

    public User() {}

    public User(String phone, String name, String avatarUrl, String city, String state, boolean active) {
        this.phone = phone;
        this.name = name;
        this.avatarUrl = avatarUrl;
        this.city = city;
        this.state = state;
        this.active = active;
    }

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
}
