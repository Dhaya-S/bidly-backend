package com.bidly.listing.repository;

import com.bidly.listing.entity.Listing;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ListingRepository extends JpaRepository<Listing, UUID>, JpaSpecificationExecutor<Listing> {

    @EntityGraph(attributePaths = {"category", "seller"})
    Page<Listing> findByStatusOrderByCreatedAtDesc(Listing.ListingStatus status, Pageable pageable);

    @EntityGraph(attributePaths = {"category", "seller"})
    @Query("SELECT l FROM Listing l WHERE l.status = :status AND l.reelUrl IS NOT NULL AND TRIM(l.reelUrl) <> '' AND (l.sellingMethod <> 'AUCTION' OR l.auctionEndTime IS NULL OR l.auctionEndTime > CURRENT_TIMESTAMP) ORDER BY l.createdAt DESC")
    List<Listing> findActiveReels(@Param("status") Listing.ListingStatus status, Pageable pageable);

    @EntityGraph(attributePaths = {"category", "seller"})
    @Query("SELECT l FROM Listing l WHERE l.status = :status AND (l.sellingMethod <> 'AUCTION' OR l.auctionEndTime IS NULL OR l.auctionEndTime > CURRENT_TIMESTAMP) ORDER BY l.createdAt DESC")
    List<Listing> findDealsNearYou(@Param("status") Listing.ListingStatus status, Pageable pageable);

    @EntityGraph(attributePaths = {"category", "seller"})
    List<Listing> findTop8ByStatusOrderByCreatedAtDesc(Listing.ListingStatus status);

    @Query("SELECT u.id, u.name, u.avatarUrl, u.trustScore, COUNT(l.id) " +
           "FROM Listing l JOIN l.seller u " +
           "WHERE l.status = :status " +
           "GROUP BY u.id, u.name, u.avatarUrl, u.trustScore " +
           "ORDER BY COUNT(l.id) DESC")
    List<Object[]> findTopSellersAggregated(@Param("status") Listing.ListingStatus status, Pageable pageable);

    long countBySellerIdAndStatus(UUID sellerId, Listing.ListingStatus status);

    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT l FROM Listing l WHERE l.id = :id")
    java.util.Optional<Listing> findByIdWithPessimisticLock(@Param("id") UUID id);

    @Query("SELECT l FROM Listing l WHERE l.sellingMethod = 'AUCTION' AND l.status = 'ACTIVE' AND l.auctionEndTime IS NOT NULL AND l.auctionEndTime <= :now")
    List<Listing> findExpiredActiveAuctions(@Param("now") java.time.Instant now);

    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE Listing l SET l.likesCount = l.likesCount + 1 WHERE l.id = :id")
    void incrementLikes(@Param("id") UUID id);

    @EntityGraph(attributePaths = {"category", "seller"})
    List<Listing> findBySellerIdOrderByCreatedAtDesc(UUID sellerId);

    @EntityGraph(attributePaths = {"category", "seller"})
    List<Listing> findBySellerIdAndStatusOrderByCreatedAtDesc(UUID sellerId, Listing.ListingStatus status);
}
