package com.bidly.order.controller;

import com.bidly.common.dto.ApiResponse;
import com.bidly.order.dto.OrderSummaryDto;
import com.bidly.order.service.OrderService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<java.util.List<OrderSummaryDto>>> getOrders(
            @AuthenticationPrincipal UUID currentUserId,
            @RequestParam(required = false) String source,
            @RequestParam(required = false) String role) {
        java.util.List<OrderSummaryDto> orders = orderService.getUserOrders(currentUserId, source, role);
        return ResponseEntity.ok(ApiResponse.success(orders));
    }

    @GetMapping("/{orderId}")
    public ResponseEntity<ApiResponse<OrderSummaryDto>> getOrder(
            @PathVariable UUID orderId,
            @AuthenticationPrincipal UUID currentUserId) {
        OrderSummaryDto dto = orderService.getOrderDetails(orderId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success(dto));
    }

    @GetMapping("/listing/{listingId}")
    public ResponseEntity<ApiResponse<OrderSummaryDto>> getOrderByListing(
            @PathVariable UUID listingId,
            @AuthenticationPrincipal UUID currentUserId) {
        OrderSummaryDto dto = orderService.getOrCreateOrderByListing(listingId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success(dto));
    }

    @PostMapping("/{orderId}/confirm-delivery")
    public ResponseEntity<ApiResponse<OrderSummaryDto>> confirmDelivery(
            @PathVariable UUID orderId,
            @AuthenticationPrincipal UUID currentUserId) {
        OrderSummaryDto dto = orderService.confirmDelivery(orderId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Delivery confirmed and payout released to seller", dto));
    }

    @PostMapping("/{orderId}/verify-otp")
    public ResponseEntity<ApiResponse<OrderSummaryDto>> verifyMeetupOtp(
            @PathVariable UUID orderId,
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody java.util.Map<String, String> body) {
        String otp = body != null ? body.get("otp") : null;
        OrderSummaryDto dto = orderService.verifyMeetupOtp(orderId, otp, currentUserId);
        return ResponseEntity.ok(ApiResponse.success("OTP verified successfully. Handover completed and payout released to seller.", dto));
    }
}
