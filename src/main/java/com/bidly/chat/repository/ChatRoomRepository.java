package com.bidly.chat.repository;

import com.bidly.chat.entity.ChatRoom;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ChatRoomRepository extends JpaRepository<ChatRoom, UUID> {

    Optional<ChatRoom> findByListingIdAndBuyerId(UUID listingId, UUID buyerId);

    @Query("SELECT r FROM ChatRoom r WHERE r.buyerId = :userId OR r.sellerId = :userId ORDER BY r.lastMessageAt DESC NULLS LAST")
    List<ChatRoom> findAllByUserId(@Param("userId") UUID userId);
}
