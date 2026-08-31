package com.bidly.order.entity;

import com.bidly.common.entity.BaseEntity;
import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "order_tracking_events", indexes = {
        @Index(name = "idx_tracking_order", columnList = "order_id")
})
public class OrderTrackingEvent extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private Order.OrderStatus status;

    @Column(nullable = false, length = 100)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "event_time", nullable = false)
    private Instant eventTime = Instant.now();

    public OrderTrackingEvent() {}

    public OrderTrackingEvent(Order order, Order.OrderStatus status, String title, String description, Instant eventTime) {
        this.order = order;
        this.status = status;
        this.title = title;
        this.description = description;
        this.eventTime = eventTime != null ? eventTime : Instant.now();
    }

    public Order getOrder() { return order; }
    public void setOrder(Order order) { this.order = order; }

    public Order.OrderStatus getStatus() { return status; }
    public void setStatus(Order.OrderStatus status) { this.status = status; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Instant getEventTime() { return eventTime; }
    public void setEventTime(Instant eventTime) { this.eventTime = eventTime; }
}
