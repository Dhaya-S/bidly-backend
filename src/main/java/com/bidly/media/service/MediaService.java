package com.bidly.media.service;

import com.bidly.common.exception.BidlyException;
import com.bidly.media.dto.PresignedUrlResponse;
import com.bidly.media.entity.MediaJob;
import com.bidly.media.repository.MediaJobRepository;
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

import java.io.File;
import java.io.IOException;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Handles Cloudflare R2 media operations (both Presigned URL and direct Multipart uploads),
 * with asynchronous background video transcoding for instant user upload responses.
 */
@Service
public class MediaService {

    private static final Logger log = LoggerFactory.getLogger(MediaService.class);

    private final S3Client s3Client;
    private final S3Presigner s3Presigner;
    private final VideoProcessingService videoProcessingService;
    private final AsyncVideoProcessingService asyncVideoProcessingService;
    private final MediaJobRepository mediaJobRepository;

    @Value("${cloudflare.r2.bucket-name}")
    private String bucketName;

    @Value("${cloudflare.r2.public-url}")
    private String publicUrl;

    @Value("${cloudflare.r2.presigned-url-expiry-minutes:15}")
    private int presignedExpiryMinutes;

    @Value("${media.video.max-size-bytes:104857600}")
    private long maxSizeBytes;

    public MediaService(
            S3Client s3Client,
            S3Presigner s3Presigner,
            VideoProcessingService videoProcessingService,
            AsyncVideoProcessingService asyncVideoProcessingService,
            MediaJobRepository mediaJobRepository) {
        this.s3Client = s3Client;
        this.s3Presigner = s3Presigner;
        this.videoProcessingService = videoProcessingService;
        this.asyncVideoProcessingService = asyncVideoProcessingService;
        this.mediaJobRepository = mediaJobRepository;
    }

    /**
     * Upload a MultipartFile directly to Cloudflare R2.
     * - Images: Direct synchronous upload to R2 (taking < 800ms).
     * - Videos (Reels): Immediately validates file, stores safe temporary copy, creates a
     *   MediaJob record, schedules background async transcoding, and returns instant HTTP 200 (< 800ms)
     *   with canonical URL references and status 'PROCESSING'.
     */
    public Map<String, String> uploadMediaFile(MultipartFile file, String folder) {
        if (file == null || file.isEmpty()) {
            throw BidlyException.badRequest("Uploaded file cannot be empty");
        }

        long uploadStartTime = System.currentTimeMillis();
        String originalFilename = file.getOriginalFilename();
        boolean isReelVideo = (folder != null && folder.contains("reels"))
                || (file.getContentType() != null && file.getContentType().startsWith("video/"))
                || isVideoFilename(originalFilename);

        if (!isReelVideo) {
            // Standard image / asset upload directly to R2
            String objectKey = uploadDirectToR2(file, folder);
            long duration = System.currentTimeMillis() - uploadStartTime;
            log.info("[MEDIA_UPLOAD] IMAGE_UPLOAD_COMPLETE key='{}' size={} total_ms={}", objectKey, file.getSize(), duration);

            Map<String, String> result = new HashMap<>();
            result.put("url", objectKey);
            result.put("thumbnailUrl", null);
            result.put("status", "READY");
            result.put("processing", "false");
            return result;
        }

        // --- Asynchronous Reel Video Pipeline ---
        if (file.getSize() > maxSizeBytes) {
            double sizeMb = file.getSize() / (1024.0 * 1024.0);
            double maxMb = maxSizeBytes / (1024.0 * 1024.0);
            throw BidlyException.badRequest(String.format("Video file size (%.1fMB) exceeds maximum limit of %.0fMB", sizeMb, maxMb));
        }

        File tempDir = getTempDirectory();
        String fileId = UUID.randomUUID().toString();
        File sourceTempFile = new File(tempDir, "upload_" + fileId + ".mp4");

        try {
            file.transferTo(sourceTempFile);
        } catch (IOException e) {
            safeDelete(sourceTempFile);
            throw BidlyException.internal("Failed to store temporary upload file: " + e.getMessage());
        }

        String videoKey = (folder != null ? folder : "listings/reels") + "/" + fileId + ".mp4";
        String thumbKey = (folder != null ? folder : "listings/reels") + "/" + fileId + "-thumb.jpg";

        // Save MediaJob with initial PROCESSING status
        MediaJob job = new MediaJob(videoKey, thumbKey, MediaJob.ProcessingStatus.PROCESSING);
        MediaJob savedJob = mediaJobRepository.save(job);

        // Enqueue asynchronous background transcoding on dedicated bounded thread pool
        asyncVideoProcessingService.processVideoAsync(
                savedJob.getId(),
                sourceTempFile,
                videoKey,
                thumbKey,
                bucketName);

        long httpDuration = System.currentTimeMillis() - uploadStartTime;
        log.info("[MEDIA_UPLOAD] QUEUED_ASYNC jobId={} videoKey='{}' size={} http_response_ms={}",
                savedJob.getId(), videoKey, file.getSize(), httpDuration);

        Map<String, String> result = new HashMap<>();
        result.put("url", videoKey);
        result.put("thumbnailUrl", thumbKey);
        result.put("jobId", savedJob.getId().toString());
        result.put("status", "PROCESSING");
        result.put("processing", "true");
        return result;
    }

    /**
     * Retrieves the processing status of a media file.
     */
    public Map<String, String> getJobStatus(String mediaUrl) {
        Map<String, String> res = new HashMap<>();
        if (mediaUrl == null || mediaUrl.isBlank()) {
            res.put("status", "READY");
            return res;
        }

        Optional<MediaJob> job = mediaJobRepository.findFirstByMediaUrlOrderByCreatedAtDesc(mediaUrl.trim());
        if (job.isPresent()) {
            res.put("jobId", job.get().getId().toString());
            res.put("status", job.get().getStatus().name());
            res.put("url", job.get().getMediaUrl());
            res.put("thumbnailUrl", job.get().getThumbnailUrl());
            if (job.get().getErrorMessage() != null) {
                res.put("error", job.get().getErrorMessage());
            }
        } else {
            res.put("status", "READY");
            res.put("url", mediaUrl);
        }
        return res;
    }

    /**
     * Backward-compatible uploadFile method returning primary object key / URL.
     */
    public String uploadFile(MultipartFile file, String folder) {
        Map<String, String> res = uploadMediaFile(file, folder);
        return res.get("url");
    }

    /**
     * Probe a local video File for codec metadata.
     */
    public com.bidly.media.dto.VideoMetadata probeVideo(File file) {
        return videoProcessingService.probeVideo(file);
    }

    /**
     * Process and upload a local video File to R2 (used for legacy media migrations).
     */
    public Map<String, String> processAndUploadLocalVideo(File sourceFile, String folder) {
        try (com.bidly.media.dto.VideoProcessingResult procResult = videoProcessingService.processFile(sourceFile)) {
            String uuid = UUID.randomUUID().toString();
            String videoKey = folder + "/" + uuid + ".mp4";
            String thumbKey = folder + "/" + uuid + "-thumb.jpg";

            File optFile = procResult.getOptimizedVideoFile();
            PutObjectRequest videoPut = PutObjectRequest.builder()
                    .bucket(bucketName)
                    .key(videoKey)
                    .contentType("video/mp4")
                    .contentLength(optFile.length())
                    .build();

            s3Client.putObject(videoPut, RequestBody.fromFile(optFile));

            File thumbFile = procResult.getThumbnailFile();
            String finalThumbKey = null;
            if (thumbFile != null && thumbFile.exists() && thumbFile.length() > 0) {
                PutObjectRequest thumbPut = PutObjectRequest.builder()
                        .bucket(bucketName)
                        .key(thumbKey)
                        .contentType("image/jpeg")
                        .contentLength(thumbFile.length())
                        .build();

                s3Client.putObject(thumbPut, RequestBody.fromFile(thumbFile));
                finalThumbKey = thumbKey;
            }

            Map<String, String> result = new HashMap<>();
            result.put("url", videoKey);
            result.put("thumbnailUrl", finalThumbKey);
            return result;
        } catch (Exception e) {
            log.warn("[R2_MIGRATE] Video migration failed: {}", e.getMessage());
            throw BidlyException.internal("Video migration failed: " + e.getMessage());
        }
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
     * Delete an object from R2 by its key.
     */
    public void deleteObject(String objectKey) {
        s3Client.deleteObject(DeleteObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .build());
        log.debug("Deleted R2 object: {}", objectKey);
    }

    private File getTempDirectory() {
        String tmpDir = System.getProperty("java.io.tmpdir");
        File dir = new File(tmpDir, "bidly_media");
        if (!dir.exists()) {
            dir.mkdirs();
        }
        return dir;
    }

    private void safeDelete(File file) {
        if (file != null && file.exists()) {
            try {
                file.delete();
            } catch (Exception ignored) {}
        }
    }
}
