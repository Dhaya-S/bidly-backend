package com.bidly.order.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public class OrderSummaryDto {
    private UUID id;
    private String orderNumber;
    private UUID listingId;
    private String productTitle;
    private String productCondition;
    private String primaryImageUrl;
    private BigDecimal wonAmount;
    private BigDecimal platformFee;
    private BigDecimal totalAmount;
    private String status; // AUCTION_WON, SELLER_CONFIRMED, PACKED, SHIPPED, DELIVERED
    private String paymentStatus; // IN_ESCROW, RELEASED
    private String courierPartner;
    private String trackingNumber;
    private Instant estimatedDeliveryDate;
    private Instant deliveredAt;
    private UUID buyerId;
    private String buyerName;
    private UUID sellerId;
    private String sellerName;
    private Double sellerRating;
    private int sellerSalesCount;
    private String deliveryAddressFullName;
    private String deliveryAddressPhone;
    private String deliveryAddressLine;
    private String deliveryAddressCity;
    private String deliveryAddressPincode;
    private List<OrderTrackingEventDto> trackingTimeline;
    private boolean isReviewed;

    private String orderSource; // AUCTION, DIRECT_SALE
    private String deliveryType; // COURIER, IN_PERSON_MEETUP
    private String meetupLocation;
    private Instant meetupTime;
    private String meetupOtp;
    private Boolean meetupOtpVerified;
    private UUID offerId;
    private boolean isSeller;
    private boolean isBuyer;

    public OrderSummaryDto() {}

    public String getOrderSource() { return orderSource; }
    public void setOrderSource(String orderSource) { this.orderSource = orderSource; }

    public String getDeliveryType() { return deliveryType; }
    public void setDeliveryType(String deliveryType) { this.deliveryType = deliveryType; }

    public String getMeetupLocation() { return meetupLocation; }
    public void setMeetupLocation(String meetupLocation) { this.meetupLocation = meetupLocation; }

    public Instant getMeetupTime() { return meetupTime; }
    public void setMeetupTime(Instant meetupTime) { this.meetupTime = meetupTime; }

    public String getMeetupOtp() { return meetupOtp; }
    public void setMeetupOtp(String meetupOtp) { this.meetupOtp = meetupOtp; }

    public Boolean getMeetupOtpVerified() { return meetupOtpVerified; }
    public void setMeetupOtpVerified(Boolean meetupOtpVerified) { this.meetupOtpVerified = meetupOtpVerified; }

    public UUID getOfferId() { return offerId; }
    public void setOfferId(UUID offerId) { this.offerId = offerId; }

    public boolean isSeller() { return isSeller; }
    public void setSeller(boolean seller) { isSeller = seller; }

    public boolean isBuyer() { return isBuyer; }
    public void setBuyer(boolean buyer) { isBuyer = buyer; }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getOrderNumber() { return orderNumber; }
    public void setOrderNumber(String orderNumber) { this.orderNumber = orderNumber; }

    public UUID getListingId() { return listingId; }
    public void setListingId(UUID listingId) { this.listingId = listingId; }

    public String getProductTitle() { return productTitle; }
    public void setProductTitle(String productTitle) { this.productTitle = productTitle; }

    public String getProductCondition() { return productCondition; }
    public void setProductCondition(String productCondition) { this.productCondition = productCondition; }

    public String getPrimaryImageUrl() { return primaryImageUrl; }
    public void setPrimaryImageUrl(String primaryImageUrl) { this.primaryImageUrl = primaryImageUrl; }

    public BigDecimal getWonAmount() { return wonAmount; }
    public void setWonAmount(BigDecimal wonAmount) { this.wonAmount = wonAmount; }

    public BigDecimal getPlatformFee() { return platformFee; }
    public void setPlatformFee(BigDecimal platformFee) { this.platformFee = platformFee; }

    public BigDecimal getTotalAmount() { return totalAmount; }
    public void setTotalAmount(BigDecimal totalAmount) { this.totalAmount = totalAmount; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getPaymentStatus() { return paymentStatus; }
    public void setPaymentStatus(String paymentStatus) { this.paymentStatus = paymentStatus; }

    public String getCourierPartner() { return courierPartner; }
    public void setCourierPartner(String courierPartner) { this.courierPartner = courierPartner; }

    public String getTrackingNumber() { return trackingNumber; }
    public void setTrackingNumber(String trackingNumber) { this.trackingNumber = trackingNumber; }

    public Instant getEstimatedDeliveryDate() { return estimatedDeliveryDate; }
    public void setEstimatedDeliveryDate(Instant estimatedDeliveryDate) { this.estimatedDeliveryDate = estimatedDeliveryDate; }

    public Instant getDeliveredAt() { return deliveredAt; }
    public void setDeliveredAt(Instant deliveredAt) { this.deliveredAt = deliveredAt; }

    public UUID getBuyerId() { return buyerId; }
    public void setBuyerId(UUID buyerId) { this.buyerId = buyerId; }

    public String getBuyerName() { return buyerName; }
    public void setBuyerName(String buyerName) { this.buyerName = buyerName; }

    public UUID getSellerId() { return sellerId; }
    public void setSellerId(UUID sellerId) { this.sellerId = sellerId; }

    public String getSellerName() { return sellerName; }
    public void setSellerName(String sellerName) { this.sellerName = sellerName; }

    public Double getSellerRating() { return sellerRating; }
    public void setSellerRating(Double sellerRating) { this.sellerRating = sellerRating; }

    public int getSellerSalesCount() { return sellerSalesCount; }
    public void setSellerSalesCount(int sellerSalesCount) { this.sellerSalesCount = sellerSalesCount; }

    public String getDeliveryAddressFullName() { return deliveryAddressFullName; }
    public void setDeliveryAddressFullName(String deliveryAddressFullName) { this.deliveryAddressFullName = deliveryAddressFullName; }

    public String getDeliveryAddressPhone() { return deliveryAddressPhone; }
    public void setDeliveryAddressPhone(String deliveryAddressPhone) { this.deliveryAddressPhone = deliveryAddressPhone; }

    public String getDeliveryAddressLine() { return deliveryAddressLine; }
    public void setDeliveryAddressLine(String deliveryAddressLine) { this.deliveryAddressLine = deliveryAddressLine; }

    public String getDeliveryAddressCity() { return deliveryAddressCity; }
    public void setDeliveryAddressCity(String deliveryAddressCity) { this.deliveryAddressCity = deliveryAddressCity; }

    public String getDeliveryAddressPincode() { return deliveryAddressPincode; }
    public void setDeliveryAddressPincode(String deliveryAddressPincode) { this.deliveryAddressPincode = deliveryAddressPincode; }

    public List<OrderTrackingEventDto> getTrackingTimeline() { return trackingTimeline; }
    public void setTrackingTimeline(List<OrderTrackingEventDto> trackingTimeline) { this.trackingTimeline = trackingTimeline; }

    public boolean isReviewed() { return isReviewed; }
    public void setReviewed(boolean reviewed) { isReviewed = reviewed; }
}
