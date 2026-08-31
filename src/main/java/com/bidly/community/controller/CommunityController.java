package com.bidly.community.controller;

import com.bidly.common.dto.ApiResponse;
import com.bidly.community.dto.AddMemberRequest;
import com.bidly.community.dto.CommunityDto;
import com.bidly.community.dto.CommunityMemberDto;
import com.bidly.community.dto.CreateCommunityRequest;
import com.bidly.community.service.CommunityService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/communities")
public class CommunityController {

    private final CommunityService communityService;

    public CommunityController(CommunityService communityService) {
        this.communityService = communityService;
    }

    /**
     * GET /api/communities — Get list of communities with search filter
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<CommunityDto>>> getCommunities(
            @AuthenticationPrincipal UUID userId,
            @RequestParam(required = false) String search) {
        List<CommunityDto> list = communityService.getCommunities(userId, search);
        return ResponseEntity.ok(ApiResponse.success(list));
    }

    /**
     * POST /api/communities — Create a new community (Creator becomes ADMIN)
     */
    @PostMapping
    public ResponseEntity<ApiResponse<CommunityDto>> createCommunity(
            @AuthenticationPrincipal UUID userId,
            @Valid @RequestBody CreateCommunityRequest request) {
        CommunityDto created = communityService.createCommunity(userId, request);
        return ResponseEntity.ok(ApiResponse.success("Community created successfully", created));
    }

    /**
     * GET /api/communities/{id} — Get community details
     */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<CommunityDto>> getCommunity(
            @PathVariable UUID id,
            @AuthenticationPrincipal UUID userId) {
        CommunityDto dto = communityService.getCommunity(id, userId);
        return ResponseEntity.ok(ApiResponse.success(dto));
    }

    /**
     * PUT /api/communities/{id} — Update community details
     */
    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<CommunityDto>> updateCommunity(
            @PathVariable UUID id,
            @AuthenticationPrincipal UUID userId,
            @RequestBody CreateCommunityRequest request) {
        CommunityDto dto = communityService.updateCommunity(id, userId, request);
        return ResponseEntity.ok(ApiResponse.success("Community updated successfully", dto));
    }

    /**
     * GET /api/communities/{id}/members — List community members
     */
    @GetMapping("/{id}/members")
    public ResponseEntity<ApiResponse<List<CommunityMemberDto>>> getMembers(@PathVariable UUID id) {
        List<CommunityMemberDto> members = communityService.getMembers(id);
        return ResponseEntity.ok(ApiResponse.success(members));
    }

    /**
     * POST /api/communities/{id}/members — Admin adds a member
     */
    @PostMapping("/{id}/members")
    public ResponseEntity<ApiResponse<CommunityMemberDto>> addMember(
            @PathVariable UUID id,
            @AuthenticationPrincipal UUID adminUserId,
            @RequestBody AddMemberRequest request) {
        CommunityMemberDto member = communityService.addMember(id, adminUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Member added successfully", member));
    }

    /**
     * DELETE /api/communities/{id}/members/{targetUserId} — Admin removes member or member leaves
     */
    @DeleteMapping("/{id}/members/{targetUserId}")
    public ResponseEntity<ApiResponse<Map<String, String>>> removeMember(
            @PathVariable UUID id,
            @PathVariable UUID targetUserId,
            @AuthenticationPrincipal UUID requesterUserId) {
        communityService.removeMember(id, requesterUserId, targetUserId);
        return ResponseEntity.ok(ApiResponse.success("Member removed successfully", Map.of("status", "REMOVED")));
    }

    /**
     * POST /api/communities/{id}/join — Join a community
     */
    @PostMapping("/{id}/join")
    public ResponseEntity<ApiResponse<Map<String, String>>> joinCommunity(
            @PathVariable UUID id,
            @AuthenticationPrincipal UUID userId) {
        communityService.joinCommunity(id, userId);
        return ResponseEntity.ok(ApiResponse.success("Joined community successfully", Map.of("status", "JOINED")));
    }
}
