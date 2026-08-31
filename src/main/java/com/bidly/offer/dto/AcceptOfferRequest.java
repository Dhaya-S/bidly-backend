package com.bidly.offer.dto;

import java.time.Instant;
import java.util.UUID;

public class AcceptOfferRequest {

    private String deliveryType = "COURIER"; // COURIER, IN_PERSON_MEETUP
    private UUID addressId;
    private String meetupLocation;
    private Instant meetupTime;

    public AcceptOfferRequest() {}

    public String getDeliveryType() { return deliveryType; }
    public void setDeliveryType(String deliveryType) { this.deliveryType = deliveryType; }

    public UUID getAddressId() { return addressId; }
    public void setAddressId(UUID addressId) { this.addressId = addressId; }

    public String getMeetupLocation() { return meetupLocation; }
    public void setMeetupLocation(String meetupLocation) { this.meetupLocation = meetupLocation; }

    public Instant getMeetupTime() { return meetupTime; }
    public void setMeetupTime(Instant meetupTime) { this.meetupTime = meetupTime; }
}
