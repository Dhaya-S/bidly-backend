package com.bidly.media.service;

import com.bidly.listing.entity.Listing;
import com.bidly.listing.repository.ListingRepository;
import com.bidly.media.dto.VideoProcessingResult;
import com.bidly.media.entity.MediaJob;
import com.bidly.media.repository.MediaJobRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.File;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;

/**
 * Asynchronous background worker service for CPU-intensive video processing,
 * thumbnail extraction, R2 uploading, and listing status updates.
 */
@Service
public class AsyncVideoProcessingService {

    private static final Logger log = LoggerFactory.getLogger(AsyncVideoProcessingService.class);

    private final VideoProcessingService videoProcessingService;
    private final MediaJobRepository mediaJobRepository;
    private final ListingRepository listingRepository;
    private final S3Client s3Client;

    public AsyncVideoProcessingService(
            VideoProcessingService videoProcessingService,
            MediaJobRepository mediaJobRepository,
            ListingRepository listingRepository,
            S3Client s3Client) {
        this.videoProcessingService = videoProcessingService;
        this.mediaJobRepository = mediaJobRepository;
        this.listingRepository = listingRepository;
        this.s3Client = s3Client;
    }

    /**
     * Executes video transcoding, poster generation, R2 uploads, and database status updates
     * on the dedicated bounded mediaProcessingExecutor thread pool.
     */
    @Async("mediaProcessingExecutor")
    public CompletableFuture<Void> processVideoAsync(
            UUID jobId,
            File sourceTempFile,
            String videoKey,
            String thumbKey,
            String bucketName) {

        long overallStartTime = System.currentTimeMillis();
        log.info("[MEDIA_PROCESSOR] START jobId={} file={} videoKey='{}'", jobId, sourceTempFile.getName(), videoKey);

        try {
            long procStartTime = System.currentTimeMillis();

            try (VideoProcessingResult procResult = videoProcessingService.processFile(sourceTempFile)) {
                long procDuration = System.currentTimeMillis() - procStartTime;
                log.info("[MEDIA_PROCESSOR] TRANSCODE_SUCCESS jobId={} proc_ms={} outputSize={}",
                        jobId, procDuration, procResult.getOutputFileSize());

                // 1. Upload optimized MP4 to Cloudflare R2
                long r2StartTime = System.currentTimeMillis();
                File optFile = procResult.getOptimizedVideoFile();
                PutObjectRequest videoPut = PutObjectRequest.builder()
                        .bucket(bucketName)
                        .key(videoKey)
                        .contentType("video/mp4")
                        .contentLength(optFile.length())
                        .build();

                s3Client.putObject(videoPut, RequestBody.fromFile(optFile));

                // 2. Upload companion thumbnail poster to Cloudflare R2
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

                long r2Duration = System.currentTimeMillis() - r2StartTime;
                long totalDuration = System.currentTimeMillis() - overallStartTime;

                log.info("[MEDIA_PROCESSOR] R2_UPLOAD_COMPLETE jobId={} r2_ms={} total_ms={} videoKey='{}' thumbKey='{}'",
                        jobId, r2Duration, totalDuration, videoKey, finalThumbKey);

                // 3. Mark MediaJob as READY in database
                updateJobStatus(jobId, MediaJob.ProcessingStatus.READY, null, finalThumbKey);

                // 4. Update any associated Listing to READY
                updateAssociatedListings(videoKey, finalThumbKey, Listing.MediaProcessingStatus.READY);

                log.info("[MEDIA_PROCESSOR] READY jobId={} videoKey='{}'", jobId, videoKey);
            }

        } catch (Exception e) {
            long failDuration = System.currentTimeMillis() - overallStartTime;
            log.error("[MEDIA_PROCESSOR] FAILED jobId={} after {}ms: {}", jobId, failDuration, e.getMessage(), e);

            updateJobStatus(jobId, MediaJob.ProcessingStatus.FAILED, e.getMessage(), null);
            updateAssociatedListings(videoKey, null, Listing.MediaProcessingStatus.FAILED);

        } finally {
            // Guaranteed cleanup of initial temporary upload copy
            safeDelete(sourceTempFile);
            log.info("[MEDIA_PROCESSOR] CLEANUP COMPLETE jobId={}", jobId);
        }

        return CompletableFuture.completedFuture(null);
    }

    @Transactional
    public void updateJobStatus(UUID jobId, MediaJob.ProcessingStatus status, String errorMessage, String thumbnailUrl) {
        if (jobId == null) return;
        try {
            mediaJobRepository.findById(jobId).ifPresent(job -> {
                job.setStatus(status);
                if (errorMessage != null) {
                    job.setErrorMessage(errorMessage);
                }
                if (thumbnailUrl != null) {
                    job.setThumbnailUrl(thumbnailUrl);
                }
                job.setUpdatedAt(Instant.now());
                mediaJobRepository.save(job);
            });
        } catch (Exception e) {
            log.warn("[MEDIA_PROCESSOR] Failed to update media job status: {}", e.getMessage());
        }
    }

    @Transactional
    public void updateAssociatedListings(String videoKey, String thumbKey, Listing.MediaProcessingStatus status) {
        if (videoKey == null || videoKey.isBlank()) return;
        try {
            List<Listing> listings = listingRepository.findAll().stream()
                    .filter(l -> l.getReelUrl() != null && l.getReelUrl().contains(videoKey))
                    .toList();

            for (Listing l : listings) {
                l.setMediaProcessingStatus(status);
                if (thumbKey != null && (l.getPrimaryImageUrl() == null || l.getPrimaryImageUrl().isBlank())) {
                    l.setPrimaryImageUrl(thumbKey);
                }
                listingRepository.save(l);
                log.info("[MEDIA_PROCESSOR] Updated listing '{}' ({}) mediaProcessingStatus -> {}", l.getTitle(), l.getId(), status);
            }
        } catch (Exception e) {
            log.warn("[MEDIA_PROCESSOR] Failed to update associated listings for videoKey '{}': {}", videoKey, e.getMessage());
        }
    }

    private void safeDelete(File file) {
        if (file != null && file.exists()) {
            try {
                file.delete();
            } catch (Exception ignored) {}
        }
    }
}
