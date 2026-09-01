package com.bidly;

import com.bidly.listing.dto.ListingSummaryDto;
import com.bidly.listing.entity.Listing;
import com.bidly.listing.repository.ListingLikeRepository;
import com.bidly.listing.repository.ListingRepository;
import com.bidly.listing.service.ListingService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageRequest;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class ReelsDatabasePaginationTest {

    @Mock
    private ListingRepository listingRepository;

    @Mock
    private ListingLikeRepository listingLikeRepository;

    @Mock
    private com.bidly.media.service.MediaService mediaService;

    @InjectMocks
    private ListingService listingService;

    private List<Listing> mockDatabaseReels;

    @BeforeEach
    void setUp() {
        mockDatabaseReels = new ArrayList<>();
        Instant baseTime = Instant.parse("2026-08-31T12:00:00Z");

        for (int i = 0; i < 28; i++) {
            Listing l = new Listing();
            l.setId(UUID.randomUUID());
            l.setTitle("Reel #" + (i + 1));
            l.setReelUrl("listings/reels/test-" + i + ".mp4");
            l.setStatus(Listing.ListingStatus.ACTIVE);
            l.setSellingMethod(i % 2 == 0 ? Listing.SellingMethod.DIRECT_BUY : Listing.SellingMethod.AUCTION);
            l.setCondition(Listing.Condition.LIKE_NEW);
            l.setCreatedAt(baseTime.minusSeconds(i * 60));
            mockDatabaseReels.add(l);
        }
    }

    @Test
    void testPage0_ReturnsFirst10Distinct() {
        List<Listing> page0List = mockDatabaseReels.subList(0, 10);
        when(listingRepository.findActiveReels(eq(Listing.ListingStatus.ACTIVE), eq(PageRequest.of(0, 10))))
                .thenReturn(page0List);

        List<ListingSummaryDto> results = listingService.getActiveReels(null, 0, 10);

        assertEquals(10, results.size());
        assertEquals("Reel #1", results.get(0).getTitle());
        assertEquals("Reel #10", results.get(9).getTitle());
        verify(listingRepository, times(1)).findActiveReels(eq(Listing.ListingStatus.ACTIVE), eq(PageRequest.of(0, 10)));
    }

    @Test
    void testPage1_ReturnsNext10DistinctWithoutDuplicates() {
        List<Listing> page1List = mockDatabaseReels.subList(10, 20);
        when(listingRepository.findActiveReels(eq(Listing.ListingStatus.ACTIVE), eq(PageRequest.of(1, 10))))
                .thenReturn(page1List);

        List<ListingSummaryDto> results = listingService.getActiveReels(null, 1, 10);

        assertEquals(10, results.size());
        assertEquals("Reel #11", results.get(0).getTitle());
        assertEquals("Reel #20", results.get(9).getTitle());
    }

    @Test
    void testPage2_ReturnsRemaining8() {
        List<Listing> page2List = mockDatabaseReels.subList(20, 28);
        when(listingRepository.findActiveReels(eq(Listing.ListingStatus.ACTIVE), eq(PageRequest.of(2, 10))))
                .thenReturn(page2List);

        List<ListingSummaryDto> results = listingService.getActiveReels(null, 2, 10);

        assertEquals(8, results.size());
        assertEquals("Reel #21", results.get(0).getTitle());
        assertEquals("Reel #28", results.get(7).getTitle());
    }

    @Test
    void testPage3_ReturnsEmptyListAtEndOfFeed() {
        when(listingRepository.findActiveReels(eq(Listing.ListingStatus.ACTIVE), eq(PageRequest.of(3, 10))))
                .thenReturn(Collections.emptyList());

        List<ListingSummaryDto> results = listingService.getActiveReels(null, 3, 10);

        assertTrue(results.isEmpty());
    }

    @Test
    void testAccumulatedDistinctIdsAcrossPages() {
        List<Listing> p0 = mockDatabaseReels.subList(0, 10);
        List<Listing> p1 = mockDatabaseReels.subList(10, 20);
        List<Listing> p2 = mockDatabaseReels.subList(20, 28);

        when(listingRepository.findActiveReels(eq(Listing.ListingStatus.ACTIVE), eq(PageRequest.of(0, 10)))).thenReturn(p0);
        when(listingRepository.findActiveReels(eq(Listing.ListingStatus.ACTIVE), eq(PageRequest.of(1, 10)))).thenReturn(p1);
        when(listingRepository.findActiveReels(eq(Listing.ListingStatus.ACTIVE), eq(PageRequest.of(2, 10)))).thenReturn(p2);

        List<ListingSummaryDto> r0 = listingService.getActiveReels(null, 0, 10);
        List<ListingSummaryDto> r1 = listingService.getActiveReels(null, 1, 10);
        List<ListingSummaryDto> r2 = listingService.getActiveReels(null, 2, 10);

        Set<UUID> allIds = new HashSet<>();
        for (ListingSummaryDto d : r0) assertTrue(allIds.add(d.getId()));
        for (ListingSummaryDto d : r1) assertTrue(allIds.add(d.getId()));
        for (ListingSummaryDto d : r2) assertTrue(allIds.add(d.getId()));

        assertEquals(28, allIds.size());
    }
}
