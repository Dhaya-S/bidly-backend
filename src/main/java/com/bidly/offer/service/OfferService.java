package com.bidly.offer.service;

import com.bidly.chat.entity.ChatMessage;
import com.bidly.chat.entity.ChatRoom;
import com.bidly.chat.repository.ChatMessageRepository;
import com.bidly.chat.repository.ChatRoomRepository;
import com.bidly.common.exception.BidlyException;
import com.bidly.listing.entity.Listing;
import com.bidly.listing.repository.ListingRepository;
import com.bidly.media.service.MediaService;
import com.bidly.offer.dto.*;
import com.bidly.offer.entity.Offer;
import com.bidly.offer.repository.OfferRepository;
import com.bidly.order.entity.Order;
import com.bidly.order.service.OrderService;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class OfferService {

    private static final Logger log = LoggerFactory.getLogger(OfferService.class);

    private final OfferRepository offerRepository;
    private final ListingRepository listingRepository;
    private final UserRepository userRepository;
    private final OrderService orderService;
    private final ChatRoomRepository chatRoomRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final MediaService mediaService;

    public OfferService(
            OfferRepository offerRepository,
            ListingRepository listingRepository,
            UserRepository userRepository,
            OrderService orderService,
            ChatRoomRepository chatRoomRepository,
            ChatMessageRepository chatMessageRepository,
            MediaService mediaService) {
        this.offerRepository = offerRepository;
        this.listingRepository = listingRepository;
        this.userRepository = userRepository;
        this.orderService = orderService;
        this.chatRoomRepository = chatRoomRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.mediaService = mediaService;
    }

    /**
     * Buyer creates a new Offer on a Direct Sale listing.
     */
    @Transactional
    public OfferDto createOffer(UUID listingId, UUID buyerId, CreateOfferRequest req) {
        if (buyerId == null) {
            throw BidlyException.unauthorized("Authentication required to make an offer");
        }
        if (req.getAmount() == null || req.getAmount().signum() <= 0) {
            throw BidlyException.badRequest("Valid offer amount is required");
        }

        Listing listing = listingRepository.findById(listingId)
                .orElseThrow(() -> BidlyException.notFound("Listing not found: " + listingId));

        if (listing.getSellingMethod() != Listing.SellingMethod.DIRECT_BUY) {
            throw BidlyException.badRequest("This listing is an Auction and does not accept direct sale offers");
        }

        if (listing.getStatus() != Listing.ListingStatus.ACTIVE) {
            throw BidlyException.badRequest("This listing is no longer active (Status: " + listing.getStatus() + ")");
        }

        User buyer = userRepository.findById(buyerId)
                .orElseThrow(() -> BidlyException.notFound("Buyer user not found"));

        User seller = listing.getSeller();
        if (seller != null && seller.getId().equals(buyerId)) {
            throw BidlyException.badRequest("You cannot make an offer on your own listing");
        }

        Offer offer = new Offer(listing, buyer, seller, req.getAmount(), req.getMessage());
        offer.setExpiresAt(Instant.now().plus(Duration.ofDays(3)));
        Offer saved = offerRepository.save(offer);

        // Ensure chat room exists and post offer message
        ChatRoom room = chatRoomRepository.findByListingIdAndBuyerId(listingId, buyerId)
                .orElseGet(() -> {
                    ChatRoom r = new ChatRoom();
                    r.setListingId(listingId);
                    r.setBuyerId(buyerId);
                    r.setSellerId(seller != null ? seller.getId() : buyerId);
                    return chatRoomRepository.save(r);
                });

        ChatMessage msg = new ChatMessage();
        msg.setRoomId(room.getId());
        msg.setSenderId(buyerId);
        msg.setType(ChatMessage.MessageType.OFFER);
        msg.setOfferAmount(req.getAmount());
        msg.setContent(req.getMessage() != null && !req.getMessage().isBlank()
                ? req.getMessage().trim()
                : "Submitted an offer of Rs. " + req.getAmount().toBigInteger());
        chatMessageRepository.save(msg);
        room.setLastMessageAt(Instant.now());
        chatRoomRepository.save(room);

        log.info("Offer of Rs. {} submitted for listing '{}' by buyer '{}'", req.getAmount(), listing.getTitle(), buyer.getName());
        return mapToDto(saved, buyerId);
    }

    /**
     * Seller or Buyer submits a counter-offer.
     */
    @Transactional
    public OfferDto counterOffer(UUID offerId, UUID currentUserId, CounterOfferRequest req) {
        if (currentUserId == null) {
            throw BidlyException.unauthorized("Authentication required");
        }
        if (req.getCounterAmount() == null || req.getCounterAmount().signum() <= 0) {
            throw BidlyException.badRequest("Valid counter offer amount is required");
        }

        Offer offer = offerRepository.findByIdWithPessimisticLock(offerId)
                .orElseThrow(() -> BidlyException.notFound("Offer not found: " + offerId));

        if (offer.getStatus() != Offer.OfferStatus.PENDING && offer.getStatus() != Offer.OfferStatus.COUNTERED) {
            throw BidlyException.badRequest("Cannot counter an offer that is " + offer.getStatus());
        }

        boolean isSeller = currentUserId.equals(offer.getSeller().getId());
        boolean isBuyer = currentUserId.equals(offer.getBuyer().getId());
        if (!isSeller && !isBuyer) {
            throw BidlyException.forbidden("You are not authorized to negotiate this offer");
        }

        offer.setCounterAmount(req.getCounterAmount());
        offer.setStatus(Offer.OfferStatus.COUNTERED);
        offer.setMessage(req.getMessage());
        Offer saved = offerRepository.save(offer);

        // Post counter message to chat room
        ChatRoom room = chatRoomRepository.findByListingIdAndBuyerId(offer.getListing().getId(), offer.getBuyer().getId()).orElse(null);
        if (room != null) {
            ChatMessage msg = new ChatMessage();
            msg.setRoomId(room.getId());
            msg.setSenderId(currentUserId);
            msg.setType(ChatMessage.MessageType.OFFER);
            msg.setOfferAmount(req.getCounterAmount());
            msg.setContent("Counter offer of Rs. " + req.getCounterAmount().toBigInteger() + (req.getMessage() != null ? ": " + req.getMessage() : ""));
            chatMessageRepository.save(msg);
            room.setLastMessageAt(Instant.now());
            chatRoomRepository.save(room);
        }

        log.info("Counter offer of Rs. {} submitted on offer '{}'", req.getCounterAmount(), offerId);
        return mapToDto(saved, currentUserId);
    }

    /**
     * Rejects or declines an offer.
     */
    @Transactional
    public OfferDto rejectOffer(UUID offerId, UUID currentUserId) {
        Offer offer = offerRepository.findByIdWithPessimisticLock(offerId)
                .orElseThrow(() -> BidlyException.notFound("Offer not found: " + offerId));

        boolean isSeller = currentUserId.equals(offer.getSeller().getId());
        boolean isBuyer = currentUserId.equals(offer.getBuyer().getId());
        if (!isSeller && !isBuyer) {
            throw BidlyException.forbidden("You are not authorized to reject this offer");
        }

        offer.setStatus(isSeller ? Offer.OfferStatus.REJECTED : Offer.OfferStatus.CANCELLED);
        Offer saved = offerRepository.save(offer);

        ChatRoom room = chatRoomRepository.findByListingIdAndBuyerId(offer.getListing().getId(), offer.getBuyer().getId()).orElse(null);
        if (room != null) {
            ChatMessage msg = new ChatMessage();
            msg.setRoomId(room.getId());
            msg.setSenderId(currentUserId);
            msg.setType(ChatMessage.MessageType.TEXT);
            msg.setContent(isSeller ? "Offer of Rs. " + offer.getAmount() + " declined." : "Offer cancelled by buyer.");
            chatMessageRepository.save(msg);
            room.setLastMessageAt(Instant.now());
            chatRoomRepository.save(room);
        }

        return mapToDto(saved, currentUserId);
    }

    /**
     * Atomically accepts the offer, marks the listing SOLD, cancels competing offers,
     * and creates the direct-sale order with delivery/meetup details.
     */
    @Transactional
    public OfferDto acceptOffer(UUID offerId, UUID currentUserId, AcceptOfferRequest req) {
        Offer offer = offerRepository.findByIdWithPessimisticLock(offerId)
                .orElseThrow(() -> BidlyException.notFound("Offer not found: " + offerId));

        Listing listing = listingRepository.findByIdWithPessimisticLock(offer.getListing().getId())
                .orElseThrow(() -> BidlyException.notFound("Listing not found"));

        if (listing.getStatus() != Listing.ListingStatus.ACTIVE) {
            throw BidlyException.badRequest("This listing has already been sold or is no longer active");
        }

        if (listing.getSellingMethod() != Listing.SellingMethod.DIRECT_BUY) {
            throw BidlyException.badRequest("Listing is not a Direct Sale");
        }

        if (offer.getStatus() != Offer.OfferStatus.PENDING && offer.getStatus() != Offer.OfferStatus.COUNTERED) {
            throw BidlyException.badRequest("Cannot accept an offer that is " + offer.getStatus());
        }

        boolean isSeller = currentUserId.equals(offer.getSeller().getId());
        boolean isBuyer = currentUserId.equals(offer.getBuyer().getId());
        if (!isSeller && !isBuyer) {
            throw BidlyException.forbidden("Not authorized to accept this offer");
        }

        // Mark offer as ACCEPTED
        offer.setStatus(Offer.OfferStatus.ACCEPTED);
        Offer savedOffer = offerRepository.save(offer);

        // Mark listing as SOLD
        listing.setStatus(Listing.ListingStatus.SOLD);
        listingRepository.save(listing);

        // Create the Order
        Order order = orderService.createOrderForAcceptedOffer(listing, savedOffer, req);

        // Cancel other pending offers on this listing
        List<Offer> pendingOffers = offerRepository.findByListingIdAndStatus(listing.getId(), Offer.OfferStatus.PENDING);
        for (Offer p : pendingOffers) {
            if (!p.getId().equals(offer.getId())) {
                p.setStatus(Offer.OfferStatus.CANCELLED);
                offerRepository.save(p);
            }
        }

        // Post accepted message to chat
        ChatRoom room = chatRoomRepository.findByListingIdAndBuyerId(listing.getId(), offer.getBuyer().getId()).orElse(null);
        if (room != null) {
            ChatMessage msg = new ChatMessage();
            msg.setRoomId(room.getId());
            msg.setSenderId(currentUserId);
            msg.setType(ChatMessage.MessageType.TEXT);
            msg.setContent("🎉 Offer of Rs. " + (offer.getCounterAmount() != null ? offer.getCounterAmount() : offer.getAmount()) + " ACCEPTED! Order #" + order.getOrderNumber() + " created.");
            chatMessageRepository.save(msg);
            room.setLastMessageAt(Instant.now());
            chatRoomRepository.save(room);
        }

        log.info("Offer '{}' accepted. Listing '{}' marked SOLD. Order '{}' created.", offerId, listing.getTitle(), order.getOrderNumber());
        OfferDto dto = mapToDto(savedOffer, currentUserId);
        dto.setOrderId(order.getId());
        return dto;
    }

    /**
     * Retrieves the latest offer for a listing + buyer.
     */
    @Transactional(readOnly = true)
    public Optional<OfferDto> getLatestOffer(UUID listingId, UUID buyerId, UUID currentUserId) {
        return offerRepository.findFirstByListingIdAndBuyerIdOrderByCreatedAtDesc(listingId, buyerId)
                .map(o -> mapToDto(o, currentUserId));
    }

    /**
     * Retrieves an offer by ID.
     */
    @Transactional(readOnly = true)
    public OfferDto getOfferById(UUID offerId, UUID currentUserId) {
        Offer offer = offerRepository.findById(offerId)
                .orElseThrow(() -> BidlyException.notFound("Offer not found: " + offerId));
        return mapToDto(offer, currentUserId);
    }

    public OfferDto mapToDto(Offer o, UUID currentUserId) {
        OfferDto dto = new OfferDto();
        dto.setId(o.getId());
        dto.setListingId(o.getListing().getId());
        dto.setListingTitle(o.getListing().getTitle());
        dto.setListingPrice(o.getListing().getPrice());

        String primaryImg = (o.getListing().getMedia() != null && !o.getListing().getMedia().isEmpty())
                ? o.getListing().getMedia().get(0).getUrl() : null;
        dto.setListingImageUrl(mediaService.generatePresignedGetUrl(primaryImg, Duration.ofHours(4)));

        dto.setBuyerId(o.getBuyer().getId());
        dto.setBuyerName(o.getBuyer().getName() != null ? o.getBuyer().getName() : "Buyer");

        dto.setSellerId(o.getSeller().getId());
        dto.setSellerName(o.getSeller().getName() != null ? o.getSeller().getName() : "Seller");

        dto.setAmount(o.getAmount());
        dto.setCounterAmount(o.getCounterAmount());
        dto.setStatus(o.getStatus().name());
        dto.setMessage(o.getMessage());
        dto.setCreatedAt(o.getCreatedAt());
        dto.setExpiresAt(o.getExpiresAt());

        if (currentUserId != null) {
            dto.setBuyer(currentUserId.equals(o.getBuyer().getId()));
            dto.setSeller(currentUserId.equals(o.getSeller().getId()));
        }

        return dto;
    }
}
