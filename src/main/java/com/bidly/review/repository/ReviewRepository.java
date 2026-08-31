package com.bidly.review.repository;

import com.bidly.review.entity.Review;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ReviewRepository extends JpaRepository<Review, UUID> {
    Optional<Review> findByOrderId(UUID orderId);

    @EntityGraph(attributePaths = {"reviewer", "photos"})
    List<Review> findBySellerIdOrderByCreatedAtDesc(UUID sellerId);

    boolean existsByOrderId(UUID orderId);
}
