package com.bidly.listing.controller;

import com.bidly.common.dto.ApiResponse;
import com.bidly.listing.dto.CreateListingRequest;
import com.bidly.listing.dto.ListingSummaryDto;
import com.bidly.listing.dto.TopSellerDto;
import com.bidly.listing.service.ListingService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/listings")
public class ListingController {

    private final ListingService listingService;

    public ListingController(ListingService listingService) {
        this.listingService = listingService;
    }

    /**
     * POST /api/listings — Create a new product listing (Direct Sale or Auction Bid)
     */
    @PostMapping
    public ResponseEntity<ApiResponse<ListingSummaryDto>> createListing(
            @AuthenticationPrincipal UUID currentUserId,
            @Valid @RequestBody CreateListingRequest request) {
        ListingSummaryDto created = listingService.createListing(currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Listing created successfully", created));
    }

    /**
     * GET /api/listings/reels — Dedicated fast video reels feed for home tab with pagination
     */
    @GetMapping("/reels")
    public ResponseEntity<ApiResponse<List<ListingSummaryDto>>> getReels(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @AuthenticationPrincipal UUID currentUserId) {
        List<ListingSummaryDto> reels = listingService.getActiveReels(currentUserId, page, size);
        return ResponseEntity.ok(ApiResponse.success(reels));
    }

    /**
     * POST /api/listings/reels/migrate — Background admin migration for legacy HEVC/HDR media
     */
    @PostMapping("/reels/migrate")
    public ResponseEntity<ApiResponse<java.util.Map<String, Object>>> migrateReels() {
        java.util.Map<String, Object> report = listingService.migrateLegacyReels();
        return ResponseEntity.ok(ApiResponse.success("Legacy reels migration finished", report));
    }

    /**
     * GET /api/listings/search — Search and filter marketplace products with geospatial search radius
     */
    @GetMapping("/search")
    public ResponseEntity<ApiResponse<List<ListingSummaryDto>>> searchListings(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String method,
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng,
            @RequestParam(required = false) Integer radiusKm,
            @AuthenticationPrincipal UUID currentUserId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        List<ListingSummaryDto> results = listingService.searchListings(
                q, category, method, lat, lng, radiusKm, currentUserId, page, size);
        return ResponseEntity.ok(ApiResponse.success(results));
    }

    /**
     * GET /api/listings/deals-near-you — Prominent horizontal deals cards within user's search radius
     */
    @GetMapping("/deals-near-you")
    public ResponseEntity<ApiResponse<List<ListingSummaryDto>>> getDealsNearYou(
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng,
            @RequestParam(required = false) Integer radiusKm,
            @AuthenticationPrincipal UUID currentUserId) {
        List<ListingSummaryDto> deals = listingService.getDealsNearYou(lat, lng, radiusKm, currentUserId);
        return ResponseEntity.ok(ApiResponse.success(deals));
    }

    /**
     * GET /api/listings/top-sellers — Top community verified sellers
     */
    @GetMapping("/top-sellers")
    public ResponseEntity<ApiResponse<List<TopSellerDto>>> getTopSellers() {
        List<TopSellerDto> sellers = listingService.getTopSellers();
        return ResponseEntity.ok(ApiResponse.success(sellers));
    }

    /**
     * GET /api/listings/recently-viewed — Compact thumbnail row
     */
    @GetMapping("/recently-viewed")
    public ResponseEntity<ApiResponse<List<ListingSummaryDto>>> getRecentlyViewed(
            @AuthenticationPrincipal UUID currentUserId) {
        List<ListingSummaryDto> recent = listingService.getRecentlyViewed(currentUserId);
        return ResponseEntity.ok(ApiResponse.success(recent));
    }

    /**
     * GET /api/listings/{id} — Get listing details by ID
     */
    @GetMapping("/{id:[a-fA-F0-9\\-]{36}}")
    public ResponseEntity<ApiResponse<ListingSummaryDto>> getListingById(
            @PathVariable UUID id,
            @AuthenticationPrincipal UUID currentUserId) {
        ListingSummaryDto listing = listingService.getListingById(id, currentUserId);
        return ResponseEntity.ok(ApiResponse.success(listing));
    }

    /**
     * POST /api/listings/{id}/like — Increment/decrement or ensure likes in real-time
     * Optional param: action = "like" (ensure liked) | "unlike" (ensure unliked) | null (toggle)
     */
    @PostMapping("/{id:[a-fA-F0-9\\-]{36}}/like")
    public ResponseEntity<ApiResponse<ListingSummaryDto>> likeListing(
            @PathVariable UUID id,
            @AuthenticationPrincipal UUID currentUserId,
            @RequestParam(required = false) String action) {
        Boolean desiredLiked = null;
        if ("like".equalsIgnoreCase(action)) {
            desiredLiked = Boolean.TRUE;
        } else if ("unlike".equalsIgnoreCase(action)) {
            desiredLiked = Boolean.FALSE;
        }
    /**
     * GET /api/listings/my — List user's active, sold, and draft listings
     */
    @GetMapping("/my")
    public ResponseEntity<ApiResponse<List<ListingSummaryDto>>> getMyListings(
            @AuthenticationPrincipal UUID currentUserId,
            @RequestParam(required = false) String status) {
        List<ListingSummaryDto> my = listingService.getMyListings(currentUserId, status);
        return ResponseEntity.ok(ApiResponse.success(my));
    }

    /**
     * GET /api/listings/wishlist — List user's saved/wishlisted items
     */
    @GetMapping("/wishlist")
    public ResponseEntity<ApiResponse<List<ListingSummaryDto>>> getWishlist(
            @AuthenticationPrincipal UUID currentUserId) {
        List<ListingSummaryDto> wishlist = listingService.getWishlist(currentUserId);
        return ResponseEntity.ok(ApiResponse.success(wishlist));
    }
}
