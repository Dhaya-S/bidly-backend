package com.bidly.chat.service;

import com.bidly.chat.dto.*;
import com.bidly.chat.entity.ChatMessage;
import com.bidly.chat.entity.ChatRoom;
import com.bidly.chat.repository.ChatMessageRepository;
import com.bidly.chat.repository.ChatRoomRepository;
import com.bidly.common.exception.BidlyException;
import com.bidly.listing.entity.Listing;
import com.bidly.listing.repository.ListingRepository;
import com.bidly.media.service.MediaService;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class ChatService {

    private static final Logger log = LoggerFactory.getLogger(ChatService.class);

    private final ChatRoomRepository roomRepo;
    private final ChatMessageRepository messageRepo;
    private final ListingRepository listingRepo;
    private final UserRepository userRepo;
    private final MediaService mediaService;
    private final SimpMessagingTemplate messagingTemplate;

    public ChatService(ChatRoomRepository roomRepo,
                       ChatMessageRepository messageRepo,
                       ListingRepository listingRepo,
                       UserRepository userRepo,
                       MediaService mediaService,
                       SimpMessagingTemplate messagingTemplate) {
        this.roomRepo          = roomRepo;
        this.messageRepo       = messageRepo;
        this.listingRepo       = listingRepo;
        this.userRepo          = userRepo;
        this.mediaService      = mediaService;
        this.messagingTemplate = messagingTemplate;
    }

    @Transactional
    public ChatRoomDto getOrCreateRoom(UUID listingId, UUID buyerId) {
        if (buyerId == null) {
            throw BidlyException.unauthorized("Authentication required to use chat");
        }
        return roomRepo.findByListingIdAndBuyerId(listingId, buyerId)
                .map(r -> mapRoomToDto(r, buyerId))
                .orElseGet(() -> {
                    Listing listing = listingRepo.findById(listingId)
                            .orElseThrow(() -> BidlyException.notFound("Listing not found"));
                    ChatRoom room = new ChatRoom();
                    room.setListingId(listingId);
                    room.setBuyerId(buyerId);
                    room.setSellerId(listing.getSeller() != null ? listing.getSeller().getId() : buyerId);
                    ChatRoom saved = roomRepo.save(room);
                    return mapRoomToDto(saved, buyerId);
                });
    }

    /** List all chat rooms where user is buyer or seller with unread counts. */
    @Transactional(readOnly = true)
    public List<ChatRoomDto> listRooms(UUID userId) {
        if (userId == null) {
            throw BidlyException.unauthorized("Authentication required");
        }
        return roomRepo.findAllByUserId(userId).stream()
                .map(r -> mapRoomToDto(r, userId))
                .collect(Collectors.toList());
    }

    /** Get deterministic messages with keyset pagination support. */
    @Transactional(readOnly = true)
    public List<ChatMessageDto> getMessages(UUID roomId, UUID currentUserId, Instant beforeCreatedAt, UUID beforeId, Integer limit) {
        validateAccess(roomId, currentUserId);
        int pageSize = (limit != null && limit > 0 && limit <= 100) ? limit : 50;

        List<ChatMessage> msgs;
        if (beforeCreatedAt != null && beforeId != null) {
            msgs = messageRepo.findOlderMessages(roomId, beforeCreatedAt, beforeId, PageRequest.of(0, pageSize));
            // Reverse so they are returned in ascending order
            Collections.reverse(msgs);
        } else {
            msgs = messageRepo.findByRoomIdOrderByCreatedAtAscIdAsc(roomId);
            if (msgs.size() > pageSize) {
                msgs = msgs.subList(msgs.size() - pageSize, msgs.size());
            }
        }

        return msgs.stream().map(m -> mapMsgToDto(m, currentUserId)).collect(Collectors.toList());
    }

    /**
     * Send a message with clientMessageId idempotency and post-commit WebSocket broadcast.
     */
    @Transactional
    public ChatMessageDto sendMessage(UUID roomId, UUID senderId, SendMessageRequest req) {
        validateAccess(roomId, senderId);
        ChatRoom room = roomRepo.findById(roomId)
                .orElseThrow(() -> BidlyException.notFound("Chat room not found"));

        // Idempotency check: if clientMessageId already exists in this room, return existing
        if (req.getClientMessageId() != null && !req.getClientMessageId().trim().isEmpty()) {
            Optional<ChatMessage> existing = messageRepo.findByRoomIdAndClientMessageId(roomId, req.getClientMessageId().trim());
            if (existing.isPresent()) {
                log.info("[CHAT_IDEMPOTENT] Returning existing message {} for clientMessageId {}",
                        existing.get().getId(), req.getClientMessageId());
                return mapMsgToDto(existing.get(), senderId);
            }
        }

        ChatMessage msg = new ChatMessage();
        msg.setRoomId(roomId);
        msg.setSenderId(senderId);
        msg.setClientMessageId(req.getClientMessageId() != null ? req.getClientMessageId().trim() : null);
        msg.setContent(req.getContent());
        msg.setOfferAmount(req.getOfferAmount());
        msg.setMediaUrl(req.getMediaUrl());
        msg.setMetadata(req.getMetadata());
        msg.setStatus(ChatMessage.MessageStatus.SENT);

        try {
            msg.setType(ChatMessage.MessageType.valueOf(
                    req.getType() != null ? req.getType().toUpperCase() : "TEXT"));
        } catch (IllegalArgumentException e) {
            msg.setType(ChatMessage.MessageType.TEXT);
        }

        ChatMessage saved = messageRepo.save(msg);
        room.setLastMessageAt(saved.getCreatedAt());
        room.setUpdatedAt(Instant.now());
        roomRepo.save(room);

        ChatMessageDto dto = mapMsgToDto(saved, senderId);
        UUID receiverId = room.getBuyerId().equals(senderId) ? room.getSellerId() : room.getBuyerId();

        // Broadcast to STOMP topic after database commit
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    broadcastMessageEvent(roomId, receiverId, dto);
                }
            });
        } else {
            broadcastMessageEvent(roomId, receiverId, dto);
        }

        return dto;
    }

    private void broadcastMessageEvent(UUID roomId, UUID receiverId, ChatMessageDto dto) {
        try {
            ChatEventDto event = ChatEventDto.newMessage(roomId, dto);
            messagingTemplate.convertAndSend("/topic/chats/" + roomId, event);
            messagingTemplate.convertAndSend("/topic/users/" + receiverId + "/chat", event);
            log.info("[CHAT_WS] BROADCAST message roomId={} msgId={} sender={}", roomId, dto.getId(), dto.getSenderId());
        } catch (Exception e) {
            log.warn("[CHAT_WS] Failed to broadcast message: {}", e.getMessage());
        }
    }

    /**
     * Mark all unread messages in room as READ and broadcast read receipts.
     */
    @Transactional
    public void markRoomMessagesAsRead(UUID roomId, UUID readerId) {
        validateAccess(roomId, readerId);
        List<ChatMessage> unread = messageRepo.findUnreadMessagesInRoom(roomId, readerId);
        if (unread.isEmpty()) {
            return;
        }

        Instant now = Instant.now();
        List<UUID> readIds = new ArrayList<>();
        for (ChatMessage m : unread) {
            m.setStatus(ChatMessage.MessageStatus.READ);
            m.setReadAt(now);
            readIds.add(m.getId());
        }
        messageRepo.saveAll(unread);

        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    try {
                        ChatEventDto event = ChatEventDto.messageRead(roomId, readerId, now, readIds);
                        messagingTemplate.convertAndSend("/topic/chats/" + roomId, event);
                        log.info("[CHAT_WS] BROADCAST read receipt roomId={} count={}", roomId, readIds.size());
                    } catch (Exception e) {
                        log.warn("[CHAT_WS] Failed to broadcast read receipt: {}", e.getMessage());
                    }
                }
            });
        }
    }

    /**
     * Send ephemeral typing indicator to WebSocket topic without storing in DB.
     */
    public void sendTypingIndicator(UUID roomId, UUID userId, boolean isTyping) {
        validateAccess(roomId, userId);
        String userName = userRepo.findById(userId).map(User::getName).orElse("User");
        ChatEventDto event = isTyping
                ? ChatEventDto.typingStarted(roomId, userId, userName)
                : ChatEventDto.typingStopped(roomId, userId);

        messagingTemplate.convertAndSend("/topic/chats/" + roomId, event);
        log.debug("[CHAT_WS] Ephemeral typing event: {} user: {} room: {}", event.getEventType(), userId, roomId);
    }

    // --- Helpers ---

    private void validateAccess(UUID roomId, UUID userId) {
        ChatRoom room = roomRepo.findById(roomId)
                .orElseThrow(() -> BidlyException.notFound("Chat room not found: " + roomId));
        if (!room.getBuyerId().equals(userId) && !room.getSellerId().equals(userId)) {
            throw BidlyException.forbidden("Access denied to this chat room");
        }
    }

    private ChatRoomDto mapRoomToDto(ChatRoom r, UUID currentUserId) {
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
            dto.setListingPrice(l.getPrice() != null ? l.getPrice().doubleValue() : 0.0);
            if (l.getMedia() != null && !l.getMedia().isEmpty()) {
                String presigned = mediaService.generatePresignedGetUrl(l.getMedia().get(0).getUrl(), Duration.ofHours(4));
                dto.setListingImageUrl(presigned != null ? presigned : l.getMedia().get(0).getUrl());
            }
        });

        userRepo.findById(r.getBuyerId()).ifPresent(u -> dto.setBuyerName(u.getName()));
        userRepo.findById(r.getSellerId()).ifPresent(u -> dto.setSellerName(u.getName()));

        boolean isBuyer = currentUserId.equals(r.getBuyerId());
        UUID otherId = isBuyer ? r.getSellerId() : r.getBuyerId();
        String otherName = isBuyer ? dto.getSellerName() : dto.getBuyerName();
        dto.setOtherUserId(otherId);
        dto.setOtherUserName(otherName != null ? otherName : (isBuyer ? "Seller" : "Buyer"));
        dto.setOtherUserRole(isBuyer ? "Seller" : "Buyer");

        long unread = messageRepo.countUnreadInRoom(r.getId(), currentUserId);
        dto.setUnreadCount((int) unread);

        messageRepo.findTopByRoomIdOrderByCreatedAtDesc(r.getId()).ifPresent(m -> {
            if (m.getType() == ChatMessage.MessageType.OFFER && m.getOfferAmount() != null) {
                dto.setLastMessagePreview("Offer: ₹" + m.getOfferAmount().toBigInteger());
            } else if (m.getType() == ChatMessage.MessageType.MEETUP_REQUEST) {
                dto.setLastMessagePreview("📅 In-Person Meetup Request");
            } else if (m.getType() == ChatMessage.MessageType.IMAGE) {
                dto.setLastMessagePreview("📷 Photo attachment");
            } else if (m.getContent() != null) {
                dto.setLastMessagePreview(m.getContent());
            }
        });
        return dto;
    }

    private ChatMessageDto mapMsgToDto(ChatMessage m, UUID currentUserId) {
        ChatMessageDto dto = new ChatMessageDto();
        dto.setId(m.getId());
        dto.setRoomId(m.getRoomId());
        dto.setSenderId(m.getSenderId());
        dto.setClientMessageId(m.getClientMessageId());
        dto.setContent(m.getContent());
        dto.setOfferAmount(m.getOfferAmount());
        dto.setType(m.getType().name());
        dto.setStatus(m.getStatus().name());
        dto.setReadAt(m.getReadAt());
        dto.setMediaUrl(m.getMediaUrl());
        dto.setMetadata(m.getMetadata());
        dto.setMine(currentUserId != null && m.getSenderId().equals(currentUserId));
        dto.setCreatedAt(m.getCreatedAt());

        userRepo.findById(m.getSenderId()).ifPresent(u -> dto.setSenderName(u.getName()));
        return dto;
    }
}
