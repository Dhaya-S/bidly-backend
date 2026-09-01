package com.bidly.chat.dto;

import java.math.BigDecimal;

public class SendMessageRequest {
    private String clientMessageId;
    private String content;
    private BigDecimal offerAmount;
    private String type = "TEXT"; // TEXT, IMAGE, SYSTEM, OFFER, MEETUP_REQUEST, QUICK_REPLY, etc.
    private String mediaUrl;
    private String metadata;

    public SendMessageRequest() {}

    public SendMessageRequest(String clientMessageId, String content, String type) {
        this.clientMessageId = clientMessageId;
        this.content = content;
        this.type = type;
    }

    public String getClientMessageId()          { return clientMessageId; }
    public void setClientMessageId(String v)    { this.clientMessageId = v; }

    public String getContent()                  { return content; }
    public void setContent(String content)      { this.content = content; }

    public BigDecimal getOfferAmount()          { return offerAmount; }
    public void setOfferAmount(BigDecimal v)    { this.offerAmount = v; }

    public String getType()                     { return type; }
    public void setType(String type)            { this.type = type; }

    public String getMediaUrl()                 { return mediaUrl; }
    public void setMediaUrl(String mediaUrl)    { this.mediaUrl = mediaUrl; }

    public String getMetadata()                 { return metadata; }
    public void setMetadata(String metadata)    { this.metadata = metadata; }
}
