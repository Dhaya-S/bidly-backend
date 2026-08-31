package com.bidly.media.service;

import com.bidly.common.exception.BidlyException;
import com.bidly.media.dto.PresignedUrlResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedGetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

import java.time.Duration;
import java.util.UUID;

/**
 * Handles Cloudflare R2 media operations (both Presigned URL and direct Multipart uploads).
 */
@Service
public class MediaService {

    private static final Logger log = LoggerFactory.getLogger(MediaService.class);

    private final S3Client s3Client;
    private final S3Presigner s3Presigner;
    private final VideoProcessingService videoProcessingService;

    @Value("${cloudflare.r2.bucket-name}")
    private String bucketName;

    @Value("${cloudflare.r2.public-url}")
    private String publicUrl;

    @Value("${cloudflare.r2.presigned-url-expiry-minutes:15}")
    private int presignedExpiryMinutes;

    @Value("${media.video.processing-fallback-enabled:true}")
    private boolean processingFallbackEnabled;

    public MediaService(S3Client s3Client, S3Presigner s3Presigner, VideoProcessingService videoProcessingService) {
        this.s3Client = s3Client;
        this.s3Presigner = s3Presigner;
        this.videoProcessingService = videoProcessingService;
    }

    /**
     * Upload a MultipartFile directly to Cloudflare R2.
     * If the file is a Reel video (folder contains 'reels' or video MIME/extension),
     * it processes the video through VideoProcessingService to produce a mobile-optimized H.264
     * fast-start MP4 and companion thumbnail poster.
     *
     * Returns a Map containing:
     * - "url": Canonical object key / URL of the uploaded media
     * - "thumbnailUrl": Optional canonical object key / URL of the generated poster (or null)
     */
    public java.util.Map<String, String> uploadMediaFile(MultipartFile file, String folder) {
        if (file == null || file.isEmpty()) {
            throw BidlyException.badRequest("Uploaded file cannot be empty");
        }

        String originalFilename = file.getOriginalFilename();
        boolean isReelVideo = (folder != null && folder.contains("reels"))
                || (file.getContentType() != null && file.getContentType().startsWith("video/"))
                || isVideoFilename(originalFilename);

        if (!isReelVideo) {
            // Standard image / asset upload directly to R2 (no video transcoding)
            String objectKey = uploadDirectToR2(file, folder);
            java.util.Map<String, String> result = new java.util.HashMap<>();
            result.put("url", objectKey);
            result.put("thumbnailUrl", null);
            return result;
        }

        // Reel Video processing pipeline
        log.info("[MEDIA_UPLOAD] type=VIDEO folder='{}' filename='{}' size={}", folder, originalFilename, file.getSize());

        try (com.bidly.media.dto.VideoProcessingResult procResult = videoProcessingService.processVideo(file)) {
            String uuid = UUID.randomUUID().toString();
            String videoKey = folder + "/" + uuid + ".mp4";
            String thumbKey = folder + "/" + uuid + "-thumb.jpg";

            // Upload optimized MP4 to Cloudflare R2
            java.io.File optFile = procResult.getOptimizedVideoFile();
            PutObjectRequest videoPut = PutObjectRequest.builder()
                    .bucket(bucketName)
                    .key(videoKey)
                    .contentType("video/mp4")
                    .contentLength(optFile.length())
                    .build();

            s3Client.putObject(videoPut, RequestBody.fromFile(optFile));
            log.info("[R2_UPLOAD] VIDEO key='{}' size={} fastStart={}", videoKey, optFile.length(), procResult.isFastStartVerified());

            // Upload companion thumbnail poster if generated
            java.io.File thumbFile = procResult.getThumbnailFile();
            String finalThumbKey = null;
            if (thumbFile != null && thumbFile.exists() && thumbFile.length() > 0) {
                PutObjectRequest thumbPut = PutObjectRequest.builder()
                        .bucket(bucketName)
                        .key(thumbKey)
                        .contentType("image/jpeg")
                        .contentLength(thumbFile.length())
                        .build();

                s3Client.putObject(thumbPut, RequestBody.fromFile(thumbFile));
                log.info("[R2_UPLOAD] THUMBNAIL key='{}' size={}", thumbKey, thumbFile.length());
                finalThumbKey = thumbKey;
            }

            log.info("[MEDIA_UPLOAD] SUCCESS video='{}' thumb='{}'", videoKey, finalThumbKey);

            java.util.Map<String, String> result = new java.util.HashMap<>();
            result.put("url", videoKey);
            result.put("thumbnailUrl", finalThumbKey);
            return result;

        } catch (Exception e) {
            log.warn("[VIDEO_PROCESS] Video processing failed: {}", e.getMessage());
            if (processingFallbackEnabled) {
                log.warn("[VIDEO_PROCESS] FALLBACK_TO_ORIGINAL: uploading raw video without transcoding");
                String fallbackKey = uploadDirectToR2(file, folder);
                java.util.Map<String, String> result = new java.util.HashMap<>();
                result.put("url", fallbackKey);
                result.put("thumbnailUrl", null);
                return result;
            } else {
                if (e instanceof BidlyException) {
                    throw (BidlyException) e;
                }
                throw BidlyException.internal("Video processing failed: " + e.getMessage());
            }
        }
    }

    /**
     * Process and upload a local video File to R2 (used for legacy media migrations).
     */
    public java.util.Map<String, String> processAndUploadLocalVideo(java.io.File sourceFile, String folder) {
        try (com.bidly.media.dto.VideoProcessingResult procResult = videoProcessingService.processFile(sourceFile)) {
            String uuid = UUID.randomUUID().toString();
            String videoKey = folder + "/" + uuid + ".mp4";
            String thumbKey = folder + "/" + uuid + "-thumb.jpg";

            // Upload optimized MP4 to Cloudflare R2
            java.io.File optFile = procResult.getOptimizedVideoFile();
            PutObjectRequest videoPut = PutObjectRequest.builder()
                    .bucket(bucketName)
                    .key(videoKey)
                    .contentType("video/mp4")
                    .contentLength(optFile.length())
                    .build();

            s3Client.putObject(videoPut, RequestBody.fromFile(optFile));
            log.info("[R2_MIGRATE] Uploaded optimized MP4 key='{}' size={}", videoKey, optFile.length());

            // Upload companion thumbnail poster if generated
            java.io.File thumbFile = procResult.getThumbnailFile();
            String finalThumbKey = null;
            if (thumbFile != null && thumbFile.exists() && thumbFile.length() > 0) {
                PutObjectRequest thumbPut = PutObjectRequest.builder()
                        .bucket(bucketName)
                        .key(thumbKey)
                        .contentType("image/jpeg")
                        .contentLength(thumbFile.length())
                        .build();

                s3Client.putObject(thumbPut, RequestBody.fromFile(thumbFile));
                log.info("[R2_MIGRATE] Uploaded companion poster key='{}' size={}", thumbKey, thumbFile.length());
                finalThumbKey = thumbKey;
            }

            java.util.Map<String, String> result = new java.util.HashMap<>();
            result.put("url", videoKey);
            result.put("thumbnailUrl", finalThumbKey);
            return result;
        } catch (Exception e) {
            log.warn("[R2_MIGRATE] Video migration failed: {}", e.getMessage());
            throw BidlyException.internal("Video migration failed: " + e.getMessage());
        }
    }

    /**
     * Probe a local video File for codec metadata.
     */
    public com.bidly.media.dto.VideoMetadata probeVideo(java.io.File file) {
        return videoProcessingService.probeVideo(file);
    }

    private boolean isVideoFilename(String filename) {
        if (filename == null || !filename.contains(".")) return false;
        String ext = filename.substring(filename.lastIndexOf(".") + 1).toLowerCase();
        return ext.equals("mp4") || ext.equals("mov") || ext.equals("m4v") ||
               ext.equals("webm") || ext.equals("3gp") || ext.equals("mkv") || ext.equals("avi");
    }

    private String uploadDirectToR2(MultipartFile file, String folder) {
        try {
            String originalFilename = file.getOriginalFilename();
            String ext = "jpg";
            if (originalFilename != null && originalFilename.contains(".")) {
                ext = originalFilename.substring(originalFilename.lastIndexOf(".") + 1);
            }
            String objectKey = folder + "/" + UUID.randomUUID() + "." + ext;
            String contentType = file.getContentType() != null ? file.getContentType() : "application/octet-stream";
            long fileSize = file.getSize();

            PutObjectRequest putRequest = PutObjectRequest.builder()
                    .bucket(bucketName)
                    .key(objectKey)
                    .contentType(contentType)
                    .contentLength(fileSize)
                    .build();

            s3Client.putObject(putRequest, RequestBody.fromInputStream(file.getInputStream(), fileSize));
            log.info("[R2_UPLOAD] RAW key='{}' size={}", objectKey, fileSize);
            return objectKey;
        } catch (Exception e) {
            log.error("Cloudflare R2 upload error: {}", e.getMessage(), e);
            throw BidlyException.internal("Failed to upload file to Cloudflare R2: " + e.getMessage());
        }
    }

    /**
     * Backward-compatible uploadFile method returning primary object key / URL.
     */
    public String uploadFile(MultipartFile file, String folder) {
        java.util.Map<String, String> res = uploadMediaFile(file, folder);
        return res.get("url");
    }

    /**
     * Generate a pre-signed PUT URL for direct upload from the Flutter app.
     */
    public PresignedUrlResponse generatePresignedUploadUrl(
            String folder, String fileExt, String contentType) {

        String objectKey = folder + "/" + UUID.randomUUID() + "." + fileExt;

        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .contentType(contentType)
                .build();

        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(presignedExpiryMinutes))
                .putObjectRequest(putRequest)
                .build();

        PresignedPutObjectRequest presigned = s3Presigner.presignPutObject(presignRequest);

        String uploadUrl = presigned.url().toString();
        String finalPublicUrl = publicUrl + "/" + objectKey;

        log.debug("Generated presigned URL for key: {}", objectKey);

        return PresignedUrlResponse.builder()
                .uploadUrl(uploadUrl)
                .publicUrl(finalPublicUrl)
                .objectKey(objectKey)
                .expiresInSeconds(presignedExpiryMinutes * 60L)
                .build();
    }

    private static final int MAX_CACHE_SIZE = 5000;
    private final java.util.concurrent.ConcurrentMap<String, CachedPresignedUrl> presignedUrlCache = new java.util.concurrent.ConcurrentHashMap<>();

    private record CachedPresignedUrl(String presignedUrl, java.time.Instant expiresAt) {}

    /**
     * Generate a secure, short-lived presigned GET URL for direct streaming from Cloudflare R2.
     * Uses a thread-safe in-memory TTL cache to eliminate redundant HMAC-SHA256 signature calculations.
     */
    public String generatePresignedGetUrl(String objectKeyOrUrl, Duration duration) {
        if (objectKeyOrUrl == null || objectKeyOrUrl.isBlank()) {
            return null;
        }
        String objectKey = objectKeyOrUrl.trim();
        if (objectKey.startsWith("http://") || objectKey.startsWith("https://")) {
            try {
                java.net.URI uri = java.net.URI.create(objectKey);
                String path = uri.getPath();
                while (path != null && path.startsWith("/")) {
                    path = path.substring(1);
                }
                if (path != null && !path.isBlank()) {
                    objectKey = path;
                }
            } catch (Exception ignored) {}
        }
        while (objectKey.startsWith("/")) {
            objectKey = objectKey.substring(1);
        }

        // Check in-memory cache for valid unexpired signature (at least 30 minutes validity remaining)
        CachedPresignedUrl cached = presignedUrlCache.get(objectKey);
        if (cached != null && java.time.Instant.now().plus(Duration.ofMinutes(30)).isBefore(cached.expiresAt())) {
            return cached.presignedUrl();
        }

        Duration effectiveDuration = duration != null ? duration : Duration.ofHours(4);

        try {
            GetObjectRequest getRequest = GetObjectRequest.builder()
                    .bucket(bucketName)
                    .key(objectKey)
                    .build();

            GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                    .signatureDuration(effectiveDuration)
                    .getObjectRequest(getRequest)
                    .build();

            PresignedGetObjectRequest presigned = s3Presigner.presignGetObject(presignRequest);
            String url = presigned.url().toString();

            // Evict expired entries if cache reaches capacity
            if (presignedUrlCache.size() >= MAX_CACHE_SIZE) {
                java.time.Instant now = java.time.Instant.now();
                presignedUrlCache.entrySet().removeIf(entry -> entry.getValue().expiresAt().isBefore(now));
                if (presignedUrlCache.size() >= MAX_CACHE_SIZE) {
                    presignedUrlCache.clear();
                }
            }

            presignedUrlCache.put(objectKey, new CachedPresignedUrl(url, java.time.Instant.now().plus(effectiveDuration)));
            return url;
        } catch (Exception e) {
            log.warn("Failed to generate presigned GET URL for key '{}': {}", objectKey, e.getMessage());
            return objectKeyOrUrl;
        }
    }

    public static class MediaObject {
        private final byte[] bytes;
        private final boolean isPartial;
        private final String contentRange;
        private final Long contentLength;

        public MediaObject(byte[] bytes, boolean isPartial, String contentRange, Long contentLength) {
            this.bytes = bytes;
            this.isPartial = isPartial;
            this.contentRange = contentRange;
            this.contentLength = contentLength;
        }

        public byte[] getBytes() { return bytes; }
        public boolean isPartial() { return isPartial; }
        public String getContentRange() { return contentRange; }
        public Long getContentLength() { return contentLength; }
    }

    /**
     * Stream object bytes directly from Cloudflare R2 supporting optional HTTP Range headers.
     */
    public software.amazon.awssdk.core.ResponseInputStream<GetObjectResponse> getObjectStream(String objectKey, String rangeHeader) {
        try {
            GetObjectRequest.Builder reqBuilder = GetObjectRequest.builder()
                    .bucket(bucketName)
                    .key(objectKey);

            if (rangeHeader != null && !rangeHeader.isBlank()) {
                reqBuilder.range(rangeHeader.trim());
            }

            return s3Client.getObject(reqBuilder.build());
        } catch (software.amazon.awssdk.services.s3.model.S3Exception e) {
            if (e.statusCode() == 416) {
                throw e;
            }
            // Fallback retry without range header if range was rejected by S3
            if (rangeHeader != null && !rangeHeader.isBlank()) {
                try {
                    GetObjectRequest fallbackReq = GetObjectRequest.builder()
                            .bucket(bucketName)
                            .key(objectKey)
                            .build();
                    return s3Client.getObject(fallbackReq);
                } catch (Exception ignored) {}
            }
            log.error("Failed to retrieve stream for file '{}' (range '{}') from Cloudflare R2: {}", objectKey, rangeHeader, e.getMessage());
            throw BidlyException.notFound("Media file not found: " + objectKey);
        } catch (Exception e) {
            if (rangeHeader != null && !rangeHeader.isBlank()) {
                try {
                    GetObjectRequest fallbackReq = GetObjectRequest.builder()
                            .bucket(bucketName)
                            .key(objectKey)
                            .build();
                    return s3Client.getObject(fallbackReq);
                } catch (Exception ignored) {}
            }
            log.error("Failed to retrieve stream for file '{}' (range '{}') from Cloudflare R2: {}", objectKey, rangeHeader, e.getMessage());
            throw BidlyException.notFound("Media file not found: " + objectKey);
        }
    }

    /**
     * Download object bytes from Cloudflare R2 supporting optional HTTP Range headers.
     */
    public MediaObject getObject(String objectKey, String rangeHeader) {
        try {
            GetObjectRequest.Builder reqBuilder = GetObjectRequest.builder()
                    .bucket(bucketName)
                    .key(objectKey);

            if (rangeHeader != null && !rangeHeader.isBlank()) {
                reqBuilder.range(rangeHeader.trim());
            }

            ResponseBytes<GetObjectResponse> responseBytes = s3Client.getObjectAsBytes(reqBuilder.build());
            GetObjectResponse s3Response = responseBytes.response();

            boolean isPartial = s3Response.contentRange() != null && !s3Response.contentRange().isBlank();
            return new MediaObject(responseBytes.asByteArray(), isPartial, s3Response.contentRange(), s3Response.contentLength());
        } catch (Exception e) {
            log.error("Failed to retrieve file '{}' (range '{}') from Cloudflare R2: {}", objectKey, rangeHeader, e.getMessage());
            throw BidlyException.notFound("Media file not found: " + objectKey);
        }
    }

    /**
     * Download object bytes from Cloudflare R2 using authenticated AWS S3Client.
     */
    public byte[] getObjectBytes(String objectKey) {
        return getObject(objectKey, null).getBytes();
    }

    /**
     * Delete an object from R2 by its key.
     */
    public void deleteObject(String objectKey) {
        s3Client.deleteObject(DeleteObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .build());
        log.debug("Deleted R2 object: {}", objectKey);
    }
}
