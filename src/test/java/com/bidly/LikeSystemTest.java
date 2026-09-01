package com.bidly;

import com.bidly.community.entity.CommunityPost;
import com.bidly.community.entity.PostLike;
import com.bidly.community.repository.CommunityPostRepository;
import com.bidly.community.repository.PostLikeRepository;
import com.bidly.community.service.CommunityPostService;
import com.bidly.listing.entity.Listing;
import com.bidly.listing.entity.ListingLike;
import com.bidly.listing.repository.ListingLikeRepository;
import com.bidly.listing.repository.ListingRepository;
import com.bidly.listing.service.ListingService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class LikeSystemTest {

    @Mock
    private CommunityPostRepository postRepository;

    @Mock
    private PostLikeRepository postLikeRepository;

    @Mock
    private com.bidly.media.service.MediaService mediaService;

    @InjectMocks
    private CommunityPostService postService;

    @Mock
    private ListingRepository listingRepository;

    @Mock
    private ListingLikeRepository listingLikeRepository;

    @InjectMocks
    private ListingService listingService;

    private UUID userA;
    private UUID userB;
    private UUID postId;
    private UUID listingId;
    private CommunityPost mockPost;
    private Listing mockListing;

    @BeforeEach
    void setUp() {
        userA = UUID.randomUUID();
        userB = UUID.randomUUID();
        postId = UUID.randomUUID();
        listingId = UUID.randomUUID();

        mockPost = new CommunityPost();
        mockPost.setId(postId);
        mockPost.setContent("Test Post");
        mockPost.setLikesCount(0);

        mockListing = new Listing();
        mockListing.setId(listingId);
        mockListing.setTitle("Test Reel");
        mockListing.setLikesCount(0);
    }

    // ─── 1. POST LIKE ───────────────────────────────────────────
    @Test
    void testPostLike_IncrementsCount() {
        when(postRepository.findById(postId)).thenReturn(Optional.of(mockPost));
        when(postLikeRepository.existsByUserIdAndPostId(userA, postId)).thenReturn(false).thenReturn(true);

        Map<String, Object> result = postService.toggleLike(userA, postId, "like");

        assertEquals(true, result.get("liked"));
        assertEquals(1, result.get("likesCount"));
        assertEquals(1, mockPost.getLikesCount());
        verify(postLikeRepository, times(1)).save(any(PostLike.class));
        verify(postRepository, times(1)).saveAndFlush(mockPost);
    }

    // ─── 2. POST DUPLICATE LIKE (IDEMPOTENCY) ───────────────────
    @Test
    void testPostDuplicateLike_NoDuplicateIncrement() {
        mockPost.setLikesCount(1);
        when(postRepository.findById(postId)).thenReturn(Optional.of(mockPost));
        when(postLikeRepository.existsByUserIdAndPostId(userA, postId)).thenReturn(true);

        Map<String, Object> result = postService.toggleLike(userA, postId, "like");

        assertEquals(true, result.get("liked"));
        assertEquals(1, result.get("likesCount"));
        assertEquals(1, mockPost.getLikesCount());
        verify(postLikeRepository, never()).save(any(PostLike.class));
    }

    // ─── 3. POST UNLIKE ─────────────────────────────────────────
    @Test
    void testPostUnlike_DecrementsCount() {
        mockPost.setLikesCount(1);
        when(postRepository.findById(postId)).thenReturn(Optional.of(mockPost));
        when(postLikeRepository.existsByUserIdAndPostId(userA, postId)).thenReturn(true).thenReturn(false);

        Map<String, Object> result = postService.toggleLike(userA, postId, "unlike");

        assertEquals(false, result.get("liked"));
        assertEquals(0, result.get("likesCount"));
        assertEquals(0, mockPost.getLikesCount());
        verify(postLikeRepository, times(1)).deleteByUserIdAndPostId(userA, postId);
        verify(postRepository, times(1)).saveAndFlush(mockPost);
    }

    // ─── 4. POST DUPLICATE UNLIKE (IDEMPOTENCY) ─────────────────
    @Test
    void testPostDuplicateUnlike_StaysZero() {
        mockPost.setLikesCount(0);
        when(postRepository.findById(postId)).thenReturn(Optional.of(mockPost));
        when(postLikeRepository.existsByUserIdAndPostId(userA, postId)).thenReturn(false);

        Map<String, Object> result = postService.toggleLike(userA, postId, "unlike");

        assertEquals(false, result.get("liked"));
        assertEquals(0, result.get("likesCount"));
        assertEquals(0, mockPost.getLikesCount());
        verify(postLikeRepository, never()).deleteByUserIdAndPostId(any(), any());
    }

    // ─── 5. REEL LIKE ───────────────────────────────────────────
    @Test
    void testReelLike_IncrementsCount() {
        when(listingRepository.findById(listingId)).thenReturn(Optional.of(mockListing));
        when(listingLikeRepository.existsByUserIdAndListingId(userA, listingId)).thenReturn(false).thenReturn(true);

        Map<String, Object> result = listingService.toggleLikeListingWithAction(userA, listingId, "like");

        assertEquals(true, result.get("liked"));
        assertEquals(1, result.get("likesCount"));
        assertEquals(1, mockListing.getLikesCount());
        verify(listingLikeRepository, times(1)).save(any(ListingLike.class));
        verify(listingRepository, times(1)).saveAndFlush(mockListing);
    }

    // ─── 6. REEL DUPLICATE LIKE (IDEMPOTENCY) ───────────────────
    @Test
    void testReelDuplicateLike_NoDuplicateIncrement() {
        mockListing.setLikesCount(1);
        when(listingRepository.findById(listingId)).thenReturn(Optional.of(mockListing));
        when(listingLikeRepository.existsByUserIdAndListingId(userA, listingId)).thenReturn(true);

        Map<String, Object> result = listingService.toggleLikeListingWithAction(userA, listingId, "like");

        assertEquals(true, result.get("liked"));
        assertEquals(1, result.get("likesCount"));
        assertEquals(1, mockListing.getLikesCount());
        verify(listingLikeRepository, never()).save(any(ListingLike.class));
    }

    // ─── 7. REEL UNLIKE ─────────────────────────────────────────
    @Test
    void testReelUnlike_DecrementsCount() {
        mockListing.setLikesCount(1);
        when(listingRepository.findById(listingId)).thenReturn(Optional.of(mockListing));
        when(listingLikeRepository.existsByUserIdAndListingId(userA, listingId)).thenReturn(true).thenReturn(false);

        Map<String, Object> result = listingService.toggleLikeListingWithAction(userA, listingId, "unlike");

        assertEquals(false, result.get("liked"));
        assertEquals(0, result.get("likesCount"));
        assertEquals(0, mockListing.getLikesCount());
        verify(listingLikeRepository, times(1)).deleteByUserIdAndListingId(userA, listingId);
        verify(listingRepository, times(1)).saveAndFlush(mockListing);
    }

    // ─── 8. REEL DUPLICATE UNLIKE (IDEMPOTENCY) ─────────────────
    @Test
    void testReelDuplicateUnlike_StaysZero() {
        mockListing.setLikesCount(0);
        when(listingRepository.findById(listingId)).thenReturn(Optional.of(mockListing));
        when(listingLikeRepository.existsByUserIdAndListingId(userA, listingId)).thenReturn(false);

        Map<String, Object> result = listingService.toggleLikeListingWithAction(userA, listingId, "unlike");

        assertEquals(false, result.get("liked"));
        assertEquals(0, result.get("likesCount"));
        assertEquals(0, mockListing.getLikesCount());
        verify(listingLikeRepository, never()).deleteByUserIdAndListingId(any(), any());
    }

    // ─── 9. USER A & USER B ISOLATION ───────────────────────────
    @Test
    void testUserIsolation_BothUsersLiked() {
        // User A likes
        when(postRepository.findById(postId)).thenReturn(Optional.of(mockPost));
        when(postLikeRepository.existsByUserIdAndPostId(userA, postId)).thenReturn(false).thenReturn(true);
        Map<String, Object> resA = postService.toggleLike(userA, postId, "like");
        assertEquals(true, resA.get("liked"));
        assertEquals(1, resA.get("likesCount"));

        // User B likes
        when(postLikeRepository.existsByUserIdAndPostId(userB, postId)).thenReturn(false).thenReturn(true);
        Map<String, Object> resB = postService.toggleLike(userB, postId, "like");
        assertEquals(true, resB.get("liked"));
        assertEquals(2, resB.get("likesCount"));
        assertEquals(2, mockPost.getLikesCount());
    }
}
