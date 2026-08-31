package com.bidly.order.entity;

import com.bidly.address.entity.DeliveryAddress;
import com.bidly.auction.entity.Bid;
import com.bidly.common.entity.BaseEntity;
import com.bidly.listing.entity.Listing;
import com.bidly.user.entity.User;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "orders", indexes = {
        @Index(name = "idx_orders_buyer", columnList = "buyer_id"),
        @Index(name = "idx_orders_seller", columnList = "seller_id"),
        @Index(name = "idx_orders_listing", columnList = "listing_id"),
        @Index(name = "idx_orders_status", columnList = "status")
})
public class Order extends BaseEntity {

    @Column(name = "order_number", nullable = false, unique = true, length = 50)
    private String orderNumber;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "listing_id", nullable = false)
    private Listing listing;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "buyer_id", nullable = false)
    private User buyer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "seller_id", nullable = false)
    private User seller;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "winning_bid_id")
    private Bid winningBid;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "offer_id")
    private com.bidly.offer.entity.Offer offer;

    @Enumerated(EnumType.STRING)
    @Column(name = "order_source", nullable = false, length = 30)
    private OrderSource orderSource = OrderSource.AUCTION;

    @Enumerated(EnumType.STRING)
    @Column(name = "delivery_type", nullable = false, length = 30)
    private DeliveryType deliveryType = DeliveryType.COURIER;

    @Column(name = "meetup_location", length = 255)
    private String meetupLocation;

    @Column(name = "meetup_time")
    private Instant meetupTime;

    @Column(name = "meetup_otp", length = 10)
    private String meetupOtp;

    @Column(name = "meetup_otp_verified")
    private Boolean meetupOtpVerified = false;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "delivery_address_id")
    private DeliveryAddress deliveryAddress;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Column(name = "platform_fee", nullable = false, precision = 12, scale = 2)
    private BigDecimal platformFee = BigDecimal.ZERO;

    @Column(name = "total_amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal totalAmount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private OrderStatus status = OrderStatus.AUCTION_WON;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_status", nullable = false, length = 30)
    private PaymentStatus paymentStatus = PaymentStatus.IN_ESCROW;

    @Column(name = "courier_partner", length = 100)
    private String courierPartner = "Ekart Logistics";

    @Column(name = "tracking_number", length = 100)
    private String trackingNumber;

    @Column(name = "estimated_delivery_date")
    private Instant estimatedDeliveryDate;

    @Column(name = "delivered_at")
    private Instant deliveredAt;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("eventTime ASC")
    private List<OrderTrackingEvent> trackingEvents = new ArrayList<>();

    public enum OrderSource {
        AUCTION, DIRECT_SALE
    }

    public enum DeliveryType {
        COURIER, IN_PERSON_MEETUP
    }

    public enum OrderStatus {
        AUCTION_WON, ORDER_CONFIRMED, SELLER_CONFIRMED, PACKED, SHIPPED, DELIVERED, CANCELLED
    }

    public enum PaymentStatus {
        PENDING, IN_ESCROW, RELEASED, REFUNDED
    }

    public Order() {}

    public Order(String orderNumber, Listing listing, User buyer, User seller, Bid winningBid, DeliveryAddress deliveryAddress, BigDecimal amount, BigDecimal platformFee, BigDecimal totalAmount) {
        this.orderNumber = orderNumber;
        this.listing = listing;
        this.buyer = buyer;
        this.seller = seller;
        this.winningBid = winningBid;
        this.deliveryAddress = deliveryAddress;
        this.amount = amount;
        this.platformFee = platformFee;
        this.totalAmount = totalAmount;
        this.orderSource = OrderSource.AUCTION;
        this.status = OrderStatus.AUCTION_WON;
        this.paymentStatus = PaymentStatus.IN_ESCROW;
    }

    public String getOrderNumber() { return orderNumber; }
    public void setOrderNumber(String orderNumber) { this.orderNumber = orderNumber; }

    public Listing getListing() { return listing; }
    public void setListing(Listing listing) { this.listing = listing; }

    public User getBuyer() { return buyer; }
    public void setBuyer(User buyer) { this.buyer = buyer; }

    public User getSeller() { return seller; }
    public void setSeller(User seller) { this.seller = seller; }

    public Bid getWinningBid() { return winningBid; }
    public void setWinningBid(Bid winningBid) { this.winningBid = winningBid; }

    public com.bidly.offer.entity.Offer getOffer() { return offer; }
    public void setOffer(com.bidly.offer.entity.Offer offer) { this.offer = offer; }

    public OrderSource getOrderSource() { return orderSource; }
    public void setOrderSource(OrderSource orderSource) { this.orderSource = orderSource; }

    public DeliveryType getDeliveryType() { return deliveryType; }
    public void setDeliveryType(DeliveryType deliveryType) { this.deliveryType = deliveryType; }

    public String getMeetupLocation() { return meetupLocation; }
    public void setMeetupLocation(String meetupLocation) { this.meetupLocation = meetupLocation; }

    public Instant getMeetupTime() { return meetupTime; }
    public void setMeetupTime(Instant meetupTime) { this.meetupTime = meetupTime; }

    public String getMeetupOtp() { return meetupOtp; }
    public void setMeetupOtp(String meetupOtp) { this.meetupOtp = meetupOtp; }

    public Boolean getMeetupOtpVerified() { return meetupOtpVerified; }
    public void setMeetupOtpVerified(Boolean meetupOtpVerified) { this.meetupOtpVerified = meetupOtpVerified; }

    public DeliveryAddress getDeliveryAddress() { return deliveryAddress; }
    public void setDeliveryAddress(DeliveryAddress deliveryAddress) { this.deliveryAddress = deliveryAddress; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public BigDecimal getPlatformFee() { return platformFee; }
    public void setPlatformFee(BigDecimal platformFee) { this.platformFee = platformFee; }

    public BigDecimal getTotalAmount() { return totalAmount; }
    public void setTotalAmount(BigDecimal totalAmount) { this.totalAmount = totalAmount; }

    public OrderStatus getStatus() { return status; }
    public void setStatus(OrderStatus status) { this.status = status; }

    public PaymentStatus getPaymentStatus() { return paymentStatus; }
    public void setPaymentStatus(PaymentStatus paymentStatus) { this.paymentStatus = paymentStatus; }

    public String getCourierPartner() { return courierPartner; }
    public void setCourierPartner(String courierPartner) { this.courierPartner = courierPartner; }

    public String getTrackingNumber() { return trackingNumber; }
    public void setTrackingNumber(String trackingNumber) { this.trackingNumber = trackingNumber; }

    public Instant getEstimatedDeliveryDate() { return estimatedDeliveryDate; }
    public void setEstimatedDeliveryDate(Instant estimatedDeliveryDate) { this.estimatedDeliveryDate = estimatedDeliveryDate; }

    public Instant getDeliveredAt() { return deliveredAt; }
    public void setDeliveredAt(Instant deliveredAt) { this.deliveredAt = deliveredAt; }

    public List<OrderTrackingEvent> getTrackingEvents() { return trackingEvents; }
    public void setTrackingEvents(List<OrderTrackingEvent> trackingEvents) { this.trackingEvents = trackingEvents; }
}
