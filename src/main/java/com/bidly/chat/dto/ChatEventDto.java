package com.bidly.chat.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public class ChatEventDto {
    private String eventType; // NEW_MESSAGE, MESSAGE_READ, TYPING_STARTED, TYPING_STOPPED, OFFER_UPDATED, MEETUP_UPDATED, PRESENCE_UPDATE
    private UUID roomId;
    private UUID userId;
    private String userName;
    private ChatMessageDto message;
    private List<UUID> readMessageIds;
    private Instant readAt;
    private UUID offerId;
    private String offerStatus;
    private Double offerAmount;
    private Double counterAmount;
    private String meetupStatus;
    private String meetupLocation;
    private Instant meetupTime;
    private boolean isOnline;
    private Instant lastSeen;
    private Instant timestamp = Instant.now();

    public ChatEventDto() {}

    public static ChatEventDto newMessage(UUID roomId, ChatMessageDto message) {
        ChatEventDto e = new ChatEventDto();
        e.setEventType("NEW_MESSAGE");
        e.setRoomId(roomId);
        e.setMessage(message);
        e.setUserId(message.getSenderId());
        e.setUserName(message.getSenderName());
        return e;
    }

    public static ChatEventDto messageRead(UUID roomId, UUID readerId, Instant readAt, List<UUID> readMessageIds) {
        ChatEventDto e = new ChatEventDto();
        e.setEventType("MESSAGE_READ");
        e.setRoomId(roomId);
        e.setUserId(readerId);
        e.setReadAt(readAt);
        e.setReadMessageIds(readMessageIds);
        return e;
    }

    public static ChatEventDto typingStarted(UUID roomId, UUID userId, String userName) {
        ChatEventDto e = new ChatEventDto();
        e.setEventType("TYPING_STARTED");
        e.setRoomId(roomId);
        e.setUserId(userId);
        e.setUserName(userName);
        return e;
    }

    public static ChatEventDto typingStopped(UUID roomId, UUID userId) {
        ChatEventDto e = new ChatEventDto();
        e.setEventType("TYPING_STOPPED");
        e.setRoomId(roomId);
        e.setUserId(userId);
        return e;
    }

    public static ChatEventDto offerUpdated(UUID roomId, UUID offerId, String status, Double amount, Double counterAmount) {
        ChatEventDto e = new ChatEventDto();
        e.setEventType("OFFER_UPDATED");
        e.setRoomId(roomId);
        e.setOfferId(offerId);
        e.setOfferStatus(status);
        e.setOfferAmount(amount);
        e.setCounterAmount(counterAmount);
        return e;
    }

    public static ChatEventDto meetupUpdated(UUID roomId, String status, String location, Instant meetupTime) {
        ChatEventDto e = new ChatEventDto();
        e.setEventType("MEETUP_UPDATED");
        e.setRoomId(roomId);
        e.setMeetupStatus(status);
        e.setMeetupLocation(location);
        e.setMeetupTime(meetupTime);
        return e;
    }

    public static ChatEventDto presenceUpdate(UUID userId, boolean isOnline, Instant lastSeen) {
        ChatEventDto e = new ChatEventDto();
        e.setEventType("PRESENCE_UPDATE");
        e.setUserId(userId);
        e.setOnline(isOnline);
        e.setLastSeen(lastSeen);
        return e;
    }

    public String getEventType()                 { return eventType; }
    public void setEventType(String v)           { this.eventType = v; }

    public UUID getRoomId()                      { return roomId; }
    public void setRoomId(UUID v)                { this.roomId = v; }

    public UUID getUserId()                      { return userId; }
    public void setUserId(UUID v)                { this.userId = v; }

    public String getUserName()                  { return userName; }
    public void setUserName(String v)            { this.userName = v; }

    public ChatMessageDto getMessage()           { return message; }
    public void setMessage(ChatMessageDto v)     { this.message = v; }

    public List<UUID> getReadMessageIds()        { return readMessageIds; }
    public void setReadMessageIds(List<UUID> v)  { this.readMessageIds = v; }

    public Instant getReadAt()                   { return readAt; }
    public void setReadAt(Instant v)             { this.readAt = v; }

    public UUID getOfferId()                     { return offerId; }
    public void setOfferId(UUID v)               { this.offerId = v; }

    public String getOfferStatus()               { return offerStatus; }
    public void setOfferStatus(String v)         { this.offerStatus = v; }

    public Double getOfferAmount()               { return offerAmount; }
    public void setOfferAmount(Double v)         { this.offerAmount = v; }

    public Double getCounterAmount()             { return counterAmount; }
    public void setCounterAmount(Double v)       { this.counterAmount = v; }

    public String getMeetupStatus()              { return meetupStatus; }
    public void setMeetupStatus(String v)        { this.meetupStatus = v; }

    public String getMeetupLocation()            { return meetupLocation; }
    public void setMeetupLocation(String v)      { this.meetupLocation = v; }

    public Instant getMeetupTime()               { return meetupTime; }
    public void setMeetupTime(Instant v)         { this.meetupTime = v; }

    public boolean isOnline()                    { return isOnline; }
    public void setOnline(boolean v)             { this.isOnline = v; }

    public Instant getLastSeen()                 { return lastSeen; }
    public void setLastSeen(Instant v)           { this.lastSeen = v; }

    public Instant getTimestamp()                { return timestamp; }
    public void setTimestamp(Instant v)          { this.timestamp = v; }
}
