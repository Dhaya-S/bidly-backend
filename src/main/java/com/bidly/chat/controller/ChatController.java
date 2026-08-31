package com.bidly.chat.controller;

import com.bidly.chat.dto.ChatMessageDto;
import com.bidly.chat.dto.ChatRoomDto;
import com.bidly.chat.dto.CreateRoomRequest;
import com.bidly.chat.dto.SendMessageRequest;
import com.bidly.chat.service.ChatService;
import com.bidly.common.dto.ApiResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
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
     * GET /api/chat/rooms/{roomId}/messages - Get messages in room with optional since ISO timestamp
     */
    @GetMapping("/rooms/{roomId}/messages")
    public ResponseEntity<ApiResponse<List<ChatMessageDto>>> getMessages(
            @PathVariable UUID roomId,
            @RequestParam(required = false) String since,
            @AuthenticationPrincipal UUID currentUserId) {
        List<ChatMessageDto> messages = chatService.getMessages(roomId, currentUserId, since);
        return ResponseEntity.ok(ApiResponse.success(messages));
    }

    /**
     * POST /api/chat/rooms/{roomId}/messages - Send text message or offer
     */
    @PostMapping("/rooms/{roomId}/messages")
    public ResponseEntity<ApiResponse<ChatMessageDto>> sendMessage(
            @PathVariable UUID roomId,
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody SendMessageRequest request) {
        ChatMessageDto message = chatService.sendMessage(roomId, currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Message sent", message));
    }
}
