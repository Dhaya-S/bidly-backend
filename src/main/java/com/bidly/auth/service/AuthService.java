package com.bidly.auth.service;

import com.bidly.auth.dto.AuthResponse;
import com.bidly.auth.dto.SendOtpRequest;
import com.bidly.auth.dto.SendOtpResponse;
import com.bidly.auth.dto.VerifyOtpRequest;
import com.bidly.auth.entity.OtpVerification;
import com.bidly.auth.repository.OtpVerificationRepository;
import com.bidly.common.exception.BidlyException;
import com.bidly.common.security.JwtTokenProvider;
import com.bidly.user.dto.UserDto;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.Optional;
import java.util.UUID;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final Fast2SmsService fast2SmsService;
    private final OtpVerificationRepository otpVerificationRepository;
    private final UserRepository userRepository;
    private final JwtTokenProvider jwtTokenProvider;

    public AuthService(
            Fast2SmsService fast2SmsService,
            OtpVerificationRepository otpVerificationRepository,
            UserRepository userRepository,
            JwtTokenProvider jwtTokenProvider) {
        this.fast2SmsService = fast2SmsService;
        this.otpVerificationRepository = otpVerificationRepository;
        this.userRepository = userRepository;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    /**
     * Normalizes phone string to standard 10 digits.
     */
    public String normalizePhone(String phone) {
        if (phone == null) {
            throw BidlyException.badRequest("Mobile number is required");
        }
        String digits = phone.replaceAll("\\D", "");
        if (digits.length() < 10) {
            throw BidlyException.badRequest("Please enter a valid 10-digit mobile number");
        }
        return digits.substring(digits.length() - 10);
    }

    /**
     * Sends an OTP to the given mobile number.
     */
    @Transactional
    public SendOtpResponse sendOtp(SendOtpRequest request) {
        String phone = normalizePhone(request.getMobile());
        boolean isNewUser = !userRepository.existsByPhone(phone);

        String requestId = fast2SmsService.sendOtp(phone);

        // Remove previous OTP records for this phone
        otpVerificationRepository.deleteAllByPhone(phone);

        // Store new session
        OtpVerification otpVerification = new OtpVerification();
        otpVerification.setPhone(phone);
        otpVerification.setSessionId(requestId);
        otpVerification.setName(request.getName());
        otpVerification.setExpiresAt(Instant.now().plus(Duration.ofMinutes(5)));
        otpVerification.setVerified(false);
        otpVerification.setAttempts(0);

        otpVerificationRepository.save(otpVerification);

        log.info("Saved OTP session for phone {}, requestId: {}", phone, requestId);

        return new SendOtpResponse(requestId, phone, "OTP sent successfully", isNewUser);
    }

    /**
     * Verifies the OTP and authenticates/registers the user.
     */
    @Transactional
    public AuthResponse verifyOtp(VerifyOtpRequest request) {
        String phone = normalizePhone(request.getMobile());
        String otp = request.getOtp().trim();
        boolean isMagicOtp = "123456".equals(otp) || "000000".equals(otp);

        Optional<OtpVerification> sessionOpt = otpVerificationRepository
                .findTopByPhoneAndVerifiedFalseOrderByCreatedAtDesc(phone);

        String sessionName = null;
        if (sessionOpt.isPresent()) {
            OtpVerification session = sessionOpt.get();
            sessionName = session.getName();
            if (session.isExpired() && !isMagicOtp) {
                otpVerificationRepository.deleteAllByPhone(phone);
                throw BidlyException.badRequest("OTP has expired. Please request a new code.");
            }
        } else if (!isMagicOtp) {
            throw BidlyException.badRequest("No pending OTP request found for this number. Please request a new OTP.");
        }

        // Verify with Fast2SMS if not magic OTP
        if (!isMagicOtp) {
            fast2SmsService.verifyOtp(phone, otp);
        } else {
            log.info("Development Magic OTP '{}' used to authenticate phone: {}", otp, phone);
        }

        // Clean up OTP sessions
        otpVerificationRepository.deleteAllByPhone(phone);

        // Find or create user
        Optional<User> existingUser = userRepository.findByPhone(phone);
        User user;
        if (existingUser.isPresent()) {
            user = existingUser.get();
            if ((user.getName() == null || user.getName().isBlank()) && request.getName() != null && !request.getName().isBlank()) {
                user.setName(request.getName().trim());
                user = userRepository.save(user);
            } else if ((user.getName() == null || user.getName().isBlank()) && sessionName != null && !sessionName.isBlank()) {
                user.setName(sessionName.trim());
                user = userRepository.save(user);
            }
        } else {
            String name = request.getName();
            if (name == null || name.isBlank()) {
                name = sessionName;
            }
            user = new User();
            user.setPhone(phone);
            user.setName(name != null && !name.isBlank() ? name.trim() : "Bidly User");
            user.setActive(true);
            user = userRepository.save(user);
            log.info("Registered new user with phone: {}", phone);
        }

        String token = jwtTokenProvider.generateToken(user.getId());

        return new AuthResponse(token, mapToDto(user), "Authentication successful");
    }

    /**
     * Resends OTP to the given mobile number.
     */
    @Transactional
    public SendOtpResponse resendOtp(String mobile) {
        SendOtpRequest request = new SendOtpRequest();
        request.setMobile(mobile);
        return sendOtp(request);
    }

    /**
     * Gets current user profile by user ID.
     */
    public UserDto getCurrentUser(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BidlyException.notFound("User"));
        return mapToDto(user);
    }

    public UserDto mapToDto(User user) {
        UserDto dto = new UserDto();
        dto.setId(user.getId());
        dto.setPhone(user.getPhone());
        dto.setName(user.getName());
        dto.setAvatarUrl(user.getAvatarUrl());
        dto.setCity(user.getCity());
        dto.setState(user.getState());
        dto.setActive(user.isActive());
        dto.setIdentityVerified(user.isIdentityVerified());
        dto.setIdentityProvider(user.getIdentityProvider());
        dto.setTrustScore(user.getTrustScore());
        dto.setAddress(user.getAddress());
        dto.setPincode(user.getPincode());
        dto.setLatitude(user.getLatitude());
        dto.setLongitude(user.getLongitude());
        dto.setSearchRadiusKm(user.getSearchRadiusKm());
        dto.setOnboardingCompleted(user.isOnboardingCompleted());
        dto.setEmail(user.getEmail());
        dto.setSellerType(user.getSellerType() != null ? user.getSellerType() : "INDIVIDUAL");
        dto.setCreatedAt(user.getCreatedAt());
        dto.setInterests(user.getInterests() != null ? new HashSet<>(user.getInterests()) : new HashSet<>());
        return dto;
    }
}
