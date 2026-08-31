package com.bidly.media.dto;

/**
 * Response payload for a pre-signed R2 upload URL request.
 */
public class PresignedUrlResponse {
    private String uploadUrl;
    private String publicUrl;
    private String objectKey;
    private long expiresInSeconds;

    public PresignedUrlResponse() {}

    public PresignedUrlResponse(String uploadUrl, String publicUrl, String objectKey, long expiresInSeconds) {
        this.uploadUrl = uploadUrl;
        this.publicUrl = publicUrl;
        this.objectKey = objectKey;
        this.expiresInSeconds = expiresInSeconds;
    }

    public static Builder builder() {
        return new Builder();
    }

    public static class Builder {
        private String uploadUrl;
        private String publicUrl;
        private String objectKey;
        private long expiresInSeconds;

        public Builder uploadUrl(String uploadUrl) { this.uploadUrl = uploadUrl; return this; }
        public Builder publicUrl(String publicUrl) { this.publicUrl = publicUrl; return this; }
        public Builder objectKey(String objectKey) { this.objectKey = objectKey; return this; }
        public Builder expiresInSeconds(long expiresInSeconds) { this.expiresInSeconds = expiresInSeconds; return this; }

        public PresignedUrlResponse build() {
            return new PresignedUrlResponse(uploadUrl, publicUrl, objectKey, expiresInSeconds);
        }
    }

    public String getUploadUrl() { return uploadUrl; }
    public void setUploadUrl(String uploadUrl) { this.uploadUrl = uploadUrl; }

    public String getPublicUrl() { return publicUrl; }
    public void setPublicUrl(String publicUrl) { this.publicUrl = publicUrl; }

    public String getObjectKey() { return objectKey; }
    public void setObjectKey(String objectKey) { this.objectKey = objectKey; }

    public long getExpiresInSeconds() { return expiresInSeconds; }
    public void setExpiresInSeconds(long expiresInSeconds) { this.expiresInSeconds = expiresInSeconds; }
}
