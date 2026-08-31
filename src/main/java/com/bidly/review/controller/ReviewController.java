package com.bidly.review.controller;

import com.bidly.common.dto.ApiResponse;
import com.bidly.review.dto.CreateReviewRequest;
import com.bidly.review.dto.ReviewDto;
import com.bidly.review.service.ReviewService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/reviews")
public class ReviewController {

    private final ReviewService reviewService;

    public ReviewController(ReviewService reviewService) {
        this.reviewService = reviewService;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<ReviewDto>> submitReview(
            @AuthenticationPrincipal UUID currentUserId,
            @Valid @RequestBody CreateReviewRequest request) {
        ReviewDto review = reviewService.createReview(currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Review submitted successfully", review));
    }

    @GetMapping("/seller/{sellerId}")
    public ResponseEntity<ApiResponse<List<ReviewDto>>> getSellerReviews(
            @PathVariable UUID sellerId) {
        List<ReviewDto> reviews = reviewService.getSellerReviews(sellerId);
        return ResponseEntity.ok(ApiResponse.success(reviews));
    }
}
