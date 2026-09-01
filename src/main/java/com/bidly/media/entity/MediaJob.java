package com.bidly.media.entity;

import com.bidly.common.entity.BaseEntity;
import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "media_jobs")
public class MediaJob extends BaseEntity {

    @Column(name = "media_url", nullable = false, columnDefinition = "TEXT")
    private String mediaUrl;

    @Column(name = "thumbnail_url", columnDefinition = "TEXT")
    private String thumbnailUrl;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ProcessingStatus status = ProcessingStatus.PROCESSING;

    @Column(name = "error_message", columnDefinition = "TEXT")
    private String errorMessage;

    public MediaJob() {}

    public MediaJob(String mediaUrl, String thumbnailUrl, ProcessingStatus status) {
        this.mediaUrl = mediaUrl;
        this.thumbnailUrl = thumbnailUrl;
        this.status = status;
    }

    public enum ProcessingStatus {
        UPLOADING, PROCESSING, READY, FAILED
    }

    public String getMediaUrl() { return mediaUrl; }
    public void setMediaUrl(String mediaUrl) { this.mediaUrl = mediaUrl; }

    public String getThumbnailUrl() { return thumbnailUrl; }
    public void setThumbnailUrl(String thumbnailUrl) { this.thumbnailUrl = thumbnailUrl; }

    public ProcessingStatus getStatus() { return status; }
    public void setStatus(ProcessingStatus status) { this.status = status; }

    public String getErrorMessage() { return errorMessage; }
    public void setErrorMessage(String errorMessage) { this.errorMessage = errorMessage; }
}
