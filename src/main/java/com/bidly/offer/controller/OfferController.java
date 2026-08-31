package com.bidly.offer.controller;

import com.bidly.common.dto.ApiResponse;
import com.bidly.offer.dto.*;
import com.bidly.offer.service.OfferService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping
public class OfferController {

    private final OfferService offerService;

    public OfferController(OfferService offerService) {
        this.offerService = offerService;
    }

    /**
     * POST /api/listings/{listingId}/offers - Submit an offer on a Direct Sale listing
     */
    @PostMapping("/listings/{listingId}/offers")
    public ResponseEntity<ApiResponse<OfferDto>> createOffer(
            @PathVariable UUID listingId,
            @AuthenticationPrincipal UUID currentUserId,
            @Valid @RequestBody CreateOfferRequest request) {
        OfferDto dto = offerService.createOffer(listingId, currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Offer submitted successfully", dto));
    }

    /**
     * GET /api/listings/{listingId}/offers/latest - Retrieve latest offer for listing + user
     */
    @GetMapping("/listings/{listingId}/offers/latest")
    public ResponseEntity<ApiResponse<OfferDto>> getLatestOffer(
            @PathVariable UUID listingId,
            @RequestParam(required = false) UUID buyerId,
            @AuthenticationPrincipal UUID currentUserId) {
        UUID effectiveBuyerId = buyerId != null ? buyerId : currentUserId;
        return offerService.getLatestOffer(listingId, effectiveBuyerId, currentUserId)
                .map(dto -> ResponseEntity.ok(ApiResponse.success(dto)))
                .orElseGet(() -> ResponseEntity.ok(ApiResponse.success(null)));
    }

    /**
     * GET /api/offers/{offerId} - Retrieve offer details
     */
    @GetMapping("/offers/{offerId}")
    public ResponseEntity<ApiResponse<OfferDto>> getOffer(
            @PathVariable UUID offerId,
            @AuthenticationPrincipal UUID currentUserId) {
        OfferDto dto = offerService.getOfferById(offerId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success(dto));
    }

    /**
     * POST /api/offers/{offerId}/counter - Submit a counter-offer
     */
    @PostMapping("/offers/{offerId}/counter")
    public ResponseEntity<ApiResponse<OfferDto>> counterOffer(
            @PathVariable UUID offerId,
            @AuthenticationPrincipal UUID currentUserId,
            @Valid @RequestBody CounterOfferRequest request) {
        OfferDto dto = offerService.counterOffer(offerId, currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Counter-offer submitted successfully", dto));
    }

    /**
     * POST /api/offers/{offerId}/reject - Reject / cancel an offer
     */
    @PostMapping("/offers/{offerId}/reject")
    public ResponseEntity<ApiResponse<OfferDto>> rejectOffer(
            @PathVariable UUID offerId,
            @AuthenticationPrincipal UUID currentUserId) {
        OfferDto dto = offerService.rejectOffer(offerId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Offer rejected", dto));
    }

    /**
     * POST /api/offers/{offerId}/accept - Accept offer and create order
     */
    @PostMapping("/offers/{offerId}/accept")
    public ResponseEntity<ApiResponse<OfferDto>> acceptOffer(
            @PathVariable UUID offerId,
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody(required = false) AcceptOfferRequest request) {
        OfferDto dto = offerService.acceptOffer(offerId, currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Offer accepted and order created", dto));
    }
}
