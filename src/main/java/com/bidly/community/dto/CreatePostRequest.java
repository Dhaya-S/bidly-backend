package com.bidly.community.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.UUID;

public class CreatePostRequest {
    private UUID communityId;

    @NotBlank(message = "Post content cannot be empty")
    private String content;

    private String mediaUrl;
    private String mediaType = "IMAGE";
    private String tag = "SELLING"; // SELLING, ANNOUNCEMENT, REVIEW, GENERAL

    public CreatePostRequest() {}

    public UUID getCommunityId() { return communityId; }
    public void setCommunityId(UUID communityId) { this.communityId = communityId; }

    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }

    public String getMediaUrl() { return mediaUrl; }
    public void setMediaUrl(String mediaUrl) { this.mediaUrl = mediaUrl; }

    public String getMediaType() { return mediaType; }
    public void setMediaType(String mediaType) { this.mediaType = mediaType; }

    public String getTag() { return tag; }
    public void setTag(String tag) { this.tag = tag; }
}
