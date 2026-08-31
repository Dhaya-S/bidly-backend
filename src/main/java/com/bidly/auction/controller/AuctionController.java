package com.bidly.auction.controller;

import com.bidly.auction.dto.AuctionDetailsDto;
import com.bidly.auction.dto.AuctionLiveStatusDto;
import com.bidly.auction.dto.BidResponseDto;
import com.bidly.auction.dto.PlaceBidRequest;
import com.bidly.auction.service.AuctionService;
import com.bidly.common.dto.ApiResponse;
import com.bidly.wallet.dto.WalletDto;
import com.bidly.wallet.service.WalletService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/auctions")
public class AuctionController {

    private final AuctionService auctionService;
    private final WalletService walletService;

    public AuctionController(AuctionService auctionService, WalletService walletService) {
        this.auctionService = auctionService;
        this.walletService = walletService;
    }

    /**
     * GET /api/auctions/{listingId} — Full auction details, highest bid, specs, seller info & bid history
     */
    @GetMapping("/{listingId}")
    public ResponseEntity<ApiResponse<AuctionDetailsDto>> getAuctionDetails(
            @PathVariable UUID listingId,
            @AuthenticationPrincipal UUID currentUserId) {
        AuctionDetailsDto dto = auctionService.getAuctionDetails(listingId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success(dto));
    }

    /**
     * GET /api/auctions/{listingId}/live-status — Lightweight polling endpoint for live tracker
     */
    @GetMapping("/{listingId}/live-status")
    public ResponseEntity<ApiResponse<AuctionLiveStatusDto>> getLiveStatus(
            @PathVariable UUID listingId,
            @AuthenticationPrincipal UUID currentUserId) {
        AuctionLiveStatusDto dto = auctionService.getLiveStatus(listingId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success(dto));
    }

    /**
     * POST /api/auctions/{listingId}/validate-wallet — Validates user's available funds before placing bid
     */
    @PostMapping("/{listingId}/validate-wallet")
    public ResponseEntity<ApiResponse<Map<String, Object>>> validateWallet(
            @PathVariable UUID listingId,
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody Map<String, Object> body) {
        BigDecimal bidAmount = new BigDecimal(body.getOrDefault("amount", "0").toString());
        WalletDto wallet = walletService.getWallet(currentUserId);
        boolean sufficient = wallet.getAvailableBalance().compareTo(bidAmount) >= 0;

        Map<String, Object> res = new HashMap<>();
        res.put("sufficient", sufficient);
        res.put("walletBalance", wallet.getBalance());
        res.put("availableBalance", wallet.getAvailableBalance());
        res.put("reservedBalance", wallet.getReservedBalance());
        res.put("bidAmount", bidAmount);

        return ResponseEntity.ok(ApiResponse.success(res));
    }

    /**
     * POST /api/auctions/{listingId}/bid — Atomic, concurrency-safe bid placement
     */
    @PostMapping("/{listingId}/bid")
    public ResponseEntity<ApiResponse<BidResponseDto>> placeBid(
            @PathVariable UUID listingId,
            @AuthenticationPrincipal UUID currentUserId,
            @Valid @RequestBody PlaceBidRequest request) {
        BidResponseDto res = auctionService.placeBid(listingId, currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Bid placed successfully", res));
    }

    /**
     * POST /api/auctions/{listingId}/withdraw — Safely withdraws active bid
     */
    @PostMapping("/{listingId}/withdraw")
    public ResponseEntity<ApiResponse<Void>> withdrawBid(
            @PathVariable UUID listingId,
            @AuthenticationPrincipal UUID currentUserId) {
        auctionService.withdrawBid(listingId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Bid withdrawn successfully", null));
    }

    /**
     * POST /api/auctions/{listingId}/finalize — Finalizes single auction and converts winning bid to order & escrow
     */
    @PostMapping("/{listingId}/finalize")
    public ResponseEntity<ApiResponse<Void>> finalizeAuction(
            @PathVariable UUID listingId) {
        auctionService.finalizeSingleAuction(listingId);
        return ResponseEntity.ok(ApiResponse.success("Auction finalized successfully", null));
    }
}
