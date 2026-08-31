package com.bidly.auction.service;

import com.bidly.address.entity.DeliveryAddress;
import com.bidly.address.repository.DeliveryAddressRepository;
import com.bidly.auction.entity.Bid;
import com.bidly.auction.repository.BidRepository;
import com.bidly.listing.entity.Listing;
import com.bidly.listing.repository.ListingRepository;
import com.bidly.order.entity.Order;
import com.bidly.order.service.OrderService;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import com.bidly.wallet.service.WalletService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Service
public class AuctionSeedService {

    private static final Logger log = LoggerFactory.getLogger(AuctionSeedService.class);

    private final ListingRepository listingRepository;
    private final BidRepository bidRepository;
    private final UserRepository userRepository;
    private final DeliveryAddressRepository addressRepository;
    private final WalletService walletService;
    private final OrderService orderService;

    public AuctionSeedService(
            ListingRepository listingRepository,
            BidRepository bidRepository,
            UserRepository userRepository,
            DeliveryAddressRepository addressRepository,
            WalletService walletService,
            OrderService orderService) {
        this.listingRepository = listingRepository;
        this.bidRepository = bidRepository;
        this.userRepository = userRepository;
        this.addressRepository = addressRepository;
        this.walletService = walletService;
        this.orderService = orderService;
    }

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void seedInitialAuctionData() {
        try {
            List<User> users = userRepository.findAll();
            if (users.isEmpty()) return;

            // 1. Ensure each existing user has a wallet and credit initial demo balance if at 0
            for (User u : users) {
                var wallet = walletService.getOrCreateWalletEntity(u.getId());
                if (wallet.getBalance().compareTo(BigDecimal.ZERO) == 0) {
                    walletService.topUpFunds(u.getId(), BigDecimal.valueOf(48000.00), "Initial welcome bidding credit");
                }
                // Also create a default delivery address if none exists
                if (addressRepository.findByUserIdOrderByCreatedAtDesc(u.getId()).isEmpty()) {
                    DeliveryAddress addr = new DeliveryAddress(
                            u,
                            u.getName() != null ? u.getName() : "Verified Buyer",
                            u.getPhone(),
                            "42, Anna Nagar 3rd Street, Flat 4B",
                            u.getCity() != null ? u.getCity() : "Chennai",
                            "600040",
                            true
                    );
                    addressRepository.save(addr);
                }
            }

            // 2. Find any active AUCTION listing or ensure sample auction has bids
            List<Listing> auctionListings = listingRepository.findAll().stream()
                    .filter(l -> l.getSellingMethod() == Listing.SellingMethod.AUCTION)
                    .toList();

            for (Listing listing : auctionListings) {
                if (listing.getAuctionEndTime() == null || Instant.now().isAfter(listing.getAuctionEndTime())) {
                    listing.setAuctionEndTime(Instant.now().plus(Duration.ofHours(2).plusMinutes(14)));
                    listing.setStatus(Listing.ListingStatus.ACTIVE);
                    listingRepository.save(listing);
                }

                if (bidRepository.countByListingId(listing.getId()) == 0) {
                    // Seed realistic bids matching the visual UI reference
                    User seller = listing.getSeller();
                    List<User> otherUsers = users.stream()
                            .filter(u -> !u.getId().equals(seller.getId()))
                            .toList();

                    if (!otherUsers.isEmpty()) {
                        User buyer1 = otherUsers.get(0);
                        User buyer2 = otherUsers.size() > 1 ? otherUsers.get(1) : otherUsers.get(0);

                        BigDecimal start = listing.getStartingBid() != null ? listing.getStartingBid() : BigDecimal.valueOf(30000.00);
                        BigDecimal b1 = start.add(BigDecimal.valueOf(3000));
                        BigDecimal b2 = b1.add(BigDecimal.valueOf(3000));
                        BigDecimal b3 = b2.add(BigDecimal.valueOf(2500));
                        BigDecimal b4 = b3.add(BigDecimal.valueOf(4000)); // e.g. 42500

                        bidRepository.save(new Bid(listing, buyer1, b1, null));
                        bidRepository.save(new Bid(listing, buyer2, b2, null));
                        bidRepository.save(new Bid(listing, buyer1, b3, null));
                        Bid top = bidRepository.save(new Bid(listing, buyer2, b4, null));

                        listing.setCurrentBid(b4);
                        listing.setBidsCount(4);
                        listingRepository.save(listing);

                        log.info("Seeded initial auction bids for listing '{}' (Highest bid: ₹{})", listing.getTitle(), b4);
                    }
                }
            }
        } catch (Exception e) {
            log.warn("Auction seed skipped: {}", e.getMessage());
        }
    }
}
