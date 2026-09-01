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
    List<Bid> findByListingIdAndStatusNotOrderByAmountDescCreatedAtDesc(UUID listingId, Bid.BidStatus status);

    @EntityGraph(attributePaths = {"bidder"})
    Optional<Bid> findFirstByListingIdOrderByAmountDescCreatedAtDesc(UUID listingId);

    @EntityGraph(attributePaths = {"bidder"})
    Optional<Bid> findFirstByListingIdAndStatusOrderByAmountDescCreatedAtDesc(UUID listingId, Bid.BidStatus status);

    @EntityGraph(attributePaths = {"bidder"})
    Optional<Bid> findFirstByListingIdAndStatusInOrderByAmountDescCreatedAtDesc(UUID listingId, java.util.Collection<Bid.BidStatus> statuses);

    @EntityGraph(attributePaths = {"bidder"})
    Optional<Bid> findFirstByListingIdAndBidderIdOrderByAmountDescCreatedAtDesc(UUID listingId, UUID bidderId);

    @EntityGraph(attributePaths = {"bidder"})
    Optional<Bid> findFirstByListingIdAndBidderIdAndStatusOrderByAmountDescCreatedAtDesc(UUID listingId, UUID bidderId, Bid.BidStatus status);

    @EntityGraph(attributePaths = {"bidder"})
    Optional<Bid> findFirstByListingIdAndBidderIdAndStatusInOrderByAmountDescCreatedAtDesc(UUID listingId, UUID bidderId, java.util.Collection<Bid.BidStatus> statuses);

    long countByListingId(UUID listingId);

    long countByListingIdAndStatusNot(UUID listingId, Bid.BidStatus status);

    @Query("SELECT COUNT(b) FROM Bid b WHERE b.listing.id = :listingId AND b.amount > :amount AND b.status <> 'WITHDRAWN'")
    long countBidsHigherThan(@Param("listingId") UUID listingId, @Param("amount") java.math.BigDecimal amount);

    List<Bid> findByListingIdAndStatus(UUID listingId, Bid.BidStatus status);

    Optional<Bid> findByClientBidId(String clientBidId);
}
