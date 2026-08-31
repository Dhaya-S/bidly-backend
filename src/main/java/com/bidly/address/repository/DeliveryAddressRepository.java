package com.bidly.address.repository;

import com.bidly.address.entity.DeliveryAddress;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DeliveryAddressRepository extends JpaRepository<DeliveryAddress, UUID> {
    List<DeliveryAddress> findByUserIdOrderByCreatedAtDesc(UUID userId);
    Optional<DeliveryAddress> findFirstByUserIdAndIsDefaultTrue(UUID userId);
}
