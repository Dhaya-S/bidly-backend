package com.bidly.user.controller;

import com.bidly.common.dto.ApiResponse;
import com.bidly.user.dto.IdentitySetupRequest;
import com.bidly.user.dto.InterestsSetupRequest;
import com.bidly.user.dto.LocationSetupRequest;
import com.bidly.user.dto.UserDto;
import com.bidly.user.service.UserService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/user")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    /**
     * PUT /api/user/setup/identity — Link DigiLocker & verify identity
     */
    @PutMapping("/setup/identity")
    public ResponseEntity<ApiResponse<UserDto>> verifyIdentity(
            @AuthenticationPrincipal UUID userId,
            @RequestBody(required = false) IdentitySetupRequest request) {
        IdentitySetupRequest req = request != null ? request : new IdentitySetupRequest();
        UserDto userDto = userService.verifyIdentity(userId, req);
        return ResponseEntity.ok(ApiResponse.success("Identity verified successfully", userDto));
    }

    /**
     * PUT /api/user/setup/location — Set location, address & search radius
     */
    @PutMapping("/setup/location")
    public ResponseEntity<ApiResponse<UserDto>> updateLocation(
            @AuthenticationPrincipal UUID userId,
            @RequestBody LocationSetupRequest request) {
        UserDto userDto = userService.updateLocation(userId, request);
        return ResponseEntity.ok(ApiResponse.success("Location updated successfully", userDto));
    }

    /**
     * PUT /api/user/setup/interests — Select favorite categories & complete setup
     */
    @PutMapping("/setup/interests")
    public ResponseEntity<ApiResponse<UserDto>> updateInterests(
            @AuthenticationPrincipal UUID userId,
            @RequestBody InterestsSetupRequest request) {
        UserDto userDto = userService.updateInterests(userId, request);
        return ResponseEntity.ok(ApiResponse.success("Setup completed successfully", userDto));
    }

    /**
     * GET /api/user/profile — Get full user profile
     */
    @GetMapping("/profile")
    public ResponseEntity<ApiResponse<UserDto>> getProfile(@AuthenticationPrincipal UUID userId) {
        UserDto userDto = userService.getUserProfile(userId);
        return ResponseEntity.ok(ApiResponse.success(userDto));
    }

    /**
     * PUT /api/user/profile — Update user profile info (name, email, phone, sellerType, address)
     */
    @PutMapping("/profile")
    public ResponseEntity<ApiResponse<UserDto>> updateProfile(
            @AuthenticationPrincipal UUID userId,
            @RequestBody com.bidly.user.dto.UpdateProfileRequest request) {
        UserDto userDto = userService.updateProfile(userId, request);
        return ResponseEntity.ok(ApiResponse.success("Profile updated successfully", userDto));
    }
}
