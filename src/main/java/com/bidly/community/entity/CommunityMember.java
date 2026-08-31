package com.bidly.community.entity;

import com.bidly.common.entity.BaseEntity;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Represents a member of a community and their access level (ADMIN vs MEMBER).
 */
@Entity
@Table(name = "community_members",
        uniqueConstraints = @UniqueConstraint(name = "uk_community_user", columnNames = {"community_id", "user_id"}))
public class CommunityMember extends BaseEntity {

    @Column(name = "community_id", nullable = false)
    private UUID communityId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false, length = 30)
    private String role = "MEMBER"; // "ADMIN", "MEMBER"

    @Column(name = "joined_at", nullable = false)
    private Instant joinedAt = Instant.now();

    public CommunityMember() {}

    public CommunityMember(UUID communityId, UUID userId, String role) {
        this.communityId = communityId;
        this.userId = userId;
        this.role = role;
        this.joinedAt = Instant.now();
    }

    public UUID getCommunityId() { return communityId; }
    public void setCommunityId(UUID communityId) { this.communityId = communityId; }

    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }

    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }

    public Instant getJoinedAt() { return joinedAt; }
    public void setJoinedAt(Instant joinedAt) { this.joinedAt = joinedAt; }
}
