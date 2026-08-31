package com.bidly.order.repository;

import com.bidly.order.entity.Order;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrderRepository extends JpaRepository<Order, UUID> {

    @EntityGraph(attributePaths = {"listing", "buyer", "seller", "deliveryAddress"})
    Optional<Order> findByOrderNumber(String orderNumber);

    @EntityGraph(attributePaths = {"listing", "buyer", "seller", "deliveryAddress"})
    Optional<Order> findFirstByListingIdOrderByCreatedAtDesc(UUID listingId);

    @EntityGraph(attributePaths = {"listing", "buyer", "seller", "deliveryAddress"})
    Optional<Order> findByOfferId(UUID offerId);

    @EntityGraph(attributePaths = {"listing", "buyer", "seller"})
    List<Order> findByBuyerIdOrderByCreatedAtDesc(UUID buyerId);

    @EntityGraph(attributePaths = {"listing", "buyer", "seller"})
    List<Order> findBySellerIdOrderByCreatedAtDesc(UUID sellerId);
}
