package com.bidly.auth.controller;

import com.bidly.auth.dto.AuthResponse;
import com.bidly.auth.dto.SendOtpRequest;
import com.bidly.auth.dto.SendOtpResponse;
import com.bidly.auth.dto.VerifyOtpRequest;
import com.bidly.auth.service.AuthService;
import com.bidly.common.dto.ApiResponse;
import com.bidly.user.dto.UserDto;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    /**
     * POST /api/auth/send-otp
     */
    @PostMapping("/send-otp")
    public ResponseEntity<ApiResponse<SendOtpResponse>> sendOtp(@Valid @RequestBody SendOtpRequest request) {
        SendOtpResponse response = authService.sendOtp(request);
        return ResponseEntity.ok(ApiResponse.success("OTP sent successfully", response));
    }

    /**
     * POST /api/auth/verify-otp
     */
    @PostMapping("/verify-otp")
    public ResponseEntity<ApiResponse<AuthResponse>> verifyOtp(@Valid @RequestBody VerifyOtpRequest request) {
        AuthResponse response = authService.verifyOtp(request);
        return ResponseEntity.ok(ApiResponse.success("OTP verified successfully", response));
    }

    /**
     * POST /api/auth/resend-otp
     */
    @PostMapping("/resend-otp")
    public ResponseEntity<ApiResponse<SendOtpResponse>> resendOtp(@RequestParam String mobile) {
        SendOtpResponse response = authService.resendOtp(mobile);
        return ResponseEntity.ok(ApiResponse.success("OTP resent successfully", response));
    }

    /**
     * GET /api/auth/me (Protected, returns current user from JWT)
     */
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserDto>> getCurrentUser(@AuthenticationPrincipal UUID userId) {
        UserDto userDto = authService.getCurrentUser(userId);
        return ResponseEntity.ok(ApiResponse.success(userDto));
    }
}
