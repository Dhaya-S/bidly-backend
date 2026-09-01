package com.bidly.chat.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "chat_messages", indexes = {
        @Index(name = "idx_chat_messages_room",   columnList = "room_id,created_at"),
        @Index(name = "idx_chat_messages_sender", columnList = "sender_id")
})
public class ChatMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    @Column(name = "room_id", nullable = false)
    private UUID roomId;

    @Column(name = "sender_id", nullable = false)
    private UUID senderId;

    @Column(name = "client_message_id", length = 64)
    private String clientMessageId;

    @Column(columnDefinition = "TEXT")
    private String content;

    @Column(name = "offer_amount", precision = 12, scale = 2)
    private BigDecimal offerAmount;

    @Enumerated(EnumType.STRING)
    @Column(length = 30, nullable = false)
    private MessageType type = MessageType.TEXT;

    @Enumerated(EnumType.STRING)
    @Column(length = 20, nullable = false)
    private MessageStatus status = MessageStatus.SENT;

    @Column(name = "read_at")
    private Instant readAt;

    @Column(name = "media_url", columnDefinition = "TEXT")
    private String mediaUrl;

    @Column(name = "metadata", columnDefinition = "TEXT")
    private String metadata;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public ChatMessage() {}

    public UUID getId()                               { return id; }
    public void setId(UUID id)                        { this.id = id; }

    public UUID getRoomId()                           { return roomId; }
    public void setRoomId(UUID roomId)                { this.roomId = roomId; }

    public UUID getSenderId()                         { return senderId; }
    public void setSenderId(UUID senderId)            { this.senderId = senderId; }

    public String getClientMessageId()                { return clientMessageId; }
    public void setClientMessageId(String clientMessageId) { this.clientMessageId = clientMessageId; }

    public String getContent()                        { return content; }
    public void setContent(String content)            { this.content = content; }

    public BigDecimal getOfferAmount()                { return offerAmount; }
    public void setOfferAmount(BigDecimal amt)        { this.offerAmount = amt; }

    public MessageType getType()                      { return type; }
    public void setType(MessageType type)             { this.type = type; }

    public MessageStatus getStatus()                  { return status; }
    public void setStatus(MessageStatus status)       { this.status = status; }

    public Instant getReadAt()                        { return readAt; }
    public void setReadAt(Instant readAt)             { this.readAt = readAt; }

    public String getMediaUrl()                       { return mediaUrl; }
    public void setMediaUrl(String mediaUrl)          { this.mediaUrl = mediaUrl; }

    public String getMetadata()                       { return metadata; }
    public void setMetadata(String metadata)          { this.metadata = metadata; }

    public Instant getCreatedAt()                     { return createdAt; }
    public void setCreatedAt(Instant createdAt)       { this.createdAt = createdAt; }

    public enum MessageType {
        TEXT,
        IMAGE,
        SYSTEM,
        OFFER,
        OFFER_ACCEPTED,
        OFFER_REJECTED,
        OFFER_COUNTERED,
        MEETUP_REQUEST,
        MEETUP_ACCEPTED,
        MEETUP_REJECTED,
        ORDER_UPDATE,
        DELIVERY_UPDATE,
        QUICK_REPLY
    }

    public enum MessageStatus {
        SENDING,
        SENT,
        DELIVERED,
        READ,
        FAILED
    }
}
