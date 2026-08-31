package com.bidly.media;

import com.bidly.media.dto.VideoMetadata;
import com.bidly.media.dto.VideoProcessingResult;
import com.bidly.media.service.VideoProcessingService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.File;
import java.io.FileOutputStream;

import static org.junit.jupiter.api.Assertions.*;

class VideoProcessingServiceTest {

    private VideoProcessingService service;

    @BeforeEach
    void setUp() {
        service = new VideoProcessingService();
        ReflectionTestUtils.setField(service, "configuredFfmpegPath", "ffmpeg");
        ReflectionTestUtils.setField(service, "configuredFfprobePath", "ffprobe");
        ReflectionTestUtils.setField(service, "maxDurationSeconds", 60);
        ReflectionTestUtils.setField(service, "maxSizeBytes", 104857600L); // 100 MB
        ReflectionTestUtils.setField(service, "maxConcurrentJobs", 2);
        ReflectionTestUtils.setField(service, "timeoutSeconds", 120);
        service.init();
    }

    @Test
    @DisplayName("Calculate output resolution: 720p portrait remains untouched")
    void testResolutionPortrait720p() {
        int[] res = service.calculateOutputResolution(720, 1280);
        assertEquals(720, res[0]);
        assertEquals(1280, res[1]);
    }

    @Test
    @DisplayName("Calculate output resolution: 1080p portrait remains untouched")
    void testResolutionPortrait1080p() {
        int[] res = service.calculateOutputResolution(1080, 1920);
        assertEquals(1080, res[0]);
        assertEquals(1920, res[1]);
    }

    @Test
    @DisplayName("Calculate output resolution: 4K portrait scales down to 1080x1920")
    void testResolutionPortrait4K() {
        int[] res = service.calculateOutputResolution(2160, 3840);
        assertEquals(1080, res[0]);
        assertEquals(1920, res[1]);
    }

    @Test
    @DisplayName("Calculate output resolution: 4K landscape scales down to 1920x1080")
    void testResolutionLandscape4K() {
        int[] res = service.calculateOutputResolution(3840, 2160);
        assertEquals(1920, res[0]);
        assertEquals(1080, res[1]);
    }

    @Test
    @DisplayName("Calculate output resolution: Small SD video is never upscaled")
    void testResolutionNoUpscale() {
        int[] res = service.calculateOutputResolution(640, 480);
        assertEquals(640, res[0]);
        assertEquals(480, res[1]);
    }

    @Test
    @DisplayName("Calculate output resolution: Enforces even dimensions")
    void testResolutionEvenDimensions() {
        int[] res = service.calculateOutputResolution(721, 1279);
        assertEquals(0, res[0] % 2, "Width must be even");
        assertEquals(0, res[1] % 2, "Height must be even");
    }

    @Test
    @DisplayName("Fast-start atom verification on synthesized MP4")
    void testFastStartVerification() throws Exception {
        // Create synthetic fast-start MP4 using local ffmpeg
        File tempSynthetic = File.createTempFile("synth_test_", ".mp4");
        tempSynthetic.deleteOnExit();

        ProcessBuilder pb = new ProcessBuilder(
                "ffmpeg", "-y",
                "-f", "lavfi", "-i", "testsrc=duration=2:size=320x240:rate=30",
                "-c:v", "libx264", "-pix_fmt", "yuv420p",
                "-movflags", "+faststart",
                tempSynthetic.getAbsolutePath()
        );
        pb.redirectErrorStream(true);
        Process p = pb.start();
        try (var is = p.getInputStream()) {
            is.transferTo(java.io.OutputStream.nullOutputStream());
        }
        int exitCode = p.waitFor();
        if (exitCode == 0 && tempSynthetic.length() > 0) {
            boolean isFastStart = service.verifyFastStart(tempSynthetic);
            assertTrue(isFastStart, "Synthesized MP4 with +faststart should pass fast-start check");

            // Process it through full pipeline
            try (VideoProcessingResult result = service.processFile(tempSynthetic)) {
                assertNotNull(result.getOptimizedVideoFile());
                assertNotNull(result.getThumbnailFile());
                assertTrue(result.getOptimizedVideoFile().exists());
                assertTrue(result.getThumbnailFile().exists());
                assertTrue(result.getThumbnailFile().length() > 0);
                assertTrue(result.isFastStartVerified());
                assertEquals("h264", result.getOutputVideoCodec());
                assertEquals(320, result.getOutputWidth());
                assertEquals(240, result.getOutputHeight());
            }
        }
    }
}
