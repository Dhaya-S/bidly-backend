package com.bidly.order.repository;

import com.bidly.order.entity.OrderTrackingEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface OrderTrackingEventRepository extends JpaRepository<OrderTrackingEvent, UUID> {
    List<OrderTrackingEvent> findByOrderIdOrderByEventTimeAsc(UUID orderId);
}
