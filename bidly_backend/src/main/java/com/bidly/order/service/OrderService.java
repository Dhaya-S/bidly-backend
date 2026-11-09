package com.bidly.order.service;

import com.bidly.auction.entity.Bid;
import com.bidly.common.exception.BidlyException;
import com.bidly.listing.entity.Listing;
import com.bidly.media.service.MediaService;
import com.bidly.order.dto.OrderSummaryDto;
import com.bidly.order.dto.OrderTrackingEventDto;
import com.bidly.order.entity.Order;
import com.bidly.order.entity.OrderTrackingEvent;
import com.bidly.order.repository.OrderRepository;
import com.bidly.order.repository.OrderTrackingEventRepository;
import com.bidly.user.entity.User;
import com.bidly.wallet.service.WalletService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class OrderService {

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(OrderService.class);

    private final OrderRepository orderRepository;
    private final OrderTrackingEventRepository trackingEventRepository;
    private final WalletService walletService;
    private final MediaService mediaService;
    private final com.bidly.address.repository.DeliveryAddressRepository addressRepository;
    private final com.bidly.listing.repository.ListingRepository listingRepository;
    private final com.bidly.notification.service.NotificationService notificationService;
    private final com.bidly.chat.repository.ChatRoomRepository chatRoomRepository;
    private final com.bidly.chat.repository.ChatMessageRepository chatMessageRepository;
    private final org.springframework.messaging.simp.SimpMessagingTemplate messagingTemplate;

    public OrderService(
            OrderRepository orderRepository,
            OrderTrackingEventRepository trackingEventRepository,
            WalletService walletService,
            MediaService mediaService,
            com.bidly.address.repository.DeliveryAddressRepository addressRepository,
            com.bidly.listing.repository.ListingRepository listingRepository,
            com.bidly.notification.service.NotificationService notificationService,
            com.bidly.chat.repository.ChatRoomRepository chatRoomRepository,
            com.bidly.chat.repository.ChatMessageRepository chatMessageRepository,
            org.springframework.messaging.simp.SimpMessagingTemplate messagingTemplate) {
        this.orderRepository = orderRepository;
        this.trackingEventRepository = trackingEventRepository;
        this.walletService = walletService;
        this.mediaService = mediaService;
        this.addressRepository = addressRepository;
        this.listingRepository = listingRepository;
        this.notificationService = notificationService;
        this.chatRoomRepository = chatRoomRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.messagingTemplate = messagingTemplate;
    }

    /**
     * Creates an Order when a Direct Sale offer is accepted.
     */
    @Transactional
    public Order createOrderForAcceptedOffer(Listing listing, com.bidly.offer.entity.Offer offer, com.bidly.offer.dto.AcceptOfferRequest req) {
        Optional<Order> existing = orderRepository.findByOfferId(offer.getId());
        if (existing.isPresent()) {
            return existing.get();
        }

        String orderNum = "ORD-2026-" + String.format("%05d", new Random().nextInt(90000) + 10000);
        BigDecimal agreedAmount = offer.getCounterAmount() != null ? offer.getCounterAmount() : offer.getAmount();
        BigDecimal platformFee = agreedAmount.multiply(BigDecimal.valueOf(0.02)).setScale(0, RoundingMode.HALF_UP);
        BigDecimal totalAmount = agreedAmount.add(platformFee);

        Order.DeliveryType deliveryType = "IN_PERSON_MEETUP".equalsIgnoreCase(req != null ? req.getDeliveryType() : "COURIER")
                ? Order.DeliveryType.IN_PERSON_MEETUP
                : Order.DeliveryType.COURIER;

        com.bidly.address.entity.DeliveryAddress address = null;
        if (req != null && req.getAddressId() != null) {
            address = addressRepository.findById(req.getAddressId()).orElse(null);
        }

        Order order = new Order();
        order.setOrderNumber(orderNum);
        order.setListing(listing);
        order.setBuyer(offer.getBuyer());
        order.setSeller(offer.getSeller());
        order.setOffer(offer);
        order.setOrderSource(Order.OrderSource.DIRECT_SALE);
        order.setDeliveryType(deliveryType);
        order.setDeliveryAddress(address);
        order.setAmount(agreedAmount);
        order.setPlatformFee(platformFee);
        order.setTotalAmount(totalAmount);
        order.setPaymentStatus(deliveryType == Order.DeliveryType.IN_PERSON_MEETUP ? Order.PaymentStatus.PENDING : Order.PaymentStatus.IN_ESCROW);

        if (deliveryType == Order.DeliveryType.IN_PERSON_MEETUP) {
            String secureOtp = String.format("%06d", new java.security.SecureRandom().nextInt(900000) + 100000);
            order.setMeetupOtp(secureOtp);
            order.setMeetupOtpVerified(false);
            order.setMeetupLocation(req != null && req.getMeetupLocation() != null && !req.getMeetupLocation().isBlank()
                    ? req.getMeetupLocation()
                    : (listing.getLocality() != null ? listing.getLocality() : "Agreed Public Meeting Point"));
            order.setMeetupTime(req != null && req.getMeetupTime() != null
                    ? req.getMeetupTime()
                    : Instant.now().plus(Duration.ofHours(24)));
            order.setStatus(Order.OrderStatus.ORDER_CONFIRMED);
            order.setIsMeetupConfirmed(false);
            order.setClientActionId(null);

            Order saved = orderRepository.save(order);
            trackingEventRepository.save(new OrderTrackingEvent(saved, Order.OrderStatus.ORDER_CONFIRMED, "Offer Accepted & Meetup Scheduled", "In-person meetup confirmed at " + saved.getMeetupLocation(), Instant.now()));
            return saved;
        } else {
            order.setDeliveryType(Order.DeliveryType.COURIER);
            order.setCourierPartner(null);
            order.setTrackingNumber(null);
            order.setEstimatedDeliveryDate(null);
            order.setStatus(Order.OrderStatus.ORDER_CONFIRMED);

            Order saved = orderRepository.save(order);
            trackingEventRepository.save(new OrderTrackingEvent(saved, Order.OrderStatus.ORDER_CONFIRMED, "Offer Accepted", "Direct Sale offer agreed for Rs. " + agreedAmount, Instant.now()));
            return saved;
        }
    }

    /**
     * Schedules or reschedules an in-person meetup for an order.
     */
    @Transactional
    public OrderSummaryDto scheduleMeetup(UUID orderId, UUID currentUserId, com.bidly.order.dto.ScheduleMeetupRequest req) {
        Order order = orderRepository.findByIdWithPessimisticLock(orderId)
                .orElseThrow(() -> BidlyException.notFound("Order not found: " + orderId));

        boolean isSeller = order.getSeller().getId().equals(currentUserId);
        boolean isBuyer = order.getBuyer().getId().equals(currentUserId);
        if (!isSeller && !isBuyer) {
            throw BidlyException.forbidden("Only the buyer or seller can schedule meetup for this order");
        }

        if (order.getStatus() == Order.OrderStatus.DELIVERED || order.getStatus() == Order.OrderStatus.CANCELLED) {
            throw BidlyException.badRequest("Cannot reschedule meetup for an order that is " + order.getStatus());
        }

        Instant meetupInstant = req.getMeetupTime();
        if (meetupInstant == null && req.getDateString() != null) {
            try {
                meetupInstant = Instant.now().plus(Duration.ofDays(1));
            } catch (Exception ignored) {}
        }
        if (meetupInstant == null) {
            meetupInstant = Instant.now().plus(Duration.ofDays(1));
        }

        order.setDeliveryType(Order.DeliveryType.IN_PERSON_MEETUP);
        order.setMeetupLocation(req.getLocation().trim());
        order.setMeetupTime(meetupInstant);
        if (req.getNotes() != null) {
            order.setMeetupNotes(req.getNotes().trim());
        }
        order.setIsMeetupConfirmed(false);
        if (req.getClientActionId() != null && !req.getClientActionId().isBlank()) {
            order.setClientActionId(req.getClientActionId().trim());
        } else {
            order.setClientActionId(null);
        }

        if (order.getMeetupOtp() == null || order.getMeetupOtp().isBlank()) {
            String secureOtp = String.format("%06d", new java.security.SecureRandom().nextInt(900000) + 100000);
            order.setMeetupOtp(secureOtp);
            order.setMeetupOtpVerified(false);
            order.setOtpExpiresAt(Instant.now().plus(Duration.ofHours(48)));
            order.setOtpAttemptCount(0);
        }

        order.setStatus(Order.OrderStatus.ORDER_CONFIRMED);
        Order saved = orderRepository.save(order);

        // Record tracking event
        trackingEventRepository.save(new OrderTrackingEvent(saved, Order.OrderStatus.ORDER_CONFIRMED, "Meetup Scheduled", "In-person meetup confirmed at " + saved.getMeetupLocation(), Instant.now()));

        DateTimeFormatter dtf = DateTimeFormatter.ofPattern("dd/MM/yy").withZone(ZoneId.of("Asia/Kolkata"));
        DateTimeFormatter ttf = DateTimeFormatter.ofPattern("hh:mma").withZone(ZoneId.of("Asia/Kolkata"));
        String dateFormatted = dtf.format(meetupInstant);
        String timeFormatted = ttf.format(meetupInstant);

        // Post structured message to Chat Room
        chatRoomRepository.findByListingIdAndBuyerId(saved.getListing().getId(), saved.getBuyer().getId()).ifPresent(room -> {
            com.bidly.chat.entity.ChatMessage msg = new com.bidly.chat.entity.ChatMessage();
            msg.setRoomId(room.getId());
            msg.setSenderId(currentUserId);
            msg.setType(com.bidly.chat.entity.ChatMessage.MessageType.MEETUP_REQUEST);
            msg.setStatus(com.bidly.chat.entity.ChatMessage.MessageStatus.SENT);
            msg.setContent("Meeting Scheduled\nDate: " + dateFormatted + "\nTime: " + timeFormatted + "\nLocation: " + saved.getMeetupLocation());
            msg.setMetadata(String.format("{\"date\":\"%s\",\"time\":\"%s\",\"location\":\"%s\",\"orderId\":\"%s\"}",
                    dateFormatted, timeFormatted, saved.getMeetupLocation(), saved.getId()));
            com.bidly.chat.entity.ChatMessage savedMsg = chatMessageRepository.save(msg);
            room.setLastMessageAt(Instant.now());
            room.setUpdatedAt(Instant.now());
            chatRoomRepository.save(room);

            // Broadcast to room
            Map<String, Object> eventData = new HashMap<>();
            eventData.put("eventType", "MEETUP_SCHEDULED");
            eventData.put("orderId", saved.getId());
            eventData.put("date", dateFormatted);
            eventData.put("time", timeFormatted);
            eventData.put("location", saved.getMeetupLocation());
            eventData.put("messageId", savedMsg.getId());
            messagingTemplate.convertAndSend("/topic/chats/" + room.getId(), (Object) eventData);
        });

        // Send persistent notification & real-time alert to the other party
        String metadataJson = String.format(
                "{\"orderId\":\"%s\",\"date\":\"%s\",\"time\":\"%s\",\"location\":\"%s\",\"buyerId\":\"%s\",\"offerId\":\"%s\",\"buyerName\":\"%s\"}",
                saved.getId(), dateFormatted, timeFormatted, saved.getMeetupLocation(),
                saved.getBuyer().getId(), saved.getOffer() != null ? saved.getOffer().getId() : "", saved.getBuyer().getName());

        com.bidly.user.entity.User recipient = isSeller ? saved.getBuyer() : saved.getSeller();
        notificationService.sendNotification(
                recipient,
                com.bidly.notification.entity.Notification.NotificationType.MEETUP_SCHEDULED,
                "Meeting Scheduled",
                "Meetup for " + saved.getListing().getTitle() + " is set for " + timeFormatted + " at " + saved.getMeetupLocation(),
                saved.getListing(),
                saved.getOffer(),
                saved,
                isSeller ? "Confirm Meetup" : "View Meetup",
                "/chat/offer/" + saved.getListing().getId(),
                saved.getId(),
                metadataJson
        );

        log.info("[MEETUP] Scheduled meetup for order {} at {} on {}", saved.getId(), saved.getMeetupLocation(), dateFormatted);
        return mapToSummaryDto(saved, currentUserId);
    }

    /**
     * Buyer confirms the scheduled meetup, which unlocks the Show OTP option.
     */
    @Transactional
    public OrderSummaryDto confirmMeetup(UUID orderId, UUID currentUserId) {
        Order order = orderRepository.findByIdWithPessimisticLock(orderId)
                .orElseThrow(() -> BidlyException.notFound("Order not found: " + orderId));

        boolean isBuyer = order.getBuyer().getId().equals(currentUserId);
        boolean isSeller = order.getSeller().getId().equals(currentUserId);
        if (!isBuyer && !isSeller) {
            throw BidlyException.forbidden("Only order participants can confirm this meetup");
        }

        order.setIsMeetupConfirmed(true);
        order.setClientActionId(null);
        Order saved = orderRepository.save(order);

        // Record tracking event
        trackingEventRepository.save(new OrderTrackingEvent(saved, Order.OrderStatus.ORDER_CONFIRMED, "Meetup Confirmed", "Meetup confirmed by " + (isBuyer ? "buyer" : "seller"), Instant.now()));

        // Post confirmation message to chat room
        chatRoomRepository.findByListingIdAndBuyerId(saved.getListing().getId(), saved.getBuyer().getId()).ifPresent(room -> {
            com.bidly.chat.entity.ChatMessage msg = new com.bidly.chat.entity.ChatMessage();
            msg.setRoomId(room.getId());
            msg.setSenderId(currentUserId);
            msg.setType(com.bidly.chat.entity.ChatMessage.MessageType.MEETUP_ACCEPTED);
            msg.setStatus(com.bidly.chat.entity.ChatMessage.MessageStatus.SENT);
            msg.setContent("🤝 Meetup confirmed! Show OTP upon meeting to complete item handover.");
            msg.setMetadata(String.format("{\"orderId\":\"%s\",\"eventType\":\"MEETUP_CONFIRMED\"}", saved.getId()));
            chatMessageRepository.save(msg);
            room.setLastMessageAt(Instant.now());
            room.setUpdatedAt(Instant.now());
            chatRoomRepository.save(room);

            Map<String, Object> eventData = new HashMap<>();
            eventData.put("eventType", "MEETUP_CONFIRMED");
            eventData.put("orderId", saved.getId());
            messagingTemplate.convertAndSend("/topic/chats/" + room.getId(), (Object) eventData);
        });

        // Notify other party
        com.bidly.user.entity.User otherParty = isBuyer ? saved.getSeller() : saved.getBuyer();
        String confirmMeta = String.format(
                "{\"orderId\":\"%s\",\"buyerId\":\"%s\",\"offerId\":\"%s\",\"buyerName\":\"%s\"}",
                saved.getId(), saved.getBuyer().getId(), saved.getOffer() != null ? saved.getOffer().getId() : "", saved.getBuyer().getName());

        notificationService.sendNotification(
                otherParty,
                com.bidly.notification.entity.Notification.NotificationType.MEETUP_CONFIRMED,
                "Meetup Confirmed",
                (isBuyer ? saved.getBuyer().getName() : saved.getSeller().getName()) + " confirmed the meetup schedule for " + saved.getListing().getTitle(),
                saved.getListing(),
                saved.getOffer(),
                saved,
                isBuyer ? "Mark As Sold" : "Show OTP",
                "/chat/offer/" + saved.getListing().getId(),
                saved.getId(),
                confirmMeta
        );

        log.info("[MEETUP] Meetup confirmed for order {} by user {}", saved.getId(), currentUserId);
        return mapToSummaryDto(saved, currentUserId);
    }

    /**
     * Buyer retrieves their confidential 6-digit OTP for in-person handover.
     */
    @Transactional(readOnly = true)
    public com.bidly.order.dto.BuyerOtpDto getBuyerOtp(UUID orderId, UUID currentUserId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> BidlyException.notFound("Order not found: " + orderId));

        if (!order.getBuyer().getId().equals(currentUserId)) {
            throw BidlyException.forbidden("Only the buyer can retrieve the handover OTP");
        }

        if (order.getDeliveryType() != Order.DeliveryType.IN_PERSON_MEETUP) {
            throw BidlyException.badRequest("This order is not configured for in-person meetup");
        }

        if (order.getMeetupOtp() == null || order.getMeetupOtp().isBlank()) {
            throw BidlyException.badRequest("No OTP has been generated for this meetup");
        }

        DateTimeFormatter dtf = DateTimeFormatter.ofPattern("MMM dd, yyyy").withZone(ZoneId.of("Asia/Kolkata"));
        DateTimeFormatter ttf = DateTimeFormatter.ofPattern("hh:mm a").withZone(ZoneId.of("Asia/Kolkata"));
        Instant mTime = order.getMeetupTime() != null ? order.getMeetupTime() : Instant.now();

        com.bidly.order.dto.BuyerOtpDto dto = new com.bidly.order.dto.BuyerOtpDto();
        dto.setOrderId(order.getId());
        dto.setOrderNumber(order.getOrderNumber());
        dto.setOtp(order.getMeetupOtp());
        dto.setOtpExpiresAt(order.getOtpExpiresAt() != null ? order.getOtpExpiresAt() : Instant.now().plus(Duration.ofHours(24)));
        dto.setBuyerName(order.getBuyer().getName());
        dto.setSellerName(order.getSeller().getName());
        dto.setProductTitle(order.getListing().getTitle());
        String primaryImg = (order.getListing().getMedia() != null && !order.getListing().getMedia().isEmpty())
                ? order.getListing().getMedia().get(0).getUrl() : null;
        dto.setProductImageUrl(mediaService.generatePresignedGetUrl(primaryImg, Duration.ofHours(4)));
        dto.setMeetupLocation(order.getMeetupLocation());
        dto.setMeetupTime(order.getMeetupTime());
        dto.setMeetupDateFormatted(dtf.format(mTime));
        dto.setMeetupTimeFormatted(ttf.format(mTime));

        return dto;
    }

    /**
     * Seller enters and verifies the OTP shared by the buyer during meetup.
     */
    @Transactional
    public OrderSummaryDto verifyMeetupOtp(UUID orderId, String inputOtp, UUID currentUserId) {
        Order order = orderRepository.findByIdWithPessimisticLock(orderId)
                .orElseThrow(() -> BidlyException.notFound("Order not found: " + orderId));

        if (!order.getSeller().getId().equals(currentUserId)) {
            throw BidlyException.forbidden("Only the seller can verify the buyer's OTP");
        }

        if (order.getDeliveryType() != Order.DeliveryType.IN_PERSON_MEETUP) {
            throw BidlyException.badRequest("This order is not set for in-person meetup");
        }

        if (inputOtp == null || inputOtp.isBlank()) {
            throw BidlyException.badRequest("OTP code is required");
        }

        if (order.getOtpAttemptCount() >= 5) {
            throw BidlyException.badRequest("Too many failed attempts. Verification is locked.");
        }

        if (order.getOtpExpiresAt() != null && order.getOtpExpiresAt().isBefore(Instant.now())) {
            throw BidlyException.badRequest("OTP has expired. Please reschedule meetup.");
        }

        if (order.getMeetupOtp() == null || !order.getMeetupOtp().trim().equals(inputOtp.trim())) {
            order.setOtpAttemptCount(order.getOtpAttemptCount() + 1);
            orderRepository.save(order);
            throw BidlyException.badRequest("Invalid OTP code. Please check the digits shown by the buyer.");
        }

        order.setMeetupOtpVerified(true);
        Order saved = orderRepository.save(order);

        // Notify Buyer of OTP verification
        notificationService.sendNotification(
                saved.getBuyer(),
                com.bidly.notification.entity.Notification.NotificationType.OTP_VERIFIED,
                "OTP Verified",
                "Your OTP was successfully verified by " + saved.getSeller().getName(),
                saved.getListing(),
                saved.getOffer(),
                saved,
                "View Details",
                "/orders/" + saved.getId() + "/track",
                saved.getId(),
                null
        );

        // Broadcast OTP_VERIFIED to room
        chatRoomRepository.findByListingIdAndBuyerId(saved.getListing().getId(), saved.getBuyer().getId()).ifPresent(room -> {
            Map<String, Object> eventData = new HashMap<>();
            eventData.put("eventType", "OTP_VERIFIED");
            eventData.put("orderId", saved.getId());
            messagingTemplate.convertAndSend("/topic/chats/" + room.getId(), (Object) eventData);
        });

        log.info("[OTP] Successfully verified OTP for order {}", orderId);
        return mapToSummaryDto(saved, currentUserId);
    }

    /**
     * Seller marks product SOLD after OTP verification.
     * Atomically transitions listing to SOLD, completes order, and releases payout.
     */
    @Transactional
    public com.bidly.order.dto.SaleSummaryDto markSold(UUID orderId, UUID currentUserId) {
        Order order = orderRepository.findByIdWithPessimisticLock(orderId)
                .orElseThrow(() -> BidlyException.notFound("Order not found: " + orderId));

        if (!order.getSeller().getId().equals(currentUserId)) {
            throw BidlyException.forbidden("Only the seller can mark this product as sold");
        }

        if (order.getDeliveryType() == Order.DeliveryType.IN_PERSON_MEETUP && !Boolean.TRUE.equals(order.getMeetupOtpVerified())) {
            throw BidlyException.badRequest("Cannot mark as sold: OTP verification must be completed first");
        }

        Listing listing = listingRepository.findByIdWithPessimisticLock(order.getListing().getId())
                .orElseThrow(() -> BidlyException.notFound("Listing not found"));

        if (listing.getStatus() == Listing.ListingStatus.SOLD && order.getStatus() == Order.OrderStatus.DELIVERED) {
            log.info("[MARK_SOLD] Listing {} already marked SOLD, returning existing summary", listing.getId());
            return getSaleSummary(orderId, currentUserId);
        }

        listing.setStatus(Listing.ListingStatus.SOLD);
        listingRepository.save(listing);

        order.setStatus(Order.OrderStatus.DELIVERED);
        order.setPaymentStatus(Order.PaymentStatus.RELEASED);
        order.setDeliveredAt(Instant.now());
        Order saved = orderRepository.save(order);

        // Credit seller funds in wallet ONLY if this was an AUCTION (funds held in digital escrow)
        if (order.getOrderSource() == Order.OrderSource.AUCTION) {
            walletService.topUpFunds(
                    saved.getSeller().getId(),
                    saved.getAmount(),
                    "Auction payout for verified order #" + saved.getOrderNumber()
            );
        } else {
            log.info("[MARK_SOLD] Direct sale in-person order #{} completed without in-app wallet payout (payment exchanged physically)", saved.getOrderNumber());
        }

        trackingEventRepository.save(new OrderTrackingEvent(saved, Order.OrderStatus.DELIVERED, "Product Sold", "Handover completed and product marked as SOLD", Instant.now()));

        // Disclose real-time events to both parties
        notificationService.sendNotification(
                saved.getBuyer(),
                com.bidly.notification.entity.Notification.NotificationType.ITEM_SOLD,
                "Product Handover Completed",
                "Your purchase of " + listing.getTitle() + " has been marked sold. Please rate your experience!",
                listing,
                saved.getOffer(),
                saved,
                "Rate Seller",
                "/orders/" + saved.getId() + "/review",
                saved.getId(),
                null
        );

        notificationService.sendNotification(
                saved.getSeller(),
                com.bidly.notification.entity.Notification.NotificationType.TRANSACTION_COMPLETED,
                "Product Sold Successfully!",
                "Your " + listing.getTitle() + " has been marked SOLD to " + saved.getBuyer().getName(),
                listing,
                saved.getOffer(),
                saved,
                "View Sale Details",
                "/my-listings/sale-summary/" + saved.getId(),
                saved.getId(),
                null
        );

        // Broadcast to chat room
        chatRoomRepository.findByListingIdAndBuyerId(listing.getId(), saved.getBuyer().getId()).ifPresent(room -> {
            Map<String, Object> eventData = new HashMap<>();
            eventData.put("eventType", "TRANSACTION_COMPLETED");
            eventData.put("orderId", saved.getId());
            eventData.put("listingId", listing.getId());
            eventData.put("status", "SOLD");
            messagingTemplate.convertAndSend("/topic/chats/" + room.getId(), (Object) eventData);
        });

        log.info("[MARK_SOLD] Order {} and listing {} transitioned to SOLD by seller {}", orderId, listing.getId(), currentUserId);
        return getSaleSummary(orderId, currentUserId);
    }

    /**
     * Retrieves authoritative sale summary for a completed order.
     */
    @Transactional(readOnly = true)
    public com.bidly.order.dto.SaleSummaryDto getSaleSummary(UUID orderId, UUID currentUserId) {
        Order order = orderRepository.findById(orderId)
                .or(() -> orderRepository.findFirstByListingIdOrderByCreatedAtDesc(orderId))
                .orElseThrow(() -> BidlyException.notFound("Order not found for: " + orderId));

        if (!order.getSeller().getId().equals(currentUserId) && !order.getBuyer().getId().equals(currentUserId)) {
            throw BidlyException.forbidden("You are not authorized to view this sale summary");
        }

        Listing listing = order.getListing();
        DateTimeFormatter dtf = DateTimeFormatter.ofPattern("dd MMM yyyy").withZone(ZoneId.of("Asia/Kolkata"));
        Instant saleDate = order.getDeliveredAt() != null ? order.getDeliveredAt() : order.getCreatedAt();

        com.bidly.order.dto.SaleSummaryDto dto = new com.bidly.order.dto.SaleSummaryDto();
        dto.setOrderId(order.getId());
        dto.setOrderNumber(order.getOrderNumber());
        dto.setListingId(listing.getId());
        dto.setListingTitle(listing.getTitle());

        String primaryImg = (listing.getMedia() != null && !listing.getMedia().isEmpty())
                ? listing.getMedia().get(0).getUrl() : null;
        dto.setListingImageUrl(mediaService.generatePresignedGetUrl(primaryImg, Duration.ofHours(4)));

        dto.setBuyerId(order.getBuyer().getId());
        dto.setBuyerName(order.getBuyer().getName());
        dto.setSellerId(order.getSeller().getId());
        dto.setSellerName(order.getSeller().getName());
        dto.setSaleType(order.getOrderSource() == Order.OrderSource.DIRECT_SALE ? "Direct Buy" : "Auction");
        dto.setFinalPrice(order.getAmount());
        dto.setPlatformFee(order.getPlatformFee());
        dto.setTotalAmount(order.getTotalAmount());
        dto.setSaleDate(saleDate);
        dto.setSaleDateFormatted(dtf.format(saleDate));
        dto.setPayoutStatus(order.getPaymentStatus() == Order.PaymentStatus.RELEASED ? "Released to Wallet" : "Offline payment");
        dto.setListingCustomId("#LST-" + listing.getId().toString().substring(0, 8).toUpperCase());
        dto.setTransactionId("#TXN-" + order.getOrderNumber().replace("ORD-", ""));

        return dto;
    }

    /**
     * Idempotent order creation when an auction ends and winner is determined.
     */
    @Transactional
    public Order createOrderForWinningBid(Listing listing, Bid winningBid) {
        Optional<Order> existing = orderRepository.findFirstByListingIdOrderByCreatedAtDesc(listing.getId());
        if (existing.isPresent()) {
            return existing.get();
        }

        String orderNum = "ORD-2026-" + String.format("%05d", new Random().nextInt(90000) + 10000);
        BigDecimal wonAmount = winningBid.getAmount();
        BigDecimal platformFee = wonAmount.multiply(BigDecimal.valueOf(0.02)).setScale(0, RoundingMode.HALF_UP);
        BigDecimal totalAmount = wonAmount.add(platformFee);

        Order order = new Order(
                orderNum,
                listing,
                winningBid.getBidder(),
                listing.getSeller(),
                winningBid,
                winningBid.getDeliveryAddress(),
                wonAmount,
                platformFee,
                totalAmount
        );

        order.setCourierPartner(null);
        order.setTrackingNumber(null);
        order.setEstimatedDeliveryDate(null);
        order.setStatus(Order.OrderStatus.AUCTION_WON);
        order.setPaymentStatus(Order.PaymentStatus.IN_ESCROW);

        Order savedOrder = orderRepository.save(order);

        // Convert reserved funds into Escrow Hold
        walletService.convertReservationToEscrow(winningBid.getBidder().getId(), wonAmount, savedOrder.getId());

        trackingEventRepository.save(new OrderTrackingEvent(
                savedOrder,
                Order.OrderStatus.AUCTION_WON,
                "Auction Won",
                "You won the auction with a winning bid of ₹" + wonAmount,
                Instant.now()
        ));

        return savedOrder;
    }

    @Transactional(readOnly = true)
    public OrderSummaryDto getOrderDetails(UUID orderId, UUID currentUserId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> BidlyException.notFound("Order not found: " + orderId));
        if (!order.getBuyer().getId().equals(currentUserId) && !order.getSeller().getId().equals(currentUserId)) {
            throw BidlyException.forbidden("Unauthorized: You do not have access to this order's details");
        }
        return mapToSummaryDto(order);
    }

    @Transactional(readOnly = true)
    public OrderSummaryDto getOrCreateOrderByListing(UUID listingId, UUID currentUserId) {
        Optional<Order> existing = orderRepository.findFirstByListingIdAndBuyerIdOrderByCreatedAtDesc(listingId, currentUserId);
        if (existing.isEmpty()) {
            existing = orderRepository.findFirstByListingIdAndSellerIdOrderByCreatedAtDesc(listingId, currentUserId);
        }
        if (existing.isEmpty()) {
            existing = orderRepository.findFirstByListingIdOrderByCreatedAtDesc(listingId);
        }
        if (existing.isPresent()) {
            Order order = existing.get();
            if (!order.getBuyer().getId().equals(currentUserId) && !order.getSeller().getId().equals(currentUserId)) {
                throw BidlyException.forbidden("Unauthorized: You do not have access to this order's details");
            }
            return mapToSummaryDto(order, currentUserId);
        }
        throw BidlyException.notFound("No active order found for listing: " + listingId);
    }

    /**
     * Buyer attaches or updates their delivery address on the Order.
     * Concurrency-safe, authorization-verified, broadcasts in-chat address card to seller.
     */
    @Transactional
    public OrderSummaryDto updateDeliveryAddress(UUID orderId, UUID currentUserId, com.bidly.order.dto.UpdateOrderAddressRequest req) {
        Order order = orderRepository.findByIdWithPessimisticLock(orderId)
                .orElseThrow(() -> BidlyException.notFound("Order not found: " + orderId));

        if (!order.getBuyer().getId().equals(currentUserId)) {
            throw BidlyException.forbidden("Unauthorized: Only the buyer can update delivery address for this order");
        }

        if (order.getStatus() == Order.OrderStatus.DELIVERED || order.getStatus() == Order.OrderStatus.CANCELLED) {
            throw BidlyException.badRequest("Cannot update address for order with status: " + order.getStatus());
        }

        com.bidly.address.entity.DeliveryAddress address = null;
        if (req != null && req.getAddressId() != null) {
            address = addressRepository.findById(req.getAddressId())
                    .orElseThrow(() -> BidlyException.notFound("Delivery address not found: " + req.getAddressId()));
            if (!address.getUser().getId().equals(currentUserId)) {
                throw BidlyException.forbidden("Unauthorized: You do not own this delivery address");
            }
        } else if (req != null && req.getAddressLine() != null && !req.getAddressLine().trim().isEmpty()) {
            User buyer = order.getBuyer();
            address = new com.bidly.address.entity.DeliveryAddress();
            address.setUser(buyer);
            address.setFullName(req.getFullName() != null && !req.getFullName().trim().isEmpty() ? req.getFullName().trim() : buyer.getName());
            address.setPhone(req.getPhone() != null && !req.getPhone().trim().isEmpty() ? req.getPhone().trim() : (buyer.getPhone() != null ? buyer.getPhone() : ""));
            address.setAddressLine(req.getAddressLine().trim());
            address.setCity(req.getCity() != null ? req.getCity().trim() : "");
            address.setPincode(req.getPincode() != null ? req.getPincode().trim() : "");
            address.setDefault(true);
            address = addressRepository.save(address);
        }

        if (address != null) {
            order.setDeliveryAddress(address);
            order.setDeliveryType(Order.DeliveryType.COURIER);
            Order saved = orderRepository.save(order);

            // Post real-time Delivery Address card to pairwise chat room
            final com.bidly.address.entity.DeliveryAddress finalAddress = address;
            chatRoomRepository.findByListingIdAndBuyerId(saved.getListing().getId(), saved.getBuyer().getId()).ifPresent(room -> {
                try {
                    com.bidly.chat.entity.ChatMessage msg = new com.bidly.chat.entity.ChatMessage();
                    msg.setRoomId(room.getId());
                    msg.setSenderId(saved.getBuyer().getId());
                    msg.setContent("Delivery Address: " + finalAddress.getFullName() + ", " + finalAddress.getAddressLine() + ", " + finalAddress.getCity() + " - " + finalAddress.getPincode() + " (Phone: " + finalAddress.getPhone() + ")");
                    msg.setType(com.bidly.chat.entity.ChatMessage.MessageType.ORDER_UPDATE);

                    Map<String, Object> meta = new HashMap<>();
                    meta.put("eventType", "DELIVERY_ADDRESS_SHARED");
                    meta.put("orderId", saved.getId().toString());
                    meta.put("recipientName", finalAddress.getFullName());
                    meta.put("phone", finalAddress.getPhone());
                    meta.put("addressLine", finalAddress.getAddressLine());
                    meta.put("city", finalAddress.getCity());
                    meta.put("pincode", finalAddress.getPincode());

                    com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
                    msg.setMetadata(mapper.writeValueAsString(meta));
                    chatMessageRepository.save(msg);

                    messagingTemplate.convertAndSend("/topic/chat/" + room.getId(), msg);
                } catch (Exception e) {
                    log.warn("[DELIVERY_ADDRESS_CHAT] Failed to send chat message: {}", e.getMessage());
                }
            });

            // Notify seller via STOMP notifications
            Map<String, Object> wsEvent = new HashMap<>();
            wsEvent.put("eventType", "DELIVERY_ADDRESS_SHARED");
            wsEvent.put("orderId", saved.getId().toString());
            wsEvent.put("listingId", saved.getListing().getId().toString());
            wsEvent.put("recipientName", finalAddress.getFullName());
            messagingTemplate.convertAndSend("/topic/users/" + saved.getSeller().getId() + "/notifications", wsEvent);

            return mapToSummaryDto(saved);
        }

        return mapToSummaryDto(order);
    }

    /**
     * Buyer confirms product receipt -> Releases escrow to seller!
     */
    @Transactional
    public OrderSummaryDto confirmDelivery(UUID orderId, UUID currentUserId) {
        Order order = orderRepository.findByIdWithPessimisticLock(orderId)
                .orElseThrow(() -> BidlyException.notFound("Order not found: " + orderId));

        if (!order.getBuyer().getId().equals(currentUserId)) {
            throw BidlyException.forbidden("Only the buyer can confirm delivery of this order");
        }

        if (order.getStatus() == Order.OrderStatus.DELIVERED) {
            return mapToSummaryDto(order);
        }

        order.setStatus(Order.OrderStatus.DELIVERED);
        order.setPaymentStatus(Order.PaymentStatus.RELEASED);
        order.setDeliveredAt(Instant.now());
        orderRepository.save(order);

        // Mark listing as SOLD
        Listing listing = order.getListing();
        if (listing != null && listing.getStatus() != Listing.ListingStatus.SOLD) {
            listing.setStatus(Listing.ListingStatus.SOLD);
            listingRepository.save(listing);
        }

        // Credit payment to seller
        walletService.topUpFunds(
                order.getSeller().getId(),
                order.getAmount(),
                "Escrow payout released for completed order #" + order.getOrderNumber()
        );

        trackingEventRepository.save(new OrderTrackingEvent(
                order,
                Order.OrderStatus.DELIVERED,
                "Delivered",
                "Product delivered and confirmed by buyer",
                Instant.now()
        ));

        // Notify Seller that buyer confirmed delivery and payout released
        notificationService.sendNotification(
                order.getSeller(),
                com.bidly.notification.entity.Notification.NotificationType.TRANSACTION_COMPLETED,
                "Delivery Confirmed",
                order.getBuyer().getName() + " confirmed receipt of " + (listing != null ? listing.getTitle() : "the item") + ". Escrow payout released!",
                listing,
                order.getOffer(),
                order,
                "View Sale Details",
                "/my-listings/sale-summary/" + order.getId(),
                order.getId(),
                null
        );

        // Disclose real-time chat card to room
        if (listing != null) {
            chatRoomRepository.findByListingIdAndBuyerId(listing.getId(), order.getBuyer().getId()).ifPresent(room -> {
                try {
                    com.bidly.chat.entity.ChatMessage msg = new com.bidly.chat.entity.ChatMessage();
                    msg.setRoomId(room.getId());
                    msg.setSenderId(currentUserId);
                    msg.setContent("Delivery confirmed! Payment of ₹" + String.format("%,.0f", order.getAmount()) + " has been released to the seller from escrow.");
                    msg.setType(com.bidly.chat.entity.ChatMessage.MessageType.ORDER_UPDATE);

                    Map<String, Object> meta = new HashMap<>();
                    meta.put("eventType", "TRANSACTION_COMPLETED");
                    meta.put("orderId", order.getId().toString());
                    meta.put("listingId", listing.getId().toString());
                    meta.put("status", "SOLD");
                    meta.put("amount", order.getAmount());

                    com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
                    msg.setMetadata(mapper.writeValueAsString(meta));
                    chatMessageRepository.save(msg);

                    messagingTemplate.convertAndSend("/topic/chat/" + room.getId(), msg);

                    Map<String, Object> eventData = new HashMap<>();
                    eventData.put("eventType", "TRANSACTION_COMPLETED");
                    eventData.put("orderId", order.getId());
                    eventData.put("listingId", listing.getId());
                    eventData.put("status", "SOLD");
                    messagingTemplate.convertAndSend("/topic/chats/" + room.getId(), (Object) eventData);
                } catch (Exception e) {
                    log.warn("[CONFIRM_DELIVERY_CHAT] Failed to broadcast to chat: {}", e.getMessage());
                }
            });
        }

        return mapToSummaryDto(order);
    }

    public OrderSummaryDto mapToSummaryDto(Order o) {
        OrderSummaryDto dto = new OrderSummaryDto();
        dto.setId(o.getId());
        dto.setOrderNumber(o.getOrderNumber());
        dto.setListingId(o.getListing().getId());
        dto.setProductTitle(o.getListing().getTitle());
        dto.setProductCondition(o.getListing().getCondition() != null ? o.getListing().getCondition().name() : "LIKE_NEW");

        String primaryImg = (o.getListing().getMedia() != null && !o.getListing().getMedia().isEmpty())
                ? o.getListing().getMedia().get(0).getUrl() : null;
        dto.setPrimaryImageUrl(mediaService.generatePresignedGetUrl(primaryImg, Duration.ofHours(4)));

        dto.setWonAmount(o.getAmount());
        dto.setPlatformFee(o.getPlatformFee());
        dto.setTotalAmount(o.getTotalAmount());
        dto.setStatus(o.getStatus().name());
        dto.setPaymentStatus(o.getPaymentStatus().name());
        dto.setCourierPartner(o.getCourierPartner());
        dto.setTrackingNumber(o.getTrackingNumber());
        dto.setEstimatedDeliveryDate(o.getEstimatedDeliveryDate());
        dto.setDeliveredAt(o.getDeliveredAt());

        dto.setBuyerId(o.getBuyer().getId());
        dto.setBuyerName(o.getBuyer().getName() != null ? o.getBuyer().getName() : "");

        dto.setSellerId(o.getSeller().getId());
        dto.setSellerName(o.getSeller().getName() != null ? o.getSeller().getName() : "");
        dto.setSellerRating(o.getListing().getRating() != null ? o.getListing().getRating() : 0.0);
        dto.setSellerSalesCount(0);

        if (o.getDeliveryAddress() != null) {
            dto.setDeliveryAddressFullName(o.getDeliveryAddress().getFullName());
            dto.setDeliveryAddressPhone(o.getDeliveryAddress().getPhone());
            dto.setDeliveryAddressLine(o.getDeliveryAddress().getAddressLine());
            dto.setDeliveryAddressCity(o.getDeliveryAddress().getCity());
            dto.setDeliveryAddressPincode(o.getDeliveryAddress().getPincode());
        } else {
            dto.setDeliveryAddressFullName(dto.getBuyerName());
            dto.setDeliveryAddressPhone(o.getBuyer().getPhone() != null ? o.getBuyer().getPhone() : "");
            dto.setDeliveryAddressLine("");
            dto.setDeliveryAddressCity("");
            dto.setDeliveryAddressPincode("");
        }

        dto.setOrderSource(o.getOrderSource() != null ? o.getOrderSource().name() : "AUCTION");
        dto.setDeliveryType(o.getDeliveryType() != null ? o.getDeliveryType().name() : "COURIER");
        dto.setMeetupLocation(o.getMeetupLocation());
        dto.setMeetupTime(o.getMeetupTime());
        dto.setMeetupOtp(o.getMeetupOtp());
        dto.setMeetupOtpVerified(o.getMeetupOtpVerified() != null ? o.getMeetupOtpVerified() : false);
        dto.setMeetupConfirmed(Boolean.TRUE.equals(o.getIsMeetupConfirmed()) || "MEETUP_CONFIRMED".equals(o.getClientActionId()) || Boolean.TRUE.equals(o.getMeetupOtpVerified()));
        if (o.getOffer() != null) {
            dto.setOfferId(o.getOffer().getId());
        }

        List<OrderTrackingEvent> events = trackingEventRepository.findByOrderIdOrderByEventTimeAsc(o.getId());
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("MMM dd, h:mm a").withZone(ZoneId.systemDefault());

        List<OrderTrackingEventDto> timeline = new ArrayList<>();
        for (OrderTrackingEvent e : events) {
            timeline.add(new OrderTrackingEventDto(
                    e.getId(),
                    e.getStatus().name(),
                    e.getTitle(),
                    e.getDescription(),
                    e.getEventTime(),
                    formatter.format(e.getEventTime()),
                    true
            ));
        }
        dto.setTrackingTimeline(timeline);

        return dto;
    }

    public OrderSummaryDto mapToSummaryDto(Order o, UUID currentUserId) {
        OrderSummaryDto dto = mapToSummaryDto(o);
        if (currentUserId != null) {
            dto.setSeller(currentUserId.equals(o.getSeller().getId()));
            dto.setBuyer(currentUserId.equals(o.getBuyer().getId()));
        }
        return dto;
    }

    @Transactional(readOnly = true)
    public List<OrderSummaryDto> getUserOrders(UUID currentUserId, String source, String role) {
        if (currentUserId == null) {
            return Collections.emptyList();
        }
        Set<Order> orders = new LinkedHashSet<>();
        if ("SELLER".equalsIgnoreCase(role)) {
            orders.addAll(orderRepository.findBySellerIdOrderByCreatedAtDesc(currentUserId));
        } else if ("BUYER".equalsIgnoreCase(role)) {
            orders.addAll(orderRepository.findByBuyerIdOrderByCreatedAtDesc(currentUserId));
        } else {
            orders.addAll(orderRepository.findByBuyerIdOrderByCreatedAtDesc(currentUserId));
            orders.addAll(orderRepository.findBySellerIdOrderByCreatedAtDesc(currentUserId));
        }

        List<OrderSummaryDto> dtos = orders.stream()
                .filter(o -> {
                    if (source != null && !source.isBlank() && !"ALL".equalsIgnoreCase(source)) {
                        return source.equalsIgnoreCase(o.getOrderSource() != null ? o.getOrderSource().name() : "AUCTION");
                    }
                    return true;
                })
                .map(o -> mapToSummaryDto(o, currentUserId))
                .collect(Collectors.toList());        return dtos;
    }

    /**
     * Seller submits real courier shipment tracking details.
     * Transitions order to SHIPPED, logs tracking event, notifies buyer, sends chat card.
     */
    @Transactional
    public OrderSummaryDto createCourierShipment(UUID orderId, UUID currentUserId, com.bidly.order.dto.CourierShipmentRequest req) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> BidlyException.notFound("Order not found: " + orderId));

        if (!order.getSeller().getId().equals(currentUserId)) {
            throw BidlyException.forbidden("Only the seller can dispatch this courier shipment");
        }

        if (order.getStatus() == Order.OrderStatus.DELIVERED || order.getStatus() == Order.OrderStatus.CANCELLED) {
            throw BidlyException.badRequest("Cannot dispatch shipment for order in status: " + order.getStatus());
        }

        order.setDeliveryType(Order.DeliveryType.COURIER);
        order.setCourierPartner(req.getCourierPartner().trim());
        order.setTrackingNumber(req.getTrackingNumber().trim());
        order.setEstimatedDeliveryDate(req.getEstimatedDeliveryDate());
        order.setStatus(Order.OrderStatus.SHIPPED);

        Order saved = orderRepository.save(order);

        trackingEventRepository.save(new OrderTrackingEvent(
                saved,
                Order.OrderStatus.SHIPPED,
                "Shipment Dispatched",
                "Package handed over to " + req.getCourierPartner().trim() + " (Tracking: " + req.getTrackingNumber().trim() + ")",
                Instant.now()
        ));

        DateTimeFormatter dtf = DateTimeFormatter.ofPattern("EEE, d MMM").withZone(ZoneId.of("Asia/Kolkata"));
        String estDateFormatted = dtf.format(req.getEstimatedDeliveryDate());

        // Send persistent notification to Buyer
        Map<String, Object> meta = new HashMap<>();
        meta.put("trackingNumber", req.getTrackingNumber().trim());
        meta.put("courierPartner", req.getCourierPartner().trim());
        meta.put("estimatedDeliveryDate", estDateFormatted);
        meta.put("orderId", saved.getId().toString());

        notificationService.sendNotificationWithMeta(
                saved.getBuyer(),
                com.bidly.notification.entity.Notification.NotificationType.SHIPPED,
                "Shipment Dispatched",
                "Your order for " + saved.getListing().getTitle() + " has been shipped via " + req.getCourierPartner().trim(),
                saved.getListing(),
                saved.getOffer(),
                saved,
                "Track My Order",
                "/orders/" + saved.getId() + "/track",
                saved.getId(),
                meta
        );

        // Disclose real-time chat card to room
        chatRoomRepository.findByListingIdAndBuyerId(saved.getListing().getId(), saved.getBuyer().getId()).ifPresent(room -> {
            try {
                com.bidly.chat.entity.ChatMessage msg = new com.bidly.chat.entity.ChatMessage();
                msg.setRoomId(room.getId());
                msg.setSenderId(saved.getSeller().getId());
                msg.setContent("Shipment Dispatched via " + req.getCourierPartner().trim() + " (Tracking: " + req.getTrackingNumber().trim() + ")");
                msg.setType(com.bidly.chat.entity.ChatMessage.MessageType.ORDER_UPDATE);
                com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
                msg.setMetadata(mapper.writeValueAsString(meta));
                chatMessageRepository.save(msg);

                messagingTemplate.convertAndSend("/topic/chat/" + room.getId(), msg);
            } catch (Exception e) {
                log.warn("[SHIPMENT_CHAT] Failed to send chat message for room {}: {}", room.getId(), e.getMessage());
            }
        });

        // Broadcast notification update to buyer topic
        Map<String, Object> wsEvent = new HashMap<>();
        wsEvent.put("eventType", "SHIPMENT_DISPATCHED");
        wsEvent.put("orderId", saved.getId());
        wsEvent.put("trackingNumber", req.getTrackingNumber().trim());
        wsEvent.put("courierPartner", req.getCourierPartner().trim());
        wsEvent.put("estimatedDeliveryDate", estDateFormatted);
        messagingTemplate.convertAndSend("/topic/users/" + saved.getBuyer().getId() + "/notifications", wsEvent);

        log.info("[COURIER_SHIPMENT] Order {} shipped via {} (Tracking: {}) by seller {}",
                saved.getId(), req.getCourierPartner(), req.getTrackingNumber(), currentUserId);

        return mapToSummaryDto(saved, currentUserId);
    }
}
