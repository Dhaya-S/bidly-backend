package com.bidly.listing.repository;

import com.bidly.listing.entity.ListingLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Repository
public interface ListingLikeRepository extends JpaRepository<ListingLike, UUID> {

    boolean existsByUserIdAndListingId(UUID userId, UUID listingId);

    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("DELETE FROM ListingLike l WHERE l.userId = :userId AND l.listingId = :listingId")
    void deleteByUserIdAndListingId(@Param("userId") UUID userId, @Param("listingId") UUID listingId);

    long countByListingId(UUID listingId);

    @Query("SELECT l.listingId FROM ListingLike l WHERE l.userId = :userId AND l.listingId IN :listingIds")
    Set<UUID> findListingIdsByUserIdAndListingIdIn(
            @Param("userId") UUID userId,
            @Param("listingIds") Collection<UUID> listingIds
    );

    @Query("SELECT l.listingId FROM ListingLike l WHERE l.userId = :userId ORDER BY l.createdAt DESC")
    List<UUID> findListingIdsByUserId(@Param("userId") UUID userId);
}
