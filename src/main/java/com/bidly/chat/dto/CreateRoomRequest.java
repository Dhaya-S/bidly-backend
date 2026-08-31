package com.bidly.chat.dto;

import java.util.UUID;

public class CreateRoomRequest {
    private UUID listingId;

    public UUID getListingId()              { return listingId; }
    public void setListingId(UUID listingId){ this.listingId = listingId; }
}
