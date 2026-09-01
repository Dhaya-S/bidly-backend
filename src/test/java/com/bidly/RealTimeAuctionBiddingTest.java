package com.bidly;

import com.bidly.address.repository.DeliveryAddressRepository;
import com.bidly.auction.dto.AuctionEventDto;
import com.bidly.auction.dto.BidResponseDto;
import com.bidly.auction.dto.PlaceBidRequest;
import com.bidly.auction.entity.Bid;
import com.bidly.auction.repository.BidRepository;
import com.bidly.auction.service.AuctionService;
import com.bidly.common.exception.BidlyException;
import com.bidly.listing.entity.Listing;
import com.bidly.listing.repository.ListingRepository;
import com.bidly.media.service.MediaService;
import com.bidly.order.service.OrderService;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import com.bidly.wallet.service.WalletService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class RealTimeAuctionBiddingTest {

    @Mock
    private ListingRepository listingRepository;

    @Mock
    private BidRepository bidRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private DeliveryAddressRepository addressRepository;

    @Mock
    private WalletService walletService;

    @Mock
    private MediaService mediaService;

    @Mock
    private OrderService orderService;

    @Mock
    private SimpMessagingTemplate messagingTemplate;

    @InjectMocks
    private AuctionService auctionService;

    private UUID listingId;
    private UUID sellerId;
    private UUID userAId;
    private UUID userBId;
    private User seller;
    private User userA;
    private User userB;
    private Listing mockListing;

    @BeforeEach
    void setUp() {
        listingId = UUID.randomUUID();
        sellerId = UUID.randomUUID();
        userAId = UUID.randomUUID();
        userBId = UUID.randomUUID();

        seller = new User();
        seller.setId(sellerId);
        seller.setName("Seller Arun");

        userA = new User();
        userA.setId(userAId);
        userA.setName("Rahul V");

        userB = new User();
        userB.setId(userBId);
        userB.setName("Priya S");

        mockListing = new Listing();
        mockListing.setId(listingId);
        mockListing.setTitle("iPhone 13 Pro 256GB");
        mockListing.setSellingMethod(Listing.SellingMethod.AUCTION);
        mockListing.setStatus(Listing.ListingStatus.ACTIVE);
        mockListing.setStartingBid(BigDecimal.valueOf(40000.00));
        mockListing.setCurrentBid(BigDecimal.valueOf(40000.00));
        mockListing.setBidIncrement(BigDecimal.valueOf(1000.00));
        mockListing.setAuctionEndTime(Instant.now().plusSeconds(7200));
        mockListing.setSeller(seller);
    }

    @Test
    void test1_firstValidBid_successAndWalletReserved() {
        when(listingRepository.findByIdWithPessimisticLock(listingId)).thenReturn(Optional.of(mockListing));
        when(userRepository.findById(userAId)).thenReturn(Optional.of(userA));
        when(walletService.validateAvailableFunds(userAId, BigDecimal.valueOf(41000.00))).thenReturn(true);
        when(bidRepository.findFirstByListingIdAndBidderIdAndStatusOrderByAmountDescCreatedAtDesc(listingId, userAId, Bid.BidStatus.ACTIVE))
                .thenReturn(Optional.empty());
        when(bidRepository.findFirstByListingIdAndStatusOrderByAmountDescCreatedAtDesc(listingId, Bid.BidStatus.ACTIVE))
                .thenReturn(Optional.empty());

        Bid savedBid = new Bid(mockListing, userA, BigDecimal.valueOf(41000.00), null, "uuid-123");
        savedBid.setId(UUID.randomUUID());
        when(bidRepository.save(any(Bid.class))).thenReturn(savedBid);
        when(listingRepository.findById(listingId)).thenReturn(Optional.of(mockListing));

        PlaceBidRequest req = new PlaceBidRequest(BigDecimal.valueOf(41000.00), null, "uuid-123");
        BidResponseDto response = auctionService.placeBid(listingId, userAId, req);

        assertNotNull(response);
        assertEquals(BigDecimal.valueOf(41000.00), response.getBidAmount());
        assertTrue(response.isHighestBidder());
        verify(walletService).reserveFunds(userAId, BigDecimal.valueOf(41000.00), listingId);
        verify(bidRepository).save(any(Bid.class));
    }

    @Test
    void test2_higherBid_outbidsPreviousAndReleasesPreviousFunds() {
        // User A was previous highest bidder at 41000
        Bid previousHighest = new Bid(mockListing, userA, BigDecimal.valueOf(41000.00), null);
        previousHighest.setId(UUID.randomUUID());
        previousHighest.setStatus(Bid.BidStatus.ACTIVE);

        mockListing.setCurrentBid(BigDecimal.valueOf(41000.00));

        when(listingRepository.findByIdWithPessimisticLock(listingId)).thenReturn(Optional.of(mockListing));
        when(userRepository.findById(userBId)).thenReturn(Optional.of(userB));
        when(walletService.validateAvailableFunds(userBId, BigDecimal.valueOf(42000.00))).thenReturn(true);
        when(bidRepository.findFirstByListingIdAndBidderIdAndStatusOrderByAmountDescCreatedAtDesc(listingId, userBId, Bid.BidStatus.ACTIVE))
                .thenReturn(Optional.empty());
        when(bidRepository.findFirstByListingIdAndStatusOrderByAmountDescCreatedAtDesc(listingId, Bid.BidStatus.ACTIVE))
                .thenReturn(Optional.of(previousHighest));

        Bid savedBid = new Bid(mockListing, userB, BigDecimal.valueOf(42000.00), null, "uuid-456");
        savedBid.setId(UUID.randomUUID());
        when(bidRepository.save(any(Bid.class))).thenReturn(savedBid);
        when(listingRepository.findById(listingId)).thenReturn(Optional.of(mockListing));

        PlaceBidRequest req = new PlaceBidRequest(BigDecimal.valueOf(42000.00), null, "uuid-456");
        BidResponseDto response = auctionService.placeBid(listingId, userBId, req);

        assertNotNull(response);
        assertEquals(BigDecimal.valueOf(42000.00), response.getBidAmount());
        // User B's funds reserved
        verify(walletService).reserveFunds(userBId, BigDecimal.valueOf(42000.00), listingId);
        // User A's funds released
        verify(walletService).releaseFunds(eq(userAId), eq(BigDecimal.valueOf(41000.00)), eq(listingId), anyString());
    }

    @Test
    void test3_lowerBid_rejectedWithBadRequest() {
        mockListing.setCurrentBid(BigDecimal.valueOf(45000.00));
        when(listingRepository.findByIdWithPessimisticLock(listingId)).thenReturn(Optional.of(mockListing));
        when(userRepository.findById(userAId)).thenReturn(Optional.of(userA));

        // Attempting to bid 44000 when current is 45000 and increment is 1000 (min valid = 46000)
        PlaceBidRequest req = new PlaceBidRequest(BigDecimal.valueOf(44000.00), null);

        assertThrows(BidlyException.class, () -> auctionService.placeBid(listingId, userAId, req));
        verify(walletService, never()).reserveFunds(any(), any(), any());
    }

    @Test
    void test4_expiredAuction_rejectedWithAuctionEnded() {
        mockListing.setAuctionEndTime(Instant.now().minusSeconds(60)); // Expired 1 min ago
        when(listingRepository.findByIdWithPessimisticLock(listingId)).thenReturn(Optional.of(mockListing));

        PlaceBidRequest req = new PlaceBidRequest(BigDecimal.valueOf(50000.00), null);

        BidlyException ex = assertThrows(BidlyException.class, () -> auctionService.placeBid(listingId, userAId, req));
        assertTrue(ex.getMessage().contains("AUCTION_ENDED") || ex.getMessage().contains("expired"));
        verify(walletService, never()).reserveFunds(any(), any(), any());
    }

    @Test
    void test5_duplicateClientBidId_returnsExistingBidIdempotently() {
        Bid existingBid = new Bid(mockListing, userA, BigDecimal.valueOf(43500.00), null, "client-uuid-999");
        existingBid.setId(UUID.randomUUID());

        when(bidRepository.findByClientBidId("client-uuid-999")).thenReturn(Optional.of(existingBid));
        when(listingRepository.findById(listingId)).thenReturn(Optional.of(mockListing));

        PlaceBidRequest req = new PlaceBidRequest(BigDecimal.valueOf(43500.00), null, "client-uuid-999");
        BidResponseDto response = auctionService.placeBid(listingId, userAId, req);

        assertNotNull(response);
        assertEquals(existingBid.getId(), response.getBidId());
        assertEquals("Bid already processed", response.getMessage());
        // Must NOT attempt to acquire lock or reserve funds a second time
        verify(listingRepository, never()).findByIdWithPessimisticLock(any());
        verify(walletService, never()).reserveFunds(any(), any(), any());
    }

    @Test
    void test6_insufficientWalletFunds_rejected() {
        when(listingRepository.findByIdWithPessimisticLock(listingId)).thenReturn(Optional.of(mockListing));
        when(userRepository.findById(userAId)).thenReturn(Optional.of(userA));
        when(walletService.validateAvailableFunds(userAId, BigDecimal.valueOf(45000.00))).thenReturn(false);

        PlaceBidRequest req = new PlaceBidRequest(BigDecimal.valueOf(45000.00), null);

        assertThrows(BidlyException.class, () -> auctionService.placeBid(listingId, userAId, req));
        verify(bidRepository, never()).save(any(Bid.class));
    }

    @Test
    void test7_withdrawBid_restoresPreviousBidderAndReReservations() {
        // User A was highest at 50,000; User B was second at 48,000 (OUTBID)
        Bid userABid = new Bid(mockListing, userA, BigDecimal.valueOf(50000.00), null);
        userABid.setId(UUID.randomUUID());
        userABid.setStatus(Bid.BidStatus.ACTIVE);

        Bid userBBid = new Bid(mockListing, userB, BigDecimal.valueOf(48000.00), null);
        userBBid.setId(UUID.randomUUID());
        userBBid.setStatus(Bid.BidStatus.OUTBID);

        when(listingRepository.findByIdWithPessimisticLock(listingId)).thenReturn(Optional.of(mockListing));
        when(bidRepository.findFirstByListingIdAndBidderIdAndStatusOrderByAmountDescCreatedAtDesc(listingId, userAId, Bid.BidStatus.ACTIVE))
                .thenReturn(Optional.of(userABid));
        when(bidRepository.findByListingIdAndStatusNotOrderByAmountDescCreatedAtDesc(listingId, Bid.BidStatus.WITHDRAWN))
                .thenReturn(List.of(userBBid));
        when(walletService.validateAvailableFunds(userBId, BigDecimal.valueOf(48000.00))).thenReturn(true);

        auctionService.withdrawBid(listingId, userAId);

        // User A's bid withdrawn & funds released
        assertEquals(Bid.BidStatus.WITHDRAWN, userABid.getStatus());
        verify(walletService).releaseFunds(eq(userAId), eq(BigDecimal.valueOf(50000.00)), eq(listingId), anyString());

        // User B restored as ACTIVE highest bidder & funds reserved
        assertEquals(Bid.BidStatus.ACTIVE, userBBid.getStatus());
        verify(walletService).reserveFunds(userBId, BigDecimal.valueOf(48000.00), listingId);
        assertEquals(BigDecimal.valueOf(48000.00), mockListing.getCurrentBid());
        verify(listingRepository).save(mockListing);
    }

    @Test
    void test8_finalizeAuction_createsOrderAndEscrow() {
        Bid winningBid = new Bid(mockListing, userA, BigDecimal.valueOf(50000.00), null);
        winningBid.setId(UUID.randomUUID());
        winningBid.setStatus(Bid.BidStatus.ACTIVE);

        when(listingRepository.findByIdWithPessimisticLock(listingId)).thenReturn(Optional.of(mockListing));
        when(bidRepository.findFirstByListingIdAndStatusOrderByAmountDescCreatedAtDesc(listingId, Bid.BidStatus.ACTIVE))
                .thenReturn(Optional.of(winningBid));
        when(bidRepository.findByListingIdAndStatus(listingId, Bid.BidStatus.ACTIVE))
                .thenReturn(List.of(winningBid));

        auctionService.finalizeSingleAuction(listingId, true);

        assertEquals(Bid.BidStatus.WON, winningBid.getStatus());
        assertEquals(Listing.ListingStatus.SOLD, mockListing.getStatus());
        verify(orderService).createOrderForWinningBid(mockListing, winningBid);
    }

    @Test
    void test9_broadcastAuctionEvent_sendsStompMessageToIsolatedTopic() {
        when(listingRepository.findById(listingId)).thenReturn(Optional.of(mockListing));

        auctionService.broadcastAuctionEvent(listingId, "BID_PLACED");

        ArgumentCaptor<String> destinationCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object> payloadCaptor = ArgumentCaptor.forClass(Object.class);

        verify(messagingTemplate).convertAndSend(destinationCaptor.capture(), payloadCaptor.capture());
        assertEquals("/topic/auctions/" + listingId, destinationCaptor.getValue());
        assertTrue(payloadCaptor.getValue() instanceof AuctionEventDto);
        AuctionEventDto event = (AuctionEventDto) payloadCaptor.getValue();
        assertEquals("BID_PLACED", event.getEventType());
        assertEquals(listingId, event.getListingId());
    }

    @Test
    void test10_increaseBid_onlyReservesIncrementalDifference() {
        // User A is currently highest bidder with active 40,000 bid.
        Bid prevActiveBid = new Bid(mockListing, userA, BigDecimal.valueOf(40000.00), null);
        prevActiveBid.setId(UUID.randomUUID());
        prevActiveBid.setStatus(Bid.BidStatus.ACTIVE);

        mockListing.setCurrentBid(BigDecimal.valueOf(40000.00));

        when(listingRepository.findByIdWithPessimisticLock(listingId)).thenReturn(Optional.of(mockListing));
        when(userRepository.findById(userAId)).thenReturn(Optional.of(userA));
        // Raising from 40,000 to 45,000: Difference is 5,000
        when(bidRepository.findFirstByListingIdAndBidderIdAndStatusOrderByAmountDescCreatedAtDesc(listingId, userAId, Bid.BidStatus.ACTIVE))
                .thenReturn(Optional.of(prevActiveBid));
        when(walletService.validateAvailableFunds(userAId, BigDecimal.valueOf(5000.00))).thenReturn(true);
        when(bidRepository.findFirstByListingIdAndStatusOrderByAmountDescCreatedAtDesc(listingId, Bid.BidStatus.ACTIVE))
                .thenReturn(Optional.of(prevActiveBid));

        Bid savedNewBid = new Bid(mockListing, userA, BigDecimal.valueOf(45000.00), null, "uuid-inc-1");
        savedNewBid.setId(UUID.randomUUID());
        when(bidRepository.save(any(Bid.class))).thenReturn(savedNewBid);
        when(listingRepository.findById(listingId)).thenReturn(Optional.of(mockListing));

        PlaceBidRequest req = new PlaceBidRequest(BigDecimal.valueOf(45000.00), null, "uuid-inc-1");
        BidResponseDto response = auctionService.placeBid(listingId, userAId, req);

        assertNotNull(response);
        assertEquals(BigDecimal.valueOf(45000.00), response.getBidAmount());
        // Verify ONLY difference of 5,000 was reserved!
        verify(walletService).reserveFunds(userAId, BigDecimal.valueOf(5000.00), listingId);
        // Verify previous funds were NOT released because it's the same user increasing
        verify(walletService, never()).releaseFunds(any(), any(), any(), any());
    }
}
