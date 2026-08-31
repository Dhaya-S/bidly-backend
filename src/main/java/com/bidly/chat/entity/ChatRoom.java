package com.bidly.chat.entity;

import com.bidly.common.entity.BaseEntity;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "chat_rooms", indexes = {
        @Index(name = "idx_chat_rooms_buyer",   columnList = "buyer_id"),
        @Index(name = "idx_chat_rooms_seller",  columnList = "seller_id"),
        @Index(name = "idx_chat_rooms_listing", columnList = "listing_id")
})
public class ChatRoom extends BaseEntity {

    @Column(name = "listing_id", nullable = false)
    private UUID listingId;

    @Column(name = "buyer_id", nullable = false)
    private UUID buyerId;

    @Column(name = "seller_id", nullable = false)
    private UUID sellerId;

    @Enumerated(EnumType.STRING)
    @Column(length = 20, nullable = false)
    private ChatRoomStatus status = ChatRoomStatus.OPEN;

    @Column(name = "last_message_at")
    private Instant lastMessageAt;

    public UUID getListingId()                  { return listingId; }
    public void setListingId(UUID listingId)    { this.listingId = listingId; }

    public UUID getBuyerId()                    { return buyerId; }
    public void setBuyerId(UUID buyerId)        { this.buyerId = buyerId; }

    public UUID getSellerId()                   { return sellerId; }
    public void setSellerId(UUID sellerId)      { this.sellerId = sellerId; }

    public ChatRoomStatus getStatus()           { return status; }
    public void setStatus(ChatRoomStatus status){ this.status = status; }

    public Instant getLastMessageAt()              { return lastMessageAt; }
    public void setLastMessageAt(Instant ts)       { this.lastMessageAt = ts; }

    public enum ChatRoomStatus { OPEN, CLOSED }
}
