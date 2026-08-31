package com.bidly.chat.repository;

import com.bidly.chat.entity.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, UUID> {

    List<ChatMessage> findByRoomIdOrderByCreatedAtAsc(UUID roomId);

    List<ChatMessage> findByRoomIdAndCreatedAtAfterOrderByCreatedAtAsc(UUID roomId, Instant since);

    Optional<ChatMessage> findTopByRoomIdOrderByCreatedAtDesc(UUID roomId);
}
