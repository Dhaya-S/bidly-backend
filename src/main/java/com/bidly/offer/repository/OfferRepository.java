package com.bidly.offer.repository;

import com.bidly.offer.entity.Offer;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OfferRepository extends JpaRepository<Offer, UUID> {

    Optional<Offer> findFirstByListingIdAndBuyerIdOrderByCreatedAtDesc(UUID listingId, UUID buyerId);

    List<Offer> findByListingIdOrderByCreatedAtDesc(UUID listingId);

    List<Offer> findByListingIdAndStatus(UUID listingId, Offer.OfferStatus status);

    List<Offer> findBySellerIdOrderByCreatedAtDesc(UUID sellerId);

    List<Offer> findByBuyerIdOrderByCreatedAtDesc(UUID buyerId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT o FROM Offer o WHERE o.id = :id")
    Optional<Offer> findByIdWithPessimisticLock(@Param("id") UUID id);
}
