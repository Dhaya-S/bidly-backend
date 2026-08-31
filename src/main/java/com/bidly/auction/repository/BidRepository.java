package com.bidly.auction.repository;

import com.bidly.auction.entity.Bid;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BidRepository extends JpaRepository<Bid, UUID> {

    @EntityGraph(attributePaths = {"bidder"})
    List<Bid> findByListingIdOrderByAmountDescCreatedAtDesc(UUID listingId);

    @EntityGraph(attributePaths = {"bidder"})
    Optional<Bid> findFirstByListingIdOrderByAmountDescCreatedAtDesc(UUID listingId);

    @EntityGraph(attributePaths = {"bidder"})
    Optional<Bid> findFirstByListingIdAndBidderIdOrderByAmountDescCreatedAtDesc(UUID listingId, UUID bidderId);

    long countByListingId(UUID listingId);

    @Query("SELECT COUNT(b) FROM Bid b WHERE b.listing.id = :listingId AND b.amount > :amount")
    long countBidsHigherThan(@Param("listingId") UUID listingId, @Param("amount") java.math.BigDecimal amount);

    List<Bid> findByListingIdAndStatus(UUID listingId, Bid.BidStatus status);
}
