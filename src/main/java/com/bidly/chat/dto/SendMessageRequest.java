package com.bidly.chat.dto;

import java.math.BigDecimal;

public class SendMessageRequest {
    private String content;
    private BigDecimal offerAmount;
    private String type = "TEXT"; // TEXT, OFFER, QUICK_REPLY

    public String getContent()                  { return content; }
    public void setContent(String content)      { this.content = content; }
    public BigDecimal getOfferAmount()          { return offerAmount; }
    public void setOfferAmount(BigDecimal v)    { this.offerAmount = v; }
    public String getType()                     { return type; }
    public void setType(String type)            { this.type = type; }
}
