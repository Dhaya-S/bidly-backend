package com.bidly;

import com.bidly.chat.dto.ChatEventDto;
import com.bidly.chat.dto.ChatMessageDto;
import com.bidly.chat.dto.ChatRoomDto;
import com.bidly.chat.dto.SendMessageRequest;
import com.bidly.chat.entity.ChatMessage;
import com.bidly.chat.entity.ChatRoom;
import com.bidly.chat.repository.ChatMessageRepository;
import com.bidly.chat.repository.ChatRoomRepository;
import com.bidly.chat.service.ChatService;
import com.bidly.common.exception.BidlyException;
import com.bidly.listing.entity.Listing;
import com.bidly.listing.repository.ListingRepository;
import com.bidly.media.service.MediaService;
import com.bidly.offer.dto.AcceptOfferRequest;
import com.bidly.offer.dto.CounterOfferRequest;
import com.bidly.offer.dto.CreateOfferRequest;
import com.bidly.offer.dto.OfferDto;
import com.bidly.offer.entity.Offer;
import com.bidly.offer.repository.OfferRepository;
import com.bidly.offer.service.OfferService;
import com.bidly.order.entity.Order;
import com.bidly.order.service.OrderService;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
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
public class RealTimeChatTest {

    @Mock
    private ChatRoomRepository roomRepo;

    @Mock
    private ChatMessageRepository messageRepo;

    @Mock
    private ListingRepository listingRepo;

    @Mock
    private UserRepository userRepo;

    @Mock
    private MediaService mediaService;

    @Mock
    private SimpMessagingTemplate messagingTemplate;

    @Mock
    private OfferRepository offerRepo;

    @Mock
    private OrderService orderService;

    @InjectMocks
    private ChatService chatService;

    @InjectMocks
    private OfferService offerService;

    private UUID roomId;
    private UUID listingId;
    private UUID buyerId;
    private UUID sellerId;
    private UUID strangerId;
    private User buyer;
    private User seller;
    private ChatRoom mockRoom;
    private Listing mockListing;

    @BeforeEach
    void setUp() {
        roomId = UUID.randomUUID();
        listingId = UUID.randomUUID();
        buyerId = UUID.randomUUID();
        sellerId = UUID.randomUUID();
        strangerId = UUID.randomUUID();

        buyer = new User();
        buyer.setId(buyerId);
        buyer.setName("Rahul V");

        seller = new User();
        seller.setId(sellerId);
        seller.setName("Tech Deals Chennai");

        mockListing = new Listing();
        mockListing.setId(listingId);
        mockListing.setTitle("iPhone 13 Pro 256GB");
        mockListing.setPrice(BigDecimal.valueOf(43500.00));
        mockListing.setSellingMethod(Listing.SellingMethod.DIRECT_BUY);
        mockListing.setStatus(Listing.ListingStatus.ACTIVE);
        mockListing.setSeller(seller);

        mockRoom = new ChatRoom();
        mockRoom.setId(roomId);
        mockRoom.setListingId(listingId);
        mockRoom.setBuyerId(buyerId);
        mockRoom.setSellerId(sellerId);
        mockRoom.setStatus(ChatRoom.ChatRoomStatus.OPEN);
        mockRoom.setCreatedAt(Instant.now());
    }

    @Test
    void test1_sendMessage_persistedAndBroadcasts() {
        when(roomRepo.findById(roomId)).thenReturn(Optional.of(mockRoom));

        ChatMessage saved = new ChatMessage();
        saved.setId(UUID.randomUUID());
        saved.setRoomId(roomId);
        saved.setSenderId(buyerId);
        saved.setClientMessageId("uuid-msg-101");
        saved.setContent("Is this item still available?");
        saved.setType(ChatMessage.MessageType.TEXT);
        saved.setStatus(ChatMessage.MessageStatus.SENT);
        saved.setCreatedAt(Instant.now());

        when(messageRepo.findByRoomIdAndClientMessageId(roomId, "uuid-msg-101")).thenReturn(Optional.empty());
        when(messageRepo.save(any(ChatMessage.class))).thenReturn(saved);
        when(userRepo.findById(buyerId)).thenReturn(Optional.of(buyer));

        SendMessageRequest req = new SendMessageRequest("uuid-msg-101", "Is this item still available?", "TEXT");
        ChatMessageDto result = chatService.sendMessage(roomId, buyerId, req);

        assertNotNull(result);
        assertEquals("Is this item still available?", result.getContent());
        assertEquals("uuid-msg-101", result.getClientMessageId());
        verify(messageRepo).save(any(ChatMessage.class));
        verify(roomRepo).save(mockRoom);
    }

    @Test
    void test2_sendMessage_idempotentDuplicateClientMessageId() {
        when(roomRepo.findById(roomId)).thenReturn(Optional.of(mockRoom));

        ChatMessage existing = new ChatMessage();
        existing.setId(UUID.randomUUID());
        existing.setRoomId(roomId);
        existing.setSenderId(buyerId);
        existing.setClientMessageId("uuid-msg-dup-1");
        existing.setContent("Duplicate message test");
        existing.setType(ChatMessage.MessageType.TEXT);
        existing.setStatus(ChatMessage.MessageStatus.SENT);
        existing.setCreatedAt(Instant.now());

        when(messageRepo.findByRoomIdAndClientMessageId(roomId, "uuid-msg-dup-1")).thenReturn(Optional.of(existing));

        SendMessageRequest req = new SendMessageRequest("uuid-msg-dup-1", "Duplicate message test", "TEXT");
        ChatMessageDto result = chatService.sendMessage(roomId, buyerId, req);

        assertNotNull(result);
        assertEquals(existing.getId(), result.getId());
        // Must not call save again
        verify(messageRepo, never()).save(any(ChatMessage.class));
    }

    @Test
    void test3_markAsRead_updatesStatusAndBroadcastsReadReceipt() {
        when(roomRepo.findById(roomId)).thenReturn(Optional.of(mockRoom));

        ChatMessage unreadMsg = new ChatMessage();
        unreadMsg.setId(UUID.randomUUID());
        unreadMsg.setRoomId(roomId);
        unreadMsg.setSenderId(sellerId);
        unreadMsg.setStatus(ChatMessage.MessageStatus.SENT);

        when(messageRepo.findUnreadMessagesInRoom(roomId, buyerId)).thenReturn(List.of(unreadMsg));

        chatService.markRoomMessagesAsRead(roomId, buyerId);

        assertEquals(ChatMessage.MessageStatus.READ, unreadMsg.getStatus());
        assertNotNull(unreadMsg.getReadAt());
        verify(messageRepo).saveAll(anyList());
    }

    @Test
    void test4_unauthorizedAccess_rejectedWithForbidden() {
        when(roomRepo.findById(roomId)).thenReturn(Optional.of(mockRoom));

        SendMessageRequest req = new SendMessageRequest("uuid-stranger", "Hello", "TEXT");

        assertThrows(BidlyException.class, () -> chatService.sendMessage(roomId, strangerId, req));
        verify(messageRepo, never()).save(any());
    }

    @Test
    void test5_createOffer_insertsChatMessageAndBroadcastsOffer() {
        when(listingRepo.findById(listingId)).thenReturn(Optional.of(mockListing));
        when(userRepo.findById(buyerId)).thenReturn(Optional.of(buyer));

        Offer offer = new Offer(mockListing, buyer, seller, BigDecimal.valueOf(42000.00), "Offer test");
        offer.setId(UUID.randomUUID());
        when(offerRepo.save(any(Offer.class))).thenReturn(offer);
        when(roomRepo.findByListingIdAndBuyerId(listingId, buyerId)).thenReturn(Optional.of(mockRoom));

        ChatMessage msg = new ChatMessage();
        msg.setId(UUID.randomUUID());
        msg.setRoomId(roomId);
        msg.setSenderId(buyerId);
        msg.setType(ChatMessage.MessageType.OFFER);
        msg.setOfferAmount(BigDecimal.valueOf(42000.00));
        msg.setStatus(ChatMessage.MessageStatus.SENT);
        when(chatMessageRepository().save(any(ChatMessage.class))).thenReturn(msg);

        CreateOfferRequest req = new CreateOfferRequest(BigDecimal.valueOf(42000.00), "Offer test");
        OfferDto result = offerService.createOffer(listingId, buyerId, req);

        assertNotNull(result);
        assertEquals(BigDecimal.valueOf(42000.00), result.getAmount());
        verify(chatMessageRepository()).save(any(ChatMessage.class));
        verify(roomRepo).save(mockRoom);
    }

    @Test
    void test6_sendTypingIndicator_broadcastsEphemeralEvent() {
        when(roomRepo.findById(roomId)).thenReturn(Optional.of(mockRoom));
        when(userRepo.findById(buyerId)).thenReturn(Optional.of(buyer));

        chatService.sendTypingIndicator(roomId, buyerId, true);

        ArgumentCaptor<String> destCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object> payloadCaptor = ArgumentCaptor.forClass(Object.class);

        verify(messagingTemplate).convertAndSend(destCaptor.capture(), payloadCaptor.capture());
        assertEquals("/topic/chats/" + roomId, destCaptor.getValue());
        assertTrue(payloadCaptor.getValue() instanceof ChatEventDto);
        ChatEventDto event = (ChatEventDto) payloadCaptor.getValue();
        assertEquals("TYPING_STARTED", event.getEventType());
        assertEquals("Rahul V", event.getUserName());
    }

    @Test
    void test7_counterOffer_updatesOfferAndBroadcastsCounteredEvent() {
        Offer offer = new Offer(mockListing, buyer, seller, BigDecimal.valueOf(40000.00), "Initial offer");
        offer.setId(UUID.randomUUID());
        offer.setStatus(Offer.OfferStatus.PENDING);

        when(offerRepo.findByIdWithPessimisticLock(offer.getId())).thenReturn(Optional.of(offer));
        when(offerRepo.save(any(Offer.class))).thenReturn(offer);
        when(roomRepo.findByListingIdAndBuyerId(listingId, buyerId)).thenReturn(Optional.of(mockRoom));

        ChatMessage msg = new ChatMessage();
        msg.setId(UUID.randomUUID());
        msg.setRoomId(roomId);
        msg.setSenderId(sellerId);
        msg.setType(ChatMessage.MessageType.OFFER_COUNTERED);
        msg.setOfferAmount(BigDecimal.valueOf(42000.00));
        msg.setStatus(ChatMessage.MessageStatus.SENT);
        when(messageRepo.save(any(ChatMessage.class))).thenReturn(msg);
        when(userRepo.findById(sellerId)).thenReturn(Optional.of(seller));

        CounterOfferRequest req = new CounterOfferRequest(BigDecimal.valueOf(42000.00), "How about 42k?");
        OfferDto result = offerService.counterOffer(offer.getId(), sellerId, req);

        assertNotNull(result);
        assertEquals(Offer.OfferStatus.COUNTERED.name(), result.getStatus());
        assertEquals(BigDecimal.valueOf(42000.00), result.getCounterAmount());
        verify(offerRepo).save(offer);
        verify(messageRepo).save(any(ChatMessage.class));
    }

    @Test
    void test8_acceptOffer_marksListingSoldAndCreatesOrder() {
        Offer offer = new Offer(mockListing, buyer, seller, BigDecimal.valueOf(42000.00), "Accepted offer");
        offer.setId(UUID.randomUUID());
        offer.setStatus(Offer.OfferStatus.PENDING);

        Order mockOrder = new Order();
        mockOrder.setId(UUID.randomUUID());
        mockOrder.setOrderNumber("ORD-2026-9999");

        when(offerRepo.findByIdWithPessimisticLock(offer.getId())).thenReturn(Optional.of(offer));
        when(listingRepo.findByIdWithPessimisticLock(listingId)).thenReturn(Optional.of(mockListing));
        when(offerRepo.save(any(Offer.class))).thenReturn(offer);
        when(listingRepo.save(any(Listing.class))).thenReturn(mockListing);
        when(orderService.createOrderForAcceptedOffer(eq(mockListing), eq(offer), any())).thenReturn(mockOrder);
        when(offerRepo.findByListingIdAndStatus(listingId, Offer.OfferStatus.PENDING)).thenReturn(List.of(offer));
        when(roomRepo.findByListingIdAndBuyerId(listingId, buyerId)).thenReturn(Optional.of(mockRoom));

        ChatMessage msg = new ChatMessage();
        msg.setId(UUID.randomUUID());
        msg.setRoomId(roomId);
        msg.setSenderId(sellerId);
        msg.setType(ChatMessage.MessageType.OFFER_ACCEPTED);
        msg.setStatus(ChatMessage.MessageStatus.SENT);
        when(messageRepo.save(any(ChatMessage.class))).thenReturn(msg);
        when(userRepo.findById(sellerId)).thenReturn(Optional.of(seller));

        AcceptOfferRequest req = new AcceptOfferRequest();
        req.setDeliveryType("IN_PERSON_MEETUP");
        req.setMeetupLocation("Phoenix Marketcity, Velachery");

        OfferDto result = offerService.acceptOffer(offer.getId(), sellerId, req);

        assertNotNull(result);
        assertEquals(Offer.OfferStatus.ACCEPTED.name(), result.getStatus());
        assertEquals(mockOrder.getId(), result.getOrderId());
        assertEquals(Listing.ListingStatus.SOLD, mockListing.getStatus());
        verify(orderService).createOrderForAcceptedOffer(mockListing, offer, req);
    }

    @Test
    void test9_rejectOffer_marksRejectedAndBroadcasts() {
        Offer offer = new Offer(mockListing, buyer, seller, BigDecimal.valueOf(35000.00), "Low offer");
        offer.setId(UUID.randomUUID());
        offer.setStatus(Offer.OfferStatus.PENDING);

        when(offerRepo.findByIdWithPessimisticLock(offer.getId())).thenReturn(Optional.of(offer));
        when(offerRepo.save(any(Offer.class))).thenReturn(offer);
        when(roomRepo.findByListingIdAndBuyerId(listingId, buyerId)).thenReturn(Optional.of(mockRoom));

        ChatMessage msg = new ChatMessage();
        msg.setId(UUID.randomUUID());
        msg.setRoomId(roomId);
        msg.setSenderId(sellerId);
        msg.setType(ChatMessage.MessageType.OFFER_REJECTED);
        msg.setStatus(ChatMessage.MessageStatus.SENT);
        when(messageRepo.save(any(ChatMessage.class))).thenReturn(msg);
        when(userRepo.findById(sellerId)).thenReturn(Optional.of(seller));

        OfferDto result = offerService.rejectOffer(offer.getId(), sellerId);

        assertNotNull(result);
        assertEquals(Offer.OfferStatus.REJECTED.name(), result.getStatus());
        verify(offerRepo).save(offer);
    }

    private ChatMessageRepository chatMessageRepository() {
        return messageRepo;
    }
}

