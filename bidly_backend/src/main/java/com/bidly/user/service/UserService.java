package com.bidly.user.service;

import com.bidly.auth.service.AuthService;
import com.bidly.common.exception.BidlyException;
import com.bidly.user.dto.IdentitySetupRequest;
import com.bidly.user.dto.InterestsSetupRequest;
import com.bidly.user.dto.LocationSetupRequest;
import com.bidly.user.dto.UserDto;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class UserService {

    private static final Logger log = LoggerFactory.getLogger(UserService.class);

    private final UserRepository userRepository;
    private final AuthService authService;

    public UserService(UserRepository userRepository, AuthService authService) {
        this.userRepository = userRepository;
        this.authService = authService;
    }

    /**
     * Links DigiLocker identity and marks user verified with trust score.
     */
    @Transactional
    public UserDto verifyIdentity(UUID userId, IdentitySetupRequest request) {
        User user = findUserById(userId);

        user.setIdentityVerified(true);
        user.setIdentityProvider(request.getProvider() != null ? request.getProvider() : "DIGILOCKER");
        user.setTrustScore(95); // High trust score upon DigiLocker verification

        User saved = userRepository.save(user);
        log.info("Verified identity for user {} via {}", userId, user.getIdentityProvider());

        return authService.mapToDto(saved);
    }

    /**
     * Updates user location, address, and search radius.
     */
    @Transactional
    public UserDto updateLocation(UUID userId, LocationSetupRequest request) {
        User user = findUserById(userId);

        if (request.getAddress() != null) user.setAddress(request.getAddress().trim());
        if (request.getCity() != null) user.setCity(request.getCity().trim());
        if (request.getState() != null) user.setState(request.getState().trim());
        if (request.getPincode() != null) user.setPincode(request.getPincode().trim());
        if (request.getLatitude() != null) user.setLatitude(request.getLatitude());
        if (request.getLongitude() != null) user.setLongitude(request.getLongitude());
        if (request.getSearchRadiusKm() > 0) user.setSearchRadiusKm(request.getSearchRadiusKm());

        User saved = userRepository.save(user);
        log.info("Updated location for user {}: city={}, radius={}km", userId, saved.getCity(), saved.getSearchRadiusKm());

        return authService.mapToDto(saved);
    }

    /**
     * Saves user selected category interests and completes onboarding setup.
     */
    @Transactional
    public UserDto updateInterests(UUID userId, InterestsSetupRequest request) {
        User user = findUserById(userId);

        if (request.getInterests() != null && !request.getInterests().isEmpty()) {
            user.setInterests(request.getInterests());
        }
        user.setOnboardingCompleted(true);

        User saved = userRepository.save(user);
        log.info("Saved interests for user {}: count={}, onboardingCompleted=true", userId, saved.getInterests().size());

        return authService.mapToDto(saved);
    }

    /**
     * Updates user profile info (name, email, phone, sellerType, address, etc.)
     */
    @Transactional
    public UserDto updateProfile(UUID userId, com.bidly.user.dto.UpdateProfileRequest request) {
        User user = findUserById(userId);

        if (request.getName() != null && !request.getName().isBlank()) {
            user.setName(request.getName().trim());
        }
        if (request.getEmail() != null) {
            user.setEmail(request.getEmail().trim());
        }
        if (request.getPhone() != null && !request.getPhone().isBlank()) {
            user.setPhone(request.getPhone().trim());
        }
        if (request.getSellerType() != null && !request.getSellerType().isBlank()) {
            user.setSellerType(request.getSellerType().trim().toUpperCase());
        }
        if (request.getAddress() != null) {
            user.setAddress(request.getAddress().trim());
        }
        if (request.getCity() != null) {
            user.setCity(request.getCity().trim());
        }
        if (request.getState() != null) {
            user.setState(request.getState().trim());
        }
        if (request.getAvatarUrl() != null) {
            user.setAvatarUrl(request.getAvatarUrl().trim());
        }

        User saved = userRepository.save(user);
        log.info("Updated profile for user {}: name={}, sellerType={}", userId, saved.getName(), saved.getSellerType());

        return authService.mapToDto(saved);
    }

    /**
     * Gets user profile.
     */
    public UserDto getUserProfile(UUID userId) {
        User user = findUserById(userId);
        return authService.mapToDto(user);
    }

    private User findUserById(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> BidlyException.notFound("User"));
    }

    /**
     * Checks which phone numbers from the list belong to registered users.
     */
    public java.util.List<UserDto> syncContacts(com.bidly.user.dto.SyncContactsRequest request) {
        if (request.getPhoneNumbers() == null || request.getPhoneNumbers().isEmpty()) {
            return java.util.Collections.emptyList();
        }
        
        java.util.List<String> cleanedNumbers = request.getPhoneNumbers().stream()
                .map(phone -> phone.replaceAll("[^0-9+]", ""))
                .collect(java.util.stream.Collectors.toList());
                
        java.util.List<User> matchedUsers = userRepository.findByPhoneIn(cleanedNumbers);
        return matchedUsers.stream()
                .map(authService::mapToDto)
                .collect(java.util.stream.Collectors.toList());
    }

    /**
     * Permanently deletes / anonymizes user account and sessions (Apple & Google Play Store Compliance).
     */
    @Transactional
    public void deleteAccount(UUID userId) {
        User user = findUserById(userId);
        log.warn("Account deletion requested for userId: {}, phone: {}", userId, user.getPhone());
        user.setName("Deleted User");
        user.setEmail(null);
        user.setAvatarUrl(null);
        user.setPhone("deleted_" + System.currentTimeMillis() + "_" + UUID.randomUUID().toString().substring(0, 8));
        user.setAddress(null);
        user.setPincode(null);
        user.setLatitude(null);
        user.setLongitude(null);
        user.setActive(false);
        userRepository.save(user);
        log.info("User account successfully anonymized and deactivated: {}", userId);
    }

}
