package com.bidly.community.dto;

import java.time.Instant;
import java.util.UUID;

public class CommunityMemberDto {
    private UUID userId;
    private String name;
    private String phone;
    private String avatarUrl;
    private String role; // "ADMIN", "MEMBER"
    private Instant joinedAt;

    public CommunityMemberDto() {}

    public CommunityMemberDto(UUID userId, String name, String phone, String avatarUrl, String role, Instant joinedAt) {
        this.userId = userId;
        this.name = name;
        this.phone = phone;
        this.avatarUrl = avatarUrl;
        this.role = role;
        this.joinedAt = joinedAt;
    }

    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }

    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }

    public Instant getJoinedAt() { return joinedAt; }
    public void setJoinedAt(Instant joinedAt) { this.joinedAt = joinedAt; }
}
