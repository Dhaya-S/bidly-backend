package com.bidly.chat.service;

import com.bidly.chat.dto.ChatMessageDto;
import com.bidly.chat.dto.ChatRoomDto;
import com.bidly.chat.dto.SendMessageRequest;
import com.bidly.chat.entity.ChatMessage;
import com.bidly.chat.entity.ChatRoom;
import com.bidly.chat.repository.ChatMessageRepository;
import com.bidly.chat.repository.ChatRoomRepository;
import com.bidly.common.exception.BidlyException;
import com.bidly.listing.entity.Listing;
import com.bidly.listing.repository.ListingRepository;
import com.bidly.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class ChatService {

    private final ChatRoomRepository roomRepo;
    private final ChatMessageRepository messageRepo;
    private final ListingRepository listingRepo;
    private final UserRepository userRepo;

    public ChatService(ChatRoomRepository roomRepo,
                       ChatMessageRepository messageRepo,
                       ListingRepository listingRepo,
                       UserRepository userRepo) {
        this.roomRepo    = roomRepo;
        this.messageRepo = messageRepo;
        this.listingRepo = listingRepo;
        this.userRepo    = userRepo;
    }

    @Transactional
    public ChatRoomDto getOrCreateRoom(UUID listingId, UUID buyerId) {
        if (buyerId == null) {
            throw BidlyException.unauthorized("Authentication required to use chat");
        }
        return roomRepo.findByListingIdAndBuyerId(listingId, buyerId)
                .map(this::mapRoomToDto)
                .orElseGet(() -> {
                    Listing listing = listingRepo.findById(listingId)
                            .orElseThrow(() -> BidlyException.notFound("Listing not found"));
                    ChatRoom room = new ChatRoom();
                    room.setListingId(listingId);
                    room.setBuyerId(buyerId);
                    room.setSellerId(listing.getSeller() != null ? listing.getSeller().getId() : buyerId);
                    return mapRoomToDto(roomRepo.save(room));
                });
    }

    /** List all chat rooms where user is buyer or seller. */
    @Transactional(readOnly = true)
    public List<ChatRoomDto> listRooms(UUID userId) {
        return roomRepo.findAllByUserId(userId).stream()
                .map(this::mapRoomToDto)
                .collect(Collectors.toList());
    }

    /** Get messages, optionally only those after since timestamp (ISO-8601). */
    @Transactional(readOnly = true)
    public List<ChatMessageDto> getMessages(UUID roomId, UUID currentUserId, String since) {
        validateAccess(roomId, currentUserId);
        List<ChatMessage> msgs = (since != null && !since.isBlank())
                ? messageRepo.findByRoomIdAndCreatedAtAfterOrderByCreatedAtAsc(roomId, Instant.parse(since))
                : messageRepo.findByRoomIdOrderByCreatedAtAsc(roomId);
        return msgs.stream().map(this::mapMsgToDto).collect(Collectors.toList());
    }

    /** Send a TEXT, OFFER, or QUICK_REPLY message. */
    @Transactional
    public ChatMessageDto sendMessage(UUID roomId, UUID senderId, SendMessageRequest req) {
        validateAccess(roomId, senderId);
        ChatRoom room = roomRepo.findById(roomId)
                .orElseThrow(() -> BidlyException.notFound("Chat room not found"));

        ChatMessage msg = new ChatMessage();
        msg.setRoomId(roomId);
        msg.setSenderId(senderId);
        msg.setContent(req.getContent());
        msg.setOfferAmount(req.getOfferAmount());
        try {
            msg.setType(ChatMessage.MessageType.valueOf(
                    req.getType() != null ? req.getType().toUpperCase() : "TEXT"));
        } catch (IllegalArgumentException e) {
            msg.setType(ChatMessage.MessageType.TEXT);
        }

        ChatMessage saved = messageRepo.save(msg);
        room.setLastMessageAt(saved.getCreatedAt());
        roomRepo.save(room);
        return mapMsgToDto(saved);
    }

    // --- Helpers ---

    private void validateAccess(UUID roomId, UUID userId) {
        ChatRoom room = roomRepo.findById(roomId)
                .orElseThrow(() -> BidlyException.notFound("Chat room not found"));
        if (!room.getBuyerId().equals(userId) && !room.getSellerId().equals(userId)) {
            throw BidlyException.unauthorized("Access denied to this chat room");
        }
    }

    private ChatRoomDto mapRoomToDto(ChatRoom r) {
        ChatRoomDto dto = new ChatRoomDto();
        dto.setId(r.getId());
        dto.setListingId(r.getListingId());
        dto.setBuyerId(r.getBuyerId());
        dto.setSellerId(r.getSellerId());
        dto.setStatus(r.getStatus().name());
        dto.setLastMessageAt(r.getLastMessageAt());
        dto.setCreatedAt(r.getCreatedAt());

        listingRepo.findById(r.getListingId()).ifPresent(l -> {
            dto.setListingTitle(l.getTitle());
            dto.setListingPrice(l.getPrice().doubleValue());
            if (l.getMedia() != null && !l.getMedia().isEmpty()) {
                dto.setListingImageUrl(l.getMedia().get(0).getUrl());
            }
        });

        userRepo.findById(r.getBuyerId()).ifPresent(u -> dto.setBuyerName(u.getName()));
        userRepo.findById(r.getSellerId()).ifPresent(u -> dto.setSellerName(u.getName()));

        messageRepo.findTopByRoomIdOrderByCreatedAtDesc(r.getId()).ifPresent(m -> {
            if (m.getType() == ChatMessage.MessageType.OFFER && m.getOfferAmount() != null) {
                dto.setLastMessagePreview("Offer: Rs." + m.getOfferAmount().toPlainString());
            } else if (m.getContent() != null) {
                dto.setLastMessagePreview(m.getContent());
            }
        });
        return dto;
    }

    private ChatMessageDto mapMsgToDto(ChatMessage m) {
        ChatMessageDto dto = new ChatMessageDto();
        dto.setId(m.getId());
        dto.setRoomId(m.getRoomId());
        dto.setSenderId(m.getSenderId());
        dto.setContent(m.getContent());
        dto.setOfferAmount(m.getOfferAmount());
        dto.setType(m.getType().name());
        dto.setCreatedAt(m.getCreatedAt());
        userRepo.findById(m.getSenderId()).ifPresent(u -> dto.setSenderName(u.getName()));
        return dto;
    }
}
