package com.bidly.community.controller;

import com.bidly.common.dto.ApiResponse;
import com.bidly.community.dto.CommunityDto;
import com.bidly.community.dto.CreatePostRequest;
import com.bidly.community.dto.PostDto;
import com.bidly.community.service.CommunityPostService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/posts")
public class CommunityPostController {

    private final CommunityPostService postService;

    public CommunityPostController(CommunityPostService postService) {
        this.postService = postService;
    }

    /**
     * GET /api/posts — Get global feed of posts
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<PostDto>>> getFeed(
            @AuthenticationPrincipal UUID currentUserId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        List<PostDto> feed = postService.getFeed(currentUserId, page, size);
        return ResponseEntity.ok(ApiResponse.success(feed));
    }

    /**
     * GET /api/posts/community/{communityId}
     */
    @GetMapping("/community/{communityId}")
    public ResponseEntity<ApiResponse<List<PostDto>>> getCommunityPosts(
            @PathVariable UUID communityId,
            @AuthenticationPrincipal UUID currentUserId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        List<PostDto> posts = postService.getCommunityPosts(communityId, currentUserId, page, size);
        return ResponseEntity.ok(ApiResponse.success(posts));
    }

    /**
     * POST /api/posts — Create a new post
     */
    @PostMapping
    public ResponseEntity<ApiResponse<PostDto>> createPost(
            @AuthenticationPrincipal UUID userId,
            @Valid @RequestBody CreatePostRequest request) {
        PostDto postDto = postService.createPost(userId, request);
        return ResponseEntity.ok(ApiResponse.success("Post created", postDto));
    }

    /**
     * POST /api/posts/{id}/like — Toggle or ensure like/unlike on a post
     */
    @PostMapping("/{id}/like")
    public ResponseEntity<ApiResponse<Map<String, Object>>> toggleLike(
            @AuthenticationPrincipal UUID userId,
            @PathVariable UUID id,
            @RequestParam(required = false) String action) {
        Map<String, Object> result = postService.toggleLike(userId, id, action);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    /**
     * POST /api/posts/{id}/share — Increment share count
     */
    @PostMapping("/{id}/share")
    public ResponseEntity<ApiResponse<Map<String, Object>>> sharePost(@PathVariable UUID id) {
        int count = postService.sharePost(id);
        return ResponseEntity.ok(ApiResponse.success(Map.of("sharesCount", count)));
    }

    /**
     * GET /api/posts/communities — List active communities
     */
    @GetMapping("/communities")
    public ResponseEntity<ApiResponse<List<CommunityDto>>> getCommunities(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        List<CommunityDto> communities = postService.getCommunities(page, size);
        return ResponseEntity.ok(ApiResponse.success(communities));
    }
}
