package com.bidly.chat.controller;

import com.bidly.chat.dto.ChatMessageDto;
import com.bidly.chat.dto.ChatRoomDto;
import com.bidly.chat.dto.CreateRoomRequest;
import com.bidly.chat.dto.SendMessageRequest;
import com.bidly.chat.service.ChatService;
import com.bidly.common.dto.ApiResponse;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/chat")
public class ChatController {

    private final ChatService chatService;

    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    /**
     * POST /api/chat/rooms - Get or create chat room for listing + current buyer
     */
    @PostMapping("/rooms")
    public ResponseEntity<ApiResponse<ChatRoomDto>> getOrCreateRoom(
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody CreateRoomRequest request) {
        ChatRoomDto room = chatService.getOrCreateRoom(request.getListingId(), currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Room created or retrieved", room));
    }

    /**
     * GET /api/chat/rooms - List all chat rooms for current user
     */
    @GetMapping("/rooms")
    public ResponseEntity<ApiResponse<List<ChatRoomDto>>> listRooms(
            @AuthenticationPrincipal UUID currentUserId) {
        List<ChatRoomDto> rooms = chatService.listRooms(currentUserId);
        return ResponseEntity.ok(ApiResponse.success(rooms));
    }

    /**
     * GET /api/chat/rooms/{roomId}/messages - Get messages in room with optional pagination
     */
    @GetMapping("/rooms/{roomId}/messages")
    public ResponseEntity<ApiResponse<List<ChatMessageDto>>> getMessages(
            @PathVariable UUID roomId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant beforeCreatedAt,
            @RequestParam(required = false) UUID beforeId,
            @RequestParam(required = false, defaultValue = "50") Integer limit,
            @AuthenticationPrincipal UUID currentUserId) {
        List<ChatMessageDto> messages = chatService.getMessages(roomId, currentUserId, beforeCreatedAt, beforeId, limit);
        return ResponseEntity.ok(ApiResponse.success(messages));
    }

    /**
     * POST /api/chat/rooms/{roomId}/messages - Send text message, offer, meetup, or image
     */
    @PostMapping("/rooms/{roomId}/messages")
    public ResponseEntity<ApiResponse<ChatMessageDto>> sendMessage(
            @PathVariable UUID roomId,
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody SendMessageRequest request) {
        ChatMessageDto message = chatService.sendMessage(roomId, currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Message sent", message));
    }

    /**
     * POST /api/chat/rooms/{roomId}/read - Mark messages as read and broadcast receipt
     */
    @PostMapping("/rooms/{roomId}/read")
    public ResponseEntity<ApiResponse<Void>> markAsRead(
            @PathVariable UUID roomId,
            @AuthenticationPrincipal UUID currentUserId) {
        chatService.markRoomMessagesAsRead(roomId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Messages marked as read", null));
    }

    /**
     * POST /api/chat/rooms/{roomId}/typing - Send ephemeral typing indicator
     */
    @PostMapping("/rooms/{roomId}/typing")
    public ResponseEntity<ApiResponse<Void>> sendTyping(
            @PathVariable UUID roomId,
            @RequestBody Map<String, Boolean> body,
            @AuthenticationPrincipal UUID currentUserId) {
        boolean isTyping = body != null && Boolean.TRUE.equals(body.get("isTyping"));
        chatService.sendTypingIndicator(roomId, currentUserId, isTyping);
        return ResponseEntity.ok(ApiResponse.success("Typing event processed", null));
    }
}
