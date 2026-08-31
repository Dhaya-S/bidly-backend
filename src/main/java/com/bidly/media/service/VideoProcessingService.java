package com.bidly.media.service;

import com.bidly.common.exception.BidlyException;
import com.bidly.media.dto.VideoMetadata;
import com.bidly.media.dto.VideoProcessingResult;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;

/**
 * High-performance, source-aware video processing pipeline.
 * Transcodes raw user video uploads into mobile-optimized H.264 MP4 with fast-start metadata
 * and extracts companion poster thumbnails.
 */
@Service
public class VideoProcessingService {

    private static final Logger log = LoggerFactory.getLogger(VideoProcessingService.class);

    @Value("${media.video.ffmpeg-path:ffmpeg}")
    private String configuredFfmpegPath;

    @Value("${media.video.ffprobe-path:ffprobe}")
    private String configuredFfprobePath;

    @Value("${media.video.max-duration-seconds:60}")
    private int maxDurationSeconds;

    @Value("${media.video.max-size-bytes:104857600}")
    private long maxSizeBytes; // 100 MB default

    @Value("${media.video.max-concurrent-jobs:2}")
    private int maxConcurrentJobs;

    @Value("${media.video.timeout-seconds:120}")
    private int timeoutSeconds;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private Semaphore processingSemaphore;
    private String resolvedFfmpegPath;
    private String resolvedFfprobePath;

    @PostConstruct
    public void init() {
        this.processingSemaphore = new Semaphore(Math.max(1, maxConcurrentJobs), true);
        this.resolvedFfmpegPath = resolveExecutable("ffmpeg", configuredFfmpegPath);
        this.resolvedFfprobePath = resolveExecutable("ffprobe", configuredFfprobePath);

        log.info("[VIDEO_PROCESS] Initialized with maxConcurrentJobs={}, maxDuration={}s, maxSize={}MB",
                maxConcurrentJobs, maxDurationSeconds, maxSizeBytes / (1024 * 1024));
        log.info("[VIDEO_PROCESS] Resolved FFmpeg: '{}', FFprobe: '{}'", resolvedFfmpegPath, resolvedFfprobePath);
    }

    /**
     * Process an uploaded MultipartFile into an optimized H.264 MP4 with fast-start and extracted thumbnail.
     * The caller is responsible for closing the returned VideoProcessingResult to clean temporary files.
     */
    public VideoProcessingResult processVideo(MultipartFile multipartFile) {
        if (multipartFile == null || multipartFile.isEmpty()) {
            throw BidlyException.badRequest("Uploaded video file is empty");
        }

        long sourceSize = multipartFile.getSize();
        if (sourceSize > maxSizeBytes) {
            double sizeMb = sourceSize / (1024.0 * 1024.0);
            double maxMb = maxSizeBytes / (1024.0 * 1024.0);
            throw BidlyException.badRequest(String.format("Video file size (%.1fMB) exceeds maximum limit of %.0fMB", sizeMb, maxMb));
        }

        File tempDir = getTempDirectory();
        String fileId = UUID.randomUUID().toString();
        File sourceTempFile = new File(tempDir, "source_" + fileId + ".mp4");
        File outputTempFile = new File(tempDir, "optimized_" + fileId + ".mp4");
        File thumbTempFile = new File(tempDir, "thumb_" + fileId + ".jpg");

        try {
            multipartFile.transferTo(sourceTempFile);
        } catch (IOException e) {
            safeDelete(sourceTempFile);
            throw BidlyException.internal("Failed to store temporary upload file: " + e.getMessage());
        }

        return processFileInternal(sourceTempFile, outputTempFile, thumbTempFile);
    }

    /**
     * Process a local File into an optimized H.264 MP4 with fast-start and extracted thumbnail.
     */
    public VideoProcessingResult processFile(File sourceFile) {
        if (sourceFile == null || !sourceFile.exists() || sourceFile.length() == 0) {
            throw BidlyException.badRequest("Video file does not exist or is empty");
        }

        if (sourceFile.length() > maxSizeBytes) {
            double sizeMb = sourceFile.length() / (1024.0 * 1024.0);
            double maxMb = maxSizeBytes / (1024.0 * 1024.0);
            throw BidlyException.badRequest(String.format("Video file size (%.1fMB) exceeds maximum limit of %.0fMB", sizeMb, maxMb));
        }

        File tempDir = getTempDirectory();
        String fileId = UUID.randomUUID().toString();
        File sourceTempCopy = new File(tempDir, "source_" + fileId + ".mp4");
        File outputTempFile = new File(tempDir, "optimized_" + fileId + ".mp4");
        File thumbTempFile = new File(tempDir, "thumb_" + fileId + ".jpg");

        try {
            Files.copy(sourceFile.toPath(), sourceTempCopy.toPath());
        } catch (IOException e) {
            safeDelete(sourceTempCopy);
            throw BidlyException.internal("Failed to create temporary copy of video: " + e.getMessage());
        }

        return processFileInternal(sourceTempCopy, outputTempFile, thumbTempFile);
    }

    private VideoProcessingResult processFileInternal(File sourceFile, File outputFile, File thumbFile) {
        boolean permitAcquired = false;
        try {
            log.debug("[VIDEO_PROCESS] Waiting for transcoding semaphore permit (available: {})...", processingSemaphore.availablePermits());
            permitAcquired = processingSemaphore.tryAcquire(60, TimeUnit.SECONDS);
            if (!permitAcquired) {
                throw BidlyException.internal("Server video processing queue is busy. Please try again shortly.");
            }

            log.info("[VIDEO_PROCESS] START file={} size={}", sourceFile.getName(), formatBytes(sourceFile.length()));

            // 1. Probe input video metadata
            VideoMetadata srcMeta = probeVideo(sourceFile);
            log.info("[VIDEO_PROCESS] INPUT resolution={}x{} duration={}s vCodec={} aCodec={} bitrate={}kbps",
                    srcMeta.getWidth(), srcMeta.getHeight(), String.format("%.2f", srcMeta.getDurationSeconds()),
                    srcMeta.getVideoCodec(), srcMeta.getAudioCodec(), srcMeta.getBitRate() / 1000);

            // Validate duration
            if (srcMeta.getDurationSeconds() <= 0.0) {
                throw BidlyException.badRequest("Video has invalid or zero duration");
            }
            if (srcMeta.getDurationSeconds() > maxDurationSeconds) {
                throw BidlyException.badRequest(String.format("Video duration (%.1fs) exceeds maximum allowed limit of %d seconds",
                        srcMeta.getDurationSeconds(), maxDurationSeconds));
            }

            // 2. Calculate output resolution
            int[] targetRes = calculateOutputResolution(srcMeta.getWidth(), srcMeta.getHeight());
            int targetWidth = targetRes[0];
            int targetHeight = targetRes[1];
            log.info("[VIDEO_PROCESS] OUTPUT resolution={}x{} (Aspect ratio preserved, max 1080p)", targetWidth, targetHeight);

            // 3. Transcode to fast-start H.264 MP4
            log.info("[VIDEO_PROCESS] FFMPEG START transcoding...");
            long startTime = System.currentTimeMillis();
            transcodeToFastStartH264(sourceFile, outputFile, targetWidth, targetHeight, srcMeta.isHasAudio());
            long transcodeDuration = System.currentTimeMillis() - startTime;
            log.info("[VIDEO_PROCESS] FFMPEG COMPLETE in {}ms, outputSize={}", transcodeDuration, formatBytes(outputFile.length()));

            // 4. Generate thumbnail poster image
            log.info("[VIDEO_PROCESS] THUMBNAIL START generating poster frame...");
            generateThumbnail(outputFile, thumbFile, srcMeta.getDurationSeconds(), targetWidth, targetHeight);
            log.info("[VIDEO_PROCESS] THUMBNAIL COMPLETE thumbSize={}", formatBytes(thumbFile.length()));

            // 5. Verify Fast-Start MP4 structure
            boolean fastStartOk = verifyFastStart(outputFile);
            log.info("[VIDEO_PROCESS] FAST_START verification: {}", fastStartOk ? "PASS" : "FAIL");

            if (!fastStartOk) {
                log.warn("[VIDEO_PROCESS] Warning: fast-start verification did not detect leading moov atom");
            }

            // 6. Build result
            VideoProcessingResult result = new VideoProcessingResult();
            result.setSourceTempFile(sourceFile);
            result.setOptimizedVideoFile(outputFile);
            result.setThumbnailFile(thumbFile);
            result.setSourceMetadata(srcMeta);
            result.setOutputWidth(targetWidth);
            result.setOutputHeight(targetHeight);
            result.setOutputDurationSeconds(srcMeta.getDurationSeconds());
            result.setOutputVideoCodec("h264");
            result.setOutputAudioCodec(srcMeta.isHasAudio() ? "aac" : "none");
            result.setOutputFileSize(outputFile.length());
            result.setFastStartVerified(fastStartOk);

            return result;

        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            cleanupFiles(sourceFile, outputFile, thumbFile);
            throw BidlyException.internal("Video processing was interrupted");
        } catch (BidlyException e) {
            cleanupFiles(sourceFile, outputFile, thumbFile);
            throw e;
        } catch (Exception e) {
            cleanupFiles(sourceFile, outputFile, thumbFile);
            log.error("[VIDEO_PROCESS] Unexpected error during video processing: {}", e.getMessage(), e);
            throw BidlyException.internal("Video processing failed: " + e.getMessage());
        } finally {
            if (permitAcquired) {
                processingSemaphore.release();
            }
        }
    }

    /**
     * Probe a video file using FFprobe to extract technical stream metadata.
     */
    public VideoMetadata probeVideo(File videoFile) {
        ensureExecutablesAvailable();

        List<String> command = new ArrayList<>();
        command.add(resolvedFfprobePath);
        command.add("-v");
        command.add("error");
        command.add("-show_entries");
        command.add("format=duration,size,bit_rate,format_name:stream=index,codec_type,codec_name,width,height,r_frame_rate,bit_rate");
        command.add("-of");
        command.add("json");
        command.add(videoFile.getAbsolutePath());

        String jsonOutput = executeProcess(command, 30, "ffprobe");

        try {
            JsonNode root = objectMapper.readTree(jsonOutput);
            JsonNode streams = root.path("streams");
            JsonNode format = root.path("format");

            if (!streams.isArray() || streams.isEmpty()) {
                throw BidlyException.badRequest("Invalid video: No media streams found in file");
            }

            JsonNode videoStream = null;
            JsonNode audioStream = null;

            for (JsonNode s : streams) {
                String codecType = s.path("codec_type").asText("");
                if ("video".equalsIgnoreCase(codecType) && videoStream == null) {
                    videoStream = s;
                } else if ("audio".equalsIgnoreCase(codecType) && audioStream == null) {
                    audioStream = s;
                }
            }

            if (videoStream == null) {
                throw BidlyException.badRequest("Invalid video: File contains no readable video stream");
            }

            int width = videoStream.path("width").asInt(0);
            int height = videoStream.path("height").asInt(0);
            String vCodec = videoStream.path("codec_name").asText("unknown");

            if (width <= 0 || height <= 0) {
                throw BidlyException.badRequest("Invalid video dimensions: " + width + "x" + height);
            }

            // Duration from format or stream
            double duration = format.path("duration").asDouble(0.0);
            if (duration <= 0.0) {
                duration = videoStream.path("duration").asDouble(0.0);
            }

            // Bitrate
            long bitrate = format.path("bit_rate").asLong(0);
            if (bitrate <= 0) {
                bitrate = videoStream.path("bit_rate").asLong(0);
            }

            // FPS calculation
            double fps = 30.0;
            String rFrameRate = videoStream.path("r_frame_rate").asText("30/1");
            if (rFrameRate.contains("/")) {
                String[] parts = rFrameRate.split("/");
                double num = Double.parseDouble(parts[0]);
                double den = Double.parseDouble(parts[1]);
                if (den > 0) fps = num / den;
            }

            boolean hasAudio = (audioStream != null);
            String aCodec = hasAudio ? audioStream.path("codec_name").asText("none") : "none";
            String containerFormat = format.path("format_name").asText("mp4");

            boolean fastStart = checkFastStartAtom(videoFile);

            return new VideoMetadata(width, height, duration, vCodec, aCodec, bitrate, fps, videoFile.length(), containerFormat, hasAudio, fastStart);

        } catch (BidlyException be) {
            throw be;
        } catch (Exception e) {
            log.error("[VIDEO_PROCESS] Failed to parse ffprobe output: {}", e.getMessage());
            throw BidlyException.badRequest("Corrupted or unreadable video file format");
        }
    }

    /**
     * Calculates the optimal output resolution for mobile streaming:
     * - Never upscales
     * - Preserves exact aspect ratio
     * - Maximum resolution capped at 1080p (1080x1920 for portrait, 1920x1080 for landscape, 1080x1080 for square)
     * - Outputs even dimensions (divisible by 2) required by H.264 encoders
     */
    public int[] calculateOutputResolution(int srcWidth, int srcHeight) {
        if (srcWidth <= 0 || srcHeight <= 0) {
            return new int[]{720, 1280};
        }

        double scaleFactor = 1.0;

        if (srcHeight >= srcWidth) {
            // Portrait or Square: max width 1080, max height 1920
            if (srcWidth > 1080 || srcHeight > 1920) {
                scaleFactor = Math.min(1080.0 / srcWidth, 1920.0 / srcHeight);
            }
        } else {
            // Landscape: max width 1920, max height 1080
            if (srcWidth > 1920 || srcHeight > 1080) {
                scaleFactor = Math.min(1920.0 / srcWidth, 1080.0 / srcHeight);
            }
        }

        int targetW = (int) Math.round(srcWidth * scaleFactor);
        int targetH = (int) Math.round(srcHeight * scaleFactor);

        // Enforce even dimensions
        targetW = (targetW / 2) * 2;
        targetH = (targetH / 2) * 2;

        if (targetW < 2) targetW = 2;
        if (targetH < 2) targetH = 2;

        return new int[]{targetW, targetH};
    }

    /**
     * Transcode source video to H.264 MP4 with fast-start metadata.
     */
    private void transcodeToFastStartH264(File inputFile, File outputFile, int targetW, int targetH, boolean hasAudio) {
        List<String> command = new ArrayList<>();
        command.add(resolvedFfmpegPath);
        command.add("-y");
        command.add("-i");
        command.add(inputFile.getAbsolutePath());

        // Video codec & quality tuning for high-definition mobile streaming
        command.add("-c:v");
        command.add("libx264");
        command.add("-preset");
        command.add("fast");
        command.add("-crf");
        command.add("23");
        command.add("-maxrate");
        command.add("3500k");
        command.add("-bufsize");
        command.add("7000k");
        command.add("-pix_fmt");
        command.add("yuv420p");

        // Scale filter
        command.add("-vf");
        command.add(String.format("scale=%d:%d:flags=lanczos", targetW, targetH));

        // Audio handling
        if (hasAudio) {
            command.add("-c:a");
            command.add("aac");
            command.add("-b:a");
            command.add("128k");
            command.add("-ac");
            command.add("2");
        } else {
            command.add("-an");
        }

        // Fast-start metadata (moov atom at start of file for instant progressive playback)
        command.add("-movflags");
        command.add("+faststart");

        command.add(outputFile.getAbsolutePath());

        executeProcess(command, timeoutSeconds, "ffmpeg");
    }

    /**
     * Extract a high-quality JPEG poster frame from the video.
     */
    private void generateThumbnail(File inputFile, File thumbnailFile, double durationSeconds, int targetW, int targetH) {
        double frameTime = (durationSeconds > 1.0) ? 1.0 : (durationSeconds > 0.1 ? durationSeconds / 2.0 : 0.0);

        List<String> command = new ArrayList<>();
        command.add(resolvedFfmpegPath);
        command.add("-y");
        command.add("-ss");
        command.add(String.format(java.util.Locale.US, "%.3f", frameTime));
        command.add("-i");
        command.add(inputFile.getAbsolutePath());
        command.add("-vframes");
        command.add("1");
        command.add("-vf");
        command.add(String.format("scale=%d:%d", targetW, targetH));
        command.add("-q:v");
        command.add("2");
        command.add("-update");
        command.add("1");
        command.add(thumbnailFile.getAbsolutePath());

        executeProcess(command, 30, "ffmpeg-thumb");
    }

    /**
     * Verifies that the MP4 file has fast-start metadata (the 'moov' atom appears in the leading bytes before 'mdat').
     */
    public boolean verifyFastStart(File mp4File) {
        return checkFastStartAtom(mp4File);
    }

    private boolean checkFastStartAtom(File file) {
        if (file == null || !file.exists() || file.length() < 16) {
            return false;
        }

        try (RandomAccessFile raf = new RandomAccessFile(file, "r")) {
            long length = Math.min(raf.length(), 1048576); // Inspect up to 1MB of header
            byte[] header = new byte[(int) length];
            raf.readFully(header);

            int moovPos = indexOf(header, "moov".getBytes());
            int mdatPos = indexOf(header, "mdat".getBytes());

            if (moovPos != -1) {
                if (mdatPos == -1 || moovPos < mdatPos) {
                    return true;
                }
            }
            return false;
        } catch (Exception e) {
            log.debug("[VIDEO_PROCESS] Error checking fast-start atom: {}", e.getMessage());
            return false;
        }
    }

    private int indexOf(byte[] array, byte[] target) {
        if (target.length == 0) return 0;
        outer:
        for (int i = 0; i < array.length - target.length + 1; i++) {
            for (int j = 0; j < target.length; j++) {
                if (array[i + j] != target[j]) {
                    continue outer;
                }
            }
            return i;
        }
        return -1;
    }

    private String executeProcess(List<String> command, int timeoutSec, String processName) {
        ProcessBuilder pb = new ProcessBuilder(command);
        pb.redirectErrorStream(true);

        StringBuilder output = new StringBuilder();
        Process process = null;

        try {
            process = pb.start();

            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
            }

            boolean finished = process.waitFor(timeoutSec, TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                log.error("[VIDEO_PROCESS] {} timed out after {}s. Terminating process.", processName, timeoutSec);
                throw BidlyException.internal("Video processing timed out after " + timeoutSec + "s");
            }

            int exitCode = process.exitValue();
            if (exitCode != 0) {
                log.error("[VIDEO_PROCESS] {} failed with exit code {}: {}", processName, exitCode, output);
                throw BidlyException.badRequest("Video processing failed: " + processName + " exited with code " + exitCode);
            }

            return output.toString();

        } catch (BidlyException be) {
            throw be;
        } catch (InterruptedException e) {
            if (process != null) process.destroyForcibly();
            Thread.currentThread().interrupt();
            throw BidlyException.internal("Video processing process was interrupted");
        } catch (IOException e) {
            if (process != null) process.destroyForcibly();
            log.error("[VIDEO_PROCESS] IO error executing {}: {}", processName, e.getMessage());
            throw BidlyException.internal("Failed to execute video processor: " + e.getMessage());
        }
    }

    private void ensureExecutablesAvailable() {
        if (resolvedFfmpegPath == null || resolvedFfprobePath == null) {
            resolvedFfmpegPath = resolveExecutable("ffmpeg", configuredFfmpegPath);
            resolvedFfprobePath = resolveExecutable("ffprobe", configuredFfprobePath);
        }
    }

    private String resolveExecutable(String binaryName, String configuredPath) {
        // 1. Configured path
        if (configuredPath != null && !configuredPath.isBlank() && !configuredPath.equalsIgnoreCase(binaryName)) {
            if (testExecutable(configuredPath)) return configuredPath;
        }

        // 2. Environment variable
        String envVar = "ffmpeg".equalsIgnoreCase(binaryName) ? System.getenv("FFMPEG_PATH") : System.getenv("FFPROBE_PATH");
        if (envVar != null && !envVar.isBlank()) {
            if (testExecutable(envVar)) return envVar;
        }

        // 3. System PATH directly
        if (testExecutable(binaryName)) {
            return binaryName;
        }

        // 4. Common Windows / Linux fallback paths
        String[] fallbacks = new String[]{
                System.getProperty("user.home") + "\\AppData\\Local\\Microsoft\\WinGet\\Links\\" + binaryName + ".exe",
                "C:\\Program Files\\ffmpeg\\bin\\" + binaryName + ".exe",
                "C:\\ffmpeg\\bin\\" + binaryName + ".exe",
                "/usr/bin/" + binaryName,
                "/usr/local/bin/" + binaryName
        };

        for (String candidate : fallbacks) {
            File f = new File(candidate);
            if (f.exists() && f.canExecute()) {
                if (testExecutable(candidate)) {
                    return candidate;
                }
            }
        }

        log.warn("[VIDEO_PROCESS] Executable '{}' could not be verified. Defaulting to '{}'", binaryName, binaryName);
        return binaryName;
    }

    private boolean testExecutable(String execPath) {
        try {
            Process process = new ProcessBuilder(execPath, "-version").start();
            boolean finished = process.waitFor(5, TimeUnit.SECONDS);
            if (finished && process.exitValue() == 0) {
                return true;
            }
            process.destroyForcibly();
            return false;
        } catch (Exception e) {
            return false;
        }
    }

    private File getTempDirectory() {
        String tmpDir = System.getProperty("java.io.tmpdir");
        File dir = new File(tmpDir, "bidly_media");
        if (!dir.exists()) {
            dir.mkdirs();
        }
        return dir;
    }

    private void cleanupFiles(File... files) {
        for (File f : files) {
            safeDelete(f);
        }
        log.info("[VIDEO_PROCESS] CLEANUP COMPLETE");
    }

    private void safeDelete(File file) {
        if (file != null && file.exists()) {
            try {
                file.delete();
            } catch (Exception ignored) {}
        }
    }

    private String formatBytes(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        return String.format("%.2f MB", bytes / (1024.0 * 1024.0));
    }
}
