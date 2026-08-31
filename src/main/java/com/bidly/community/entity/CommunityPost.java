package com.bidly.community.entity;

import com.bidly.common.entity.BaseEntity;
import com.bidly.user.entity.User;
import jakarta.persistence.*;

/**
 * Community Post (selling ad post, announcement, review, community feed post).
 */
@Entity
@Table(name = "community_posts")
public class CommunityPost extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User author;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "community_id")
    private Community community;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "listing_id")
    private com.bidly.listing.entity.Listing listing;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(name = "media_url", length = 500)
    private String mediaUrl;

    @Column(name = "media_type", length = 20)
    private String mediaType = "IMAGE";

    @Column(nullable = false, length = 50)
    private String tag = "SELLING"; // SELLING, ANNOUNCEMENT, REVIEW, GENERAL

    @Column(name = "likes_count", nullable = false)
    private int likesCount = 0;

    @Column(name = "shares_count", nullable = false)
    private int sharesCount = 0;

    public CommunityPost() {}

    public CommunityPost(User author, Community community, String content, String mediaUrl, String mediaType, String tag, int likesCount, int sharesCount) {
        this.author = author;
        this.community = community;
        this.content = content;
        this.mediaUrl = mediaUrl;
        this.mediaType = mediaType;
        this.tag = tag;
        this.likesCount = likesCount;
        this.sharesCount = sharesCount;
    }

    public User getAuthor() { return author; }
    public void setAuthor(User author) { this.author = author; }

    public Community getCommunity() { return community; }
    public void setCommunity(Community community) { this.community = community; }

    public com.bidly.listing.entity.Listing getListing() { return listing; }
    public void setListing(com.bidly.listing.entity.Listing listing) { this.listing = listing; }

    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }

    public String getMediaUrl() { return mediaUrl; }
    public void setMediaUrl(String mediaUrl) { this.mediaUrl = mediaUrl; }

    public String getMediaType() { return mediaType; }
    public void setMediaType(String mediaType) { this.mediaType = mediaType; }

    public String getTag() { return tag; }
    public void setTag(String tag) { this.tag = tag; }

    public int getLikesCount() { return likesCount; }
    public void setLikesCount(int likesCount) { this.likesCount = likesCount; }

    public int getSharesCount() { return sharesCount; }
    public void setSharesCount(int sharesCount) { this.sharesCount = sharesCount; }
}
