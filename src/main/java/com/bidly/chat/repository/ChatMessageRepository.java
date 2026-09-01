package com.bidly.chat.repository;

import com.bidly.chat.entity.ChatMessage;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, UUID> {

    List<ChatMessage> findByRoomIdOrderByCreatedAtAsc(UUID roomId);

    @Query("SELECT m FROM ChatMessage m WHERE m.roomId = :roomId ORDER BY m.createdAt ASC, m.id ASC")
    List<ChatMessage> findByRoomIdOrderByCreatedAtAscIdAsc(@Param("roomId") UUID roomId);

    @Query("SELECT m FROM ChatMessage m WHERE m.roomId = :roomId AND m.createdAt > :since ORDER BY m.createdAt ASC, m.id ASC")
    List<ChatMessage> findByRoomIdAndCreatedAtAfterOrderByCreatedAtAscIdAsc(@Param("roomId") UUID roomId, @Param("since") Instant since);

    Optional<ChatMessage> findTopByRoomIdOrderByCreatedAtDesc(UUID roomId);

    Optional<ChatMessage> findByRoomIdAndClientMessageId(UUID roomId, String clientMessageId);

    Optional<ChatMessage> findByClientMessageId(String clientMessageId);

    @Query("SELECT m FROM ChatMessage m WHERE m.roomId = :roomId AND (m.createdAt < :beforeCreatedAt OR (m.createdAt = :beforeCreatedAt AND m.id < :beforeId)) ORDER BY m.createdAt DESC, m.id DESC")
    List<ChatMessage> findOlderMessages(
            @Param("roomId") UUID roomId,
            @Param("beforeCreatedAt") Instant beforeCreatedAt,
            @Param("beforeId") UUID beforeId,
            Pageable pageable);

    @Query("SELECT m FROM ChatMessage m WHERE m.roomId = :roomId AND m.senderId <> :readerId AND m.readAt IS NULL")
    List<ChatMessage> findUnreadMessagesInRoom(@Param("roomId") UUID roomId, @Param("readerId") UUID readerId);

    @Query("SELECT COUNT(m) FROM ChatMessage m WHERE m.roomId = :roomId AND m.senderId <> :userId AND m.readAt IS NULL")
    long countUnreadInRoom(@Param("roomId") UUID roomId, @Param("userId") UUID userId);

    @Query("SELECT COUNT(m) FROM ChatMessage m JOIN ChatRoom r ON m.roomId = r.id WHERE (r.buyerId = :userId OR r.sellerId = :userId) AND m.senderId <> :userId AND m.readAt IS NULL")
    long countUnreadMessagesForUser(@Param("userId") UUID userId);
}
