package com.bidly.chat.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public class ChatMessageDto {
    private UUID id;
    private UUID roomId;
    private UUID senderId;
    private String senderName;
    private String content;
    private BigDecimal offerAmount;
    private String type;
    private Instant createdAt;

    public UUID getId()                        { return id; }
    public void setId(UUID id)                 { this.id = id; }
    public UUID getRoomId()                    { return roomId; }
    public void setRoomId(UUID v)              { this.roomId = v; }
    public UUID getSenderId()                  { return senderId; }
    public void setSenderId(UUID v)            { this.senderId = v; }
    public String getSenderName()              { return senderName; }
    public void setSenderName(String v)        { this.senderName = v; }
    public String getContent()                 { return content; }
    public void setContent(String v)           { this.content = v; }
    public BigDecimal getOfferAmount()         { return offerAmount; }
    public void setOfferAmount(BigDecimal v)   { this.offerAmount = v; }
    public String getType()                    { return type; }
    public void setType(String v)              { this.type = v; }
    public Instant getCreatedAt()              { return createdAt; }
    public void setCreatedAt(Instant v)        { this.createdAt = v; }
}
