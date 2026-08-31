package com.bidly.auction.service;

import com.bidly.address.entity.DeliveryAddress;
import com.bidly.address.repository.DeliveryAddressRepository;
import com.bidly.auction.dto.*;
import com.bidly.auction.entity.Bid;
import com.bidly.auction.repository.BidRepository;
import com.bidly.common.exception.BidlyException;
import com.bidly.listing.entity.Listing;
import com.bidly.listing.entity.ListingMedia;
import com.bidly.listing.repository.ListingRepository;
import com.bidly.media.service.MediaService;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import com.bidly.wallet.service.WalletService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class AuctionService {

    private static final Logger log = LoggerFactory.getLogger(AuctionService.class);

    private final ListingRepository listingRepository;
    private final BidRepository bidRepository;
    private final UserRepository userRepository;
    private final DeliveryAddressRepository addressRepository;
    private final WalletService walletService;
    private final MediaService mediaService;
    private final com.bidly.order.service.OrderService orderService;

    public AuctionService(
            ListingRepository listingRepository,
            BidRepository bidRepository,
            UserRepository userRepository,
            DeliveryAddressRepository addressRepository,
            WalletService walletService,
            MediaService mediaService,
            com.bidly.order.service.OrderService orderService) {
        this.listingRepository = listingRepository;
        this.bidRepository = bidRepository;
        this.userRepository = userRepository;
        this.addressRepository = addressRepository;
        this.walletService = walletService;
        this.mediaService = mediaService;
        this.orderService = orderService;
    }

    /**
     * Concurrency-safe atomic bid placement using pessimistic row locking.
     */
    @Transactional
    public BidResponseDto placeBid(UUID listingId, UUID currentUserId, PlaceBidRequest req) {
        if (req == null || req.getAmount() == null) {
            throw BidlyException.badRequest("Bid amount is required");
        }

        // 1. Acquire pessimistic write lock on Listing
        Listing listing = listingRepository.findByIdWithPessimisticLock(listingId)
                .orElseThrow(() -> BidlyException.notFound("Auction listing not found: " + listingId));

        // 2. Validate selling method
        if (listing.getSellingMethod() != Listing.SellingMethod.AUCTION) {
            throw BidlyException.badRequest("This listing is a Direct Sale and does not accept auction bids");
        }

        // 3. Validate auction status
        if (listing.getStatus() != Listing.ListingStatus.ACTIVE) {
            throw BidlyException.badRequest("Auction is no longer active (Status: " + listing.getStatus() + ")");
        }

        // 4. Validate auction time
        Instant now = Instant.now();
        if (listing.getAuctionEndTime() != null && now.isAfter(listing.getAuctionEndTime())) {
            throw BidlyException.badRequest("Auction has expired");
        }

        // 5. Validate bidder identity
        User bidder = userRepository.findById(currentUserId)
                .orElseThrow(() -> BidlyException.notFound("Bidder user not found: " + currentUserId));

        if (listing.getSeller() != null && listing.getSeller().getId().equals(currentUserId)) {
            throw BidlyException.badRequest("Sellers cannot bid on their own listings");
        }

        // 6. Validate minimum increment
        BigDecimal startingBid = listing.getStartingBid() != null ? listing.getStartingBid() : listing.getPrice();
        BigDecimal currentBid = listing.getCurrentBid();
        BigDecimal minIncrement = listing.getBidIncrement() != null ? listing.getBidIncrement() : BigDecimal.valueOf(500.00);

        BigDecimal minValidBid = currentBid != null
                ? currentBid.add(minIncrement)
                : startingBid;

        if (req.getAmount().compareTo(minValidBid) < 0) {
            throw BidlyException.badRequest("Bid amount must be at least ₹" + minValidBid.setScale(0, RoundingMode.HALF_UP));
        }

        // 7. Validate & link delivery address if provided
        DeliveryAddress deliveryAddress = null;
        if (req.getDeliveryAddressId() != null) {
            deliveryAddress = addressRepository.findById(req.getDeliveryAddressId()).orElse(null);
        }
        if (deliveryAddress == null) {
            deliveryAddress = addressRepository.findFirstByUserIdAndIsDefaultTrue(currentUserId)
                    .orElseGet(() -> {
                        List<DeliveryAddress> all = addressRepository.findByUserIdOrderByCreatedAtDesc(currentUserId);
                        return all.isEmpty() ? null : all.get(0);
                    });
        }

        // 8. Wallet Funds Reservation with Transaction-Safe Adjustment
        Optional<Bid> prevUserBidOpt = bidRepository.findFirstByListingIdAndBidderIdOrderByAmountDescCreatedAtDesc(listingId, currentUserId);
        BigDecimal amountToReserve = req.getAmount();

        if (prevUserBidOpt.isPresent() && prevUserBidOpt.get().getStatus() == Bid.BidStatus.ACTIVE) {
            // User was previously active highest bidder, only reserve the difference
            BigDecimal previousReserved = prevUserBidOpt.get().getAmount();
            BigDecimal diff = req.getAmount().subtract(previousReserved);
            if (diff.compareTo(BigDecimal.ZERO) > 0) {
                if (!walletService.validateAvailableFunds(currentUserId, diff)) {
                    throw BidlyException.badRequest("Insufficient wallet funds. You need ₹" + diff.setScale(0, RoundingMode.HALF_UP) + " additional balance.");
                }
                walletService.reserveFunds(currentUserId, diff, listingId);
            }
        } else {
            // New bidder on this listing
            if (!walletService.validateAvailableFunds(currentUserId, amountToReserve)) {
                throw BidlyException.badRequest("Insufficient available funds in wallet (Required: ₹" + amountToReserve.setScale(0, RoundingMode.HALF_UP) + ")");
            }
            walletService.reserveFunds(currentUserId, amountToReserve, listingId);
        }

        // 9. Release previous highest bidder's reserved funds if it was a different user
        Optional<Bid> currentHighestBidOpt = bidRepository.findFirstByListingIdOrderByAmountDescCreatedAtDesc(listingId);
        if (currentHighestBidOpt.isPresent()) {
            Bid previousHighest = currentHighestBidOpt.get();
            if (!previousHighest.getBidder().getId().equals(currentUserId) && previousHighest.getStatus() == Bid.BidStatus.ACTIVE) {
                previousHighest.setStatus(Bid.BidStatus.OUTBID);
                bidRepository.save(previousHighest);
                walletService.releaseFunds(
                        previousHighest.getBidder().getId(),
                        previousHighest.getAmount(),
                        listingId,
                        "Outbid by another user on listing: " + listing.getTitle()
                );
            }
        }

        // 10. Mark all older active bids of current user on this listing as outbid
        List<Bid> olderActiveBids = bidRepository.findByListingIdAndStatus(listingId, Bid.BidStatus.ACTIVE);
        for (Bid b : olderActiveBids) {
            if (b.getBidder().getId().equals(currentUserId)) {
                b.setStatus(Bid.BidStatus.OUTBID);
                bidRepository.save(b);
            }
        }

        // 11. Create and persist new Bid
        Bid newBid = new Bid(listing, bidder, req.getAmount(), deliveryAddress);
        newBid.setStatus(Bid.BidStatus.ACTIVE);
        Bid savedBid = bidRepository.save(newBid);

        // 12. Update Listing denormalized cache values atomically
        listing.setCurrentBid(req.getAmount());
        listing.setViewsCount(listing.getViewsCount()); // preserve views
        int newBidsCount = (int) bidRepository.countByListingId(listingId);
        // Note: Listing entity bidsCount property
        listingRepository.save(listing);

        log.info("Placed bid of ₹{} on listing '{}' by user '{}'", req.getAmount(), listingId, currentUserId);

        AuctionDetailsDto details = getAuctionDetails(listingId, currentUserId);

        return new BidResponseDto(
                savedBid.getId(),
                listingId,
                req.getAmount(),
                req.getAmount(),
                newBidsCount,
                true,
                "ACTIVE",
                "Bid placed successfully!",
                details
        );
    }

    /**
     * Get complete auction details matching visual reference.
     */
    @Transactional(readOnly = true)
    public AuctionDetailsDto getAuctionDetails(UUID listingId, UUID currentUserId) {
        Listing listing = listingRepository.findById(listingId)
                .orElseThrow(() -> BidlyException.notFound("Listing not found: " + listingId));

        AuctionDetailsDto dto = new AuctionDetailsDto();
        dto.setListingId(listing.getId());
        dto.setTitle(listing.getTitle());
        dto.setProductCondition(listing.getCondition() != null ? listing.getCondition().name() : "LIKE_NEW");

        String primaryImg = (listing.getMedia() != null && !listing.getMedia().isEmpty())
                ? listing.getMedia().get(0).getUrl() : null;
        dto.setPrimaryImageUrl(mediaService.generatePresignedGetUrl(primaryImg, Duration.ofHours(4)));

        if (listing.getMedia() != null) {
            dto.setImageUrls(listing.getMedia().stream()
                    .map(m -> {
                        String presigned = mediaService.generatePresignedGetUrl(m.getUrl(), Duration.ofHours(4));
                        return presigned != null ? presigned : m.getUrl();
                    })
                    .collect(Collectors.toList()));
        } else {
            dto.setImageUrls(Collections.emptyList());
        }

        BigDecimal startingBid = listing.getStartingBid() != null ? listing.getStartingBid() : listing.getPrice();
        BigDecimal currentBid = listing.getCurrentBid() != null ? listing.getCurrentBid() : startingBid;
        BigDecimal minIncrement = listing.getBidIncrement() != null ? listing.getBidIncrement() : BigDecimal.valueOf(500.00);
        BigDecimal minNextBid = currentBid.add(minIncrement);

        dto.setStartingBid(startingBid);
        dto.setCurrentHighestBid(currentBid);
        dto.setMinNextBid(minNextBid);
        dto.setMinBidIncrement(minIncrement);
        dto.setAuctionEndTime(listing.getAuctionEndTime());

        Instant now = Instant.now();
        long secondsLeft = 0;
        if (listing.getAuctionEndTime() != null) {
            secondsLeft = Math.max(0, Duration.between(now, listing.getAuctionEndTime()).getSeconds());
        } else {
            secondsLeft = 7200; // default 2 hours demo
        }
        dto.setSecondsRemaining(secondsLeft);
        dto.setTimeLeftFormatted(formatSecondsToHuman(secondsLeft));

        int totalBids = (int) bidRepository.countByListingId(listingId);
        dto.setTotalBids(totalBids);
        dto.setWatchingCount(Math.max(12, (int) (listing.getViewsCount() > 0 ? listing.getViewsCount() : 284)));

        dto.setStatus(listing.getStatus().name());
        dto.setAuctionEnded(secondsLeft <= 0 || listing.getStatus() != Listing.ListingStatus.ACTIVE);

        // Highest Bidder Info
        Optional<Bid> highestBidOpt = bidRepository.findFirstByListingIdOrderByAmountDescCreatedAtDesc(listingId);
        if (highestBidOpt.isPresent()) {
            Bid topBid = highestBidOpt.get();
            dto.setHighestBidderId(topBid.getBidder().getId());
            dto.setHighestBidderName(topBid.getBidder().getName() != null ? topBid.getBidder().getName() : "Verified Bidder");
            dto.setHighestBidderTime(getRelativeTime(topBid.getCreatedAt()));
        }

        // Current User Bid Status
        if (currentUserId != null) {
            Optional<Bid> userTopBidOpt = bidRepository.findFirstByListingIdAndBidderIdOrderByAmountDescCreatedAtDesc(listingId, currentUserId);
            if (userTopBidOpt.isPresent()) {
                Bid userBid = userTopBidOpt.get();
                dto.setCurrentUserBid(userBid.getAmount());
                boolean isWinning = highestBidOpt.isPresent() && highestBidOpt.get().getBidder().getId().equals(currentUserId);
                dto.setCurrentUserWinning(isWinning);

                long higherCount = bidRepository.countBidsHigherThan(listingId, userBid.getAmount());
                dto.setCurrentUserRank((int) higherCount + 1);
            } else {
                dto.setCurrentUserWinning(false);
            }
        }

        // Fee calculations (2% platform fee)
        BigDecimal platformFee = minNextBid.multiply(BigDecimal.valueOf(0.02)).setScale(0, RoundingMode.HALF_UP);
        dto.setPlatformFee(platformFee);
        dto.setTotalPayable(minNextBid.add(platformFee));

        // Win Probability / Competitive Strength Metric based on bid level
        dto.setWinProbability(calculateCompetitiveScore(startingBid, currentBid, minNextBid));

        // Seller Details
        if (listing.getSeller() != null) {
            User seller = listing.getSeller();
            dto.setSellerId(seller.getId());
            dto.setSellerName(seller.getName() != null ? seller.getName() : "Verified Seller");
            dto.setSellerRating(listing.getRating() != null ? listing.getRating() : 4.9);
            dto.setSellerReviewsCount(312);
            dto.setSellerSalesCount(48);
        }
        dto.setCity(listing.getCity() != null ? listing.getCity() : "Chennai");
        dto.setState(listing.getState() != null ? listing.getState() : "Tamil Nadu");

        // Bid History (Top 20 bids)
        List<Bid> bids = bidRepository.findByListingIdOrderByAmountDescCreatedAtDesc(listingId);
        List<BidHistoryItemDto> historyItems = new ArrayList<>();
        for (int i = 0; i < Math.min(bids.size(), 20); i++) {
            Bid b = bids.get(i);
            String name = b.getBidder().getName() != null ? b.getBidder().getName() : "Bidder " + (i + 1);
            String initials = getInitials(name);
            boolean isTop = i == 0;
            boolean isUser = currentUserId != null && b.getBidder().getId().equals(currentUserId);

            historyItems.add(new BidHistoryItemDto(
                    b.getId(),
                    b.getBidder().getId(),
                    name,
                    initials,
                    b.getAmount(),
                    b.getCreatedAt(),
                    getRelativeTime(b.getCreatedAt()),
                    isTop,
                    isUser
            ));
        }
        dto.setRecentBids(historyItems);

        return dto;
    }

    /**
     * Lightweight Live Status for 2.5s polling without reloading entire screen.
     */
    @Transactional(readOnly = true)
    public AuctionLiveStatusDto getLiveStatus(UUID listingId, UUID currentUserId) {
        Listing listing = listingRepository.findById(listingId)
                .orElseThrow(() -> BidlyException.notFound("Listing not found: " + listingId));

        AuctionLiveStatusDto dto = new AuctionLiveStatusDto();
        dto.setListingId(listing.getId());

        BigDecimal startingBid = listing.getStartingBid() != null ? listing.getStartingBid() : listing.getPrice();
        BigDecimal currentBid = listing.getCurrentBid() != null ? listing.getCurrentBid() : startingBid;
        BigDecimal minIncrement = listing.getBidIncrement() != null ? listing.getBidIncrement() : BigDecimal.valueOf(500.00);

        dto.setCurrentHighestBid(currentBid);
        dto.setMinNextBid(currentBid.add(minIncrement));
        dto.setTotalBids((int) bidRepository.countByListingId(listingId));
        dto.setWatchingCount(Math.max(12, (int) (listing.getViewsCount() > 0 ? listing.getViewsCount() : 284)));

        Instant now = Instant.now();
        long secondsLeft = 0;
        if (listing.getAuctionEndTime() != null) {
            secondsLeft = Math.max(0, Duration.between(now, listing.getAuctionEndTime()).getSeconds());
        }
        dto.setSecondsRemaining(secondsLeft);
        dto.setTimeLeftFormatted(formatSecondsToHuman(secondsLeft));
        dto.setStatus(listing.getStatus().name());
        dto.setAuctionEnded(secondsLeft <= 0 || listing.getStatus() != Listing.ListingStatus.ACTIVE);

        Optional<Bid> highestBidOpt = bidRepository.findFirstByListingIdOrderByAmountDescCreatedAtDesc(listingId);
        if (highestBidOpt.isPresent()) {
            Bid topBid = highestBidOpt.get();
            dto.setHighestBidderId(topBid.getBidder().getId());
            dto.setHighestBidderName(topBid.getBidder().getName() != null ? topBid.getBidder().getName() : "Verified Bidder");
        }

        if (currentUserId != null) {
            Optional<Bid> userTopBidOpt = bidRepository.findFirstByListingIdAndBidderIdOrderByAmountDescCreatedAtDesc(listingId, currentUserId);
            if (userTopBidOpt.isPresent()) {
                Bid userBid = userTopBidOpt.get();
                dto.setCurrentUserBid(userBid.getAmount());

                boolean isWinning = highestBidOpt.isPresent() && highestBidOpt.get().getBidder().getId().equals(currentUserId);
                dto.setCurrentUserWinning(isWinning);
                dto.setCurrentUserOutbid(!isWinning && currentBid.compareTo(userBid.getAmount()) > 0);

                if (dto.isCurrentUserOutbid()) {
                    dto.setBehindByAmount(currentBid.subtract(userBid.getAmount()));
                }

                long higherCount = bidRepository.countBidsHigherThan(listingId, userBid.getAmount());
                dto.setCurrentUserRank((int) higherCount + 1);
            }
        }

        // Live Feed (Top 5 items)
        List<Bid> bids = bidRepository.findByListingIdOrderByAmountDescCreatedAtDesc(listingId);
        List<BidHistoryItemDto> feed = new ArrayList<>();
        for (int i = 0; i < Math.min(bids.size(), 5); i++) {
            Bid b = bids.get(i);
            String name = b.getBidder().getName() != null ? b.getBidder().getName() : "Bidder " + (i + 1);
            feed.add(new BidHistoryItemDto(
                    b.getId(),
                    b.getBidder().getId(),
                    name,
                    getInitials(name),
                    b.getAmount(),
                    b.getCreatedAt(),
                    getRelativeTime(b.getCreatedAt()),
                    i == 0,
                    currentUserId != null && b.getBidder().getId().equals(currentUserId)
            ));
        }
        dto.setLiveBidFeed(feed);

        return dto;
    }

    /**
     * Safely withdraws user's active bid and releases reserved funds.
     */
    @Transactional
    public void withdrawBid(UUID listingId, UUID currentUserId) {
        Listing listing = listingRepository.findByIdWithPessimisticLock(listingId)
                .orElseThrow(() -> BidlyException.notFound("Auction listing not found: " + listingId));

        if (listing.getStatus() != Listing.ListingStatus.ACTIVE) {
            throw BidlyException.badRequest("Cannot withdraw from an inactive or ended auction");
        }

        Optional<Bid> userBidOpt = bidRepository.findFirstByListingIdAndBidderIdOrderByAmountDescCreatedAtDesc(listingId, currentUserId);
        if (userBidOpt.isEmpty() || userBidOpt.get().getStatus() != Bid.BidStatus.ACTIVE) {
            throw BidlyException.badRequest("You do not have an active bid to withdraw on this auction");
        }

        Bid userBid = userBidOpt.get();
        userBid.setStatus(Bid.BidStatus.WITHDRAWN);
        bidRepository.save(userBid);

        walletService.releaseFunds(
                currentUserId,
                userBid.getAmount(),
                listingId,
                "Withdrew bid from listing: " + listing.getTitle()
        );

        // Re-evaluate current highest bid
        Optional<Bid> nextHighestOpt = bidRepository.findFirstByListingIdOrderByAmountDescCreatedAtDesc(listingId);
        if (nextHighestOpt.isPresent() && nextHighestOpt.get().getStatus() == Bid.BidStatus.ACTIVE) {
            listing.setCurrentBid(nextHighestOpt.get().getAmount());
        } else {
            listing.setCurrentBid(listing.getStartingBid());
        }
        listingRepository.save(listing);

        log.info("User '{}' withdrew bid from listing '{}'", currentUserId, listingId);
    }

    private int calculateCompetitiveScore(BigDecimal starting, BigDecimal current, BigDecimal nextBid) {
        if (starting == null || starting.compareTo(BigDecimal.ZERO) == 0) return 50;
        BigDecimal diff = nextBid.subtract(starting);
        BigDecimal ratio = diff.divide(starting, 4, RoundingMode.HALF_UP);
        int score = (int) (40 + ratio.doubleValue() * 30);
        return Math.min(95, Math.max(15, score));
    }

    private String formatSecondsToHuman(long totalSecs) {
        if (totalSecs <= 0) return "Ended";
        long hours = totalSecs / 3600;
        long mins = (totalSecs % 3600) / 60;
        long secs = totalSecs % 60;
        if (hours > 0) {
            return String.format("%dh %02dm", hours, mins);
        }
        return String.format("%02d:%02d", mins, secs);
    }

    private String getRelativeTime(Instant instant) {
        if (instant == null) return "Just now";
        long secs = Duration.between(instant, Instant.now()).getSeconds();
        if (secs < 60) return "Just now";
        if (secs < 3600) return (secs / 60) + " min ago";
        if (secs < 86400) return (secs / 3600) + " hr ago";
        return (secs / 86400) + " days ago";
    }

    /**
     * Finalizes all expired active auctions idempotently.
     */
    @Transactional
    public void finalizeExpiredAuctions() {
        Instant now = Instant.now();
        List<Listing> expired = listingRepository.findExpiredActiveAuctions(now);
        for (Listing l : expired) {
            try {
                finalizeSingleAuction(l.getId(), false);
            } catch (Exception e) {
                log.warn("Failed to finalize auction {}: {}", l.getId(), e.getMessage());
            }
        }
    }

    /**
     * Finalizes a single auction by selecting the top valid bid,
     * converting reserved funds to escrow, creating the winning order,
     * and marking the listing as SOLD or EXPIRED.
     */
    @Transactional
    public void finalizeSingleAuction(UUID listingId) {
        finalizeSingleAuction(listingId, true);
    }

    @Transactional
    public void finalizeSingleAuction(UUID listingId, boolean force) {
        Listing listing = listingRepository.findByIdWithPessimisticLock(listingId).orElse(null);
        if (listing == null || listing.getStatus() != Listing.ListingStatus.ACTIVE) {
            return;
        }

        Instant now = Instant.now();
        if (!force && (listing.getAuctionEndTime() == null || now.isBefore(listing.getAuctionEndTime()))) {
            return;
        }

        Optional<Bid> winningBidOpt = bidRepository.findFirstByListingIdOrderByAmountDescCreatedAtDesc(listingId);
        if (winningBidOpt.isPresent()) {
            Bid winningBid = winningBidOpt.get();
            winningBid.setStatus(Bid.BidStatus.WON);
            bidRepository.save(winningBid);

            // Mark other active bids as LOST / OUTBID
            List<Bid> allBids = bidRepository.findByListingIdOrderByAmountDescCreatedAtDesc(listingId);
            for (Bid b : allBids) {
                if (!b.getId().equals(winningBid.getId()) && b.getStatus() == Bid.BidStatus.ACTIVE) {
                    b.setStatus(Bid.BidStatus.OUTBID);
                    bidRepository.save(b);
                }
            }

            listing.setStatus(Listing.ListingStatus.SOLD);
            listingRepository.save(listing);

            // Create Order and convert reservation to Escrow
            orderService.createOrderForWinningBid(listing, winningBid);
            log.info("Auction '{}' finalized. Winner: '{}', Amount: Rs.{}", listing.getTitle(), winningBid.getBidder().getName(), winningBid.getAmount());
        } else {
            // No bids placed
            listing.setStatus(Listing.ListingStatus.EXPIRED);
            listingRepository.save(listing);
            log.info("Auction '{}' expired with 0 bids. Marked EXPIRED.", listing.getTitle());
        }
    }

    private String getInitials(String name) {
        if (name == null || name.isBlank()) return "U";
        String[] parts = name.trim().split("\\s+");
        if (parts.length >= 2 && !parts[0].isEmpty() && !parts[1].isEmpty()) {
            return ("" + parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
        }
        return ("" + name.charAt(0)).toUpperCase();
    }
}
