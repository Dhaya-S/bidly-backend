package com.bidly.address.controller;

import com.bidly.address.dto.CreateAddressRequest;
import com.bidly.address.dto.DeliveryAddressDto;
import com.bidly.address.service.DeliveryAddressService;
import com.bidly.common.dto.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/addresses")
public class DeliveryAddressController {

    private final DeliveryAddressService addressService;

    public DeliveryAddressController(DeliveryAddressService addressService) {
        this.addressService = addressService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<DeliveryAddressDto>>> getUserAddresses(
            @AuthenticationPrincipal UUID currentUserId) {
        List<DeliveryAddressDto> addresses = addressService.getUserAddresses(currentUserId);
        return ResponseEntity.ok(ApiResponse.success(addresses));
    }

    @GetMapping("/default")
    public ResponseEntity<ApiResponse<DeliveryAddressDto>> getDefaultAddress(
            @AuthenticationPrincipal UUID currentUserId) {
        DeliveryAddressDto address = addressService.getDefaultOrLatestAddress(currentUserId);
        return ResponseEntity.ok(ApiResponse.success(address));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<DeliveryAddressDto>> createAddress(
            @AuthenticationPrincipal UUID currentUserId,
            @Valid @RequestBody CreateAddressRequest request) {
        DeliveryAddressDto address = addressService.createAddress(currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Delivery address saved successfully", address));
    }
}
