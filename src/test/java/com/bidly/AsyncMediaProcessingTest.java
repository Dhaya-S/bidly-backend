package com.bidly;

import com.bidly.common.exception.BidlyException;
import com.bidly.category.entity.Category;
import com.bidly.category.repository.CategoryRepository;
import com.bidly.listing.dto.CreateListingRequest;
import com.bidly.listing.dto.ListingSummaryDto;
import com.bidly.listing.entity.Listing;
import com.bidly.listing.repository.ListingMediaRepository;
import com.bidly.listing.repository.ListingRepository;
import com.bidly.listing.service.ListingService;
import com.bidly.media.dto.VideoMetadata;
import com.bidly.media.dto.VideoProcessingResult;
import com.bidly.media.entity.MediaJob;
import com.bidly.media.repository.MediaJobRepository;
import com.bidly.media.service.AsyncVideoProcessingService;
import com.bidly.media.service.MediaService;
import com.bidly.media.service.VideoProcessingService;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.File;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.CompletableFuture;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class AsyncMediaProcessingTest {

    @Mock
    private S3Client s3Client;

    @Mock
    private VideoProcessingService videoProcessingService;

    @Mock
    private AsyncVideoProcessingService asyncVideoProcessingService;

    @Mock
    private MediaJobRepository mediaJobRepository;

    @Mock
    private ListingRepository listingRepository;

    @Mock
    private ListingMediaRepository mediaRepository;

    @Mock
    private CategoryRepository categoryRepository;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private MediaService mediaService;

    private ListingService listingService;

    private User testUser;
    private Category testCategory;

    @BeforeEach
    void setUp() {
        testUser = new User();
        testUser.setId(UUID.randomUUID());
        testUser.setName("Dhaya");
        testUser.setPhone("9876543210");
        testUser.setTrustScore(90);

        testCategory = new Category("Electronics", null, 1, null, true);
        testCategory.setId(UUID.randomUUID());

        listingService = new ListingService(
                listingRepository,
                mediaRepository,
                null,
                categoryRepository,
                userRepository,
                null,
                null,
                mediaService,
                mediaJobRepository
        );
    }

    @Test
    void test1_imageUpload_synchronousFastReturnReady() {
        MockMultipartFile imageFile = new MockMultipartFile(
                "file", "photo.jpg", "image/jpeg", new byte[1024]);

        Map<String, String> result = mediaService.uploadMediaFile(imageFile, "listings/photos");

        assertNotNull(result);
        assertNotNull(result.get("url"));
        assertTrue(result.get("url").startsWith("listings/photos/"));
        assertEquals("READY", result.get("status"));
        assertEquals("false", result.get("processing"));
        assertNull(result.get("thumbnailUrl"));

        verify(s3Client).putObject(any(PutObjectRequest.class), any(software.amazon.awssdk.core.sync.RequestBody.class));
        verifyNoInteractions(asyncVideoProcessingService);
    }

    @Test
    void test2_videoUpload_asynchronousFastReturnProcessing() {
        MockMultipartFile videoFile = new MockMultipartFile(
                "file", "reel.mp4", "video/mp4", new byte[2048]);

        MediaJob mockJob = new MediaJob("listings/reels/test.mp4", "listings/reels/test-thumb.jpg", MediaJob.ProcessingStatus.PROCESSING);
        mockJob.setId(UUID.randomUUID());
        when(mediaJobRepository.save(any(MediaJob.class))).thenReturn(mockJob);

        Map<String, String> result = mediaService.uploadMediaFile(videoFile, "listings/reels");

        assertNotNull(result);
        assertEquals("PROCESSING", result.get("status"));
        assertEquals("true", result.get("processing"));
        assertNotNull(result.get("url"));
        assertNotNull(result.get("thumbnailUrl"));
        assertEquals(mockJob.getId().toString(), result.get("jobId"));

        // Verify async video processing was scheduled
        verify(asyncVideoProcessingService).processVideoAsync(
                eq(mockJob.getId()), any(File.class), anyString(), anyString(), any());
    }

    @Test
    void test3_emptyUpload_rejectedBadRequest() {
        MockMultipartFile emptyFile = new MockMultipartFile(
                "file", "empty.mp4", "video/mp4", new byte[0]);

        assertThrows(BidlyException.class, () -> mediaService.uploadMediaFile(emptyFile, "listings/reels"));
    }

    @Test
    void test4_getJobStatus_returnsCorrectStatus() {
        MediaJob mockJob = new MediaJob("listings/reels/123.mp4", "listings/reels/123-thumb.jpg", MediaJob.ProcessingStatus.READY);
        mockJob.setId(UUID.randomUUID());
        when(mediaJobRepository.findFirstByMediaUrlOrderByCreatedAtDesc("listings/reels/123.mp4"))
                .thenReturn(Optional.of(mockJob));

        Map<String, String> status = mediaService.getJobStatus("listings/reels/123.mp4");

        assertNotNull(status);
        assertEquals("READY", status.get("status"));
        assertEquals("listings/reels/123.mp4", status.get("url"));
        assertEquals("listings/reels/123-thumb.jpg", status.get("thumbnailUrl"));
    }

    @Test
    void test5_listingCreation_withProcessingVideo_setsMediaProcessingStatusProcessing() {
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(categoryRepository.findFirstByNameIgnoreCase("Electronics")).thenReturn(Optional.of(testCategory));

        MediaJob processingJob = new MediaJob("listings/reels/proc.mp4", "listings/reels/proc-thumb.jpg", MediaJob.ProcessingStatus.PROCESSING);
        when(mediaJobRepository.findFirstByMediaUrlOrderByCreatedAtDesc("listings/reels/proc.mp4"))
                .thenReturn(Optional.of(processingJob));

        when(listingRepository.save(any(Listing.class))).thenAnswer(invocation -> {
            Listing l = invocation.getArgument(0);
            l.setId(UUID.randomUUID());
            return l;
        });

        CreateListingRequest req = new CreateListingRequest();
        req.setTitle("iPhone 13 Pro");
        req.setDescription("Excellent phone");
        req.setPrice(BigDecimal.valueOf(43500));
        req.setCategory("Electronics");
        req.setReelUrl("listings/reels/proc.mp4");
        req.setMediaUrls(List.of("listings/reels/proc-thumb.jpg"));

        ListingSummaryDto created = listingService.createListing(testUser.getId(), req);

        assertNotNull(created);
        verify(listingRepository).save(argThat(l -> l.getMediaProcessingStatus() == Listing.MediaProcessingStatus.PROCESSING));
    }

    @Test
    void test6_listingCreation_withCompletedVideo_setsMediaProcessingStatusReady() {
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(categoryRepository.findFirstByNameIgnoreCase("Electronics")).thenReturn(Optional.of(testCategory));

        MediaJob readyJob = new MediaJob("listings/reels/ready.mp4", "listings/reels/ready-thumb.jpg", MediaJob.ProcessingStatus.READY);
        when(mediaJobRepository.findFirstByMediaUrlOrderByCreatedAtDesc("listings/reels/ready.mp4"))
                .thenReturn(Optional.of(readyJob));

        when(listingRepository.save(any(Listing.class))).thenAnswer(invocation -> {
            Listing l = invocation.getArgument(0);
            l.setId(UUID.randomUUID());
            return l;
        });

        CreateListingRequest req = new CreateListingRequest();
        req.setTitle("iPhone 13 Pro");
        req.setDescription("Excellent phone");
        req.setPrice(BigDecimal.valueOf(43500));
        req.setCategory("Electronics");
        req.setReelUrl("listings/reels/ready.mp4");
        req.setMediaUrls(List.of("listings/reels/ready-thumb.jpg"));

        ListingSummaryDto created = listingService.createListing(testUser.getId(), req);

        assertNotNull(created);
        verify(listingRepository).save(argThat(l -> l.getMediaProcessingStatus() == Listing.MediaProcessingStatus.READY));
    }

    @Test
    void test7_asyncProcessingWorker_transcodesAndUpdatesJobToReady() throws Exception {
        AsyncVideoProcessingService worker = new AsyncVideoProcessingService(
                videoProcessingService,
                mediaJobRepository,
                listingRepository,
                s3Client
        );

        UUID jobId = UUID.randomUUID();
        MediaJob job = new MediaJob("listings/reels/test.mp4", "listings/reels/test-thumb.jpg", MediaJob.ProcessingStatus.PROCESSING);
        job.setId(jobId);
        when(mediaJobRepository.findById(jobId)).thenReturn(Optional.of(job));

        File mockSource = File.createTempFile("mock_src", ".mp4");
        File mockOpt = File.createTempFile("mock_opt", ".mp4");
        File mockThumb = File.createTempFile("mock_thumb", ".jpg");

        VideoProcessingResult mockResult = new VideoProcessingResult();
        mockResult.setOptimizedVideoFile(mockOpt);
        mockResult.setThumbnailFile(mockThumb);
        mockResult.setOutputFileSize(1024L);
        mockResult.setSourceMetadata(new VideoMetadata(1080, 1920, 15.0, "h264", "aac", 2500000, 30.0, 1024L, "mp4", true, true));

        when(videoProcessingService.processFile(any(File.class))).thenReturn(mockResult);

        CompletableFuture<Void> future = worker.processVideoAsync(
                jobId,
                mockSource,
                "listings/reels/test.mp4",
                "listings/reels/test-thumb.jpg",
                "bidly-media"
        );

        future.get(); // wait for completion

        assertEquals(MediaJob.ProcessingStatus.READY, job.getStatus());
        verify(mediaJobRepository).save(job);
        verify(s3Client, times(2)).putObject(any(PutObjectRequest.class), any(software.amazon.awssdk.core.sync.RequestBody.class));

        mockOpt.delete();
        mockThumb.delete();
    }
}
