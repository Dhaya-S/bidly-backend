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

    @Column(columnDefinition = "TEXT")
    private String content;

    @Column(name = "offer_amount", precision = 12, scale = 2)
    private BigDecimal offerAmount;

    @Enumerated(EnumType.STRING)
    @Column(length = 20, nullable = false)
    private MessageType type = MessageType.TEXT;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public UUID getId()                         { return id; }
    public UUID getRoomId()                     { return roomId; }
    public void setRoomId(UUID roomId)          { this.roomId = roomId; }
    public UUID getSenderId()                   { return senderId; }
    public void setSenderId(UUID senderId)      { this.senderId = senderId; }
    public String getContent()                  { return content; }
    public void setContent(String content)      { this.content = content; }
    public BigDecimal getOfferAmount()          { return offerAmount; }
    public void setOfferAmount(BigDecimal amt)  { this.offerAmount = amt; }
    public MessageType getType()                { return type; }
    public void setType(MessageType type)       { this.type = type; }
    public Instant getCreatedAt()               { return createdAt; }

    public enum MessageType { TEXT, OFFER, QUICK_REPLY }
}
