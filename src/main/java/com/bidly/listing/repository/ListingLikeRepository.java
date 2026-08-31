package com.bidly.listing.repository;

import com.bidly.listing.entity.ListingLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.Set;
import java.util.UUID;

@Repository
public interface ListingLikeRepository extends JpaRepository<ListingLike, UUID> {

    boolean existsByUserIdAndListingId(UUID userId, UUID listingId);

    void deleteByUserIdAndListingId(UUID userId, UUID listingId);

    long countByListingId(UUID listingId);

    @Query("SELECT l.listingId FROM ListingLike l WHERE l.userId = :userId AND l.listingId IN :listingIds")
    Set<UUID> findListingIdsByUserIdAndListingIdIn(
            @Param("userId") UUID userId,
            @Param("listingIds") Collection<UUID> listingIds
    );
}
