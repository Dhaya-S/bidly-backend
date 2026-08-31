package com.bidly.address.service;

import com.bidly.address.dto.CreateAddressRequest;
import com.bidly.address.dto.DeliveryAddressDto;
import com.bidly.address.entity.DeliveryAddress;
import com.bidly.address.repository.DeliveryAddressRepository;
import com.bidly.common.exception.BidlyException;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class DeliveryAddressService {

    private final DeliveryAddressRepository addressRepository;
    private final UserRepository userRepository;

    public DeliveryAddressService(DeliveryAddressRepository addressRepository, UserRepository userRepository) {
        this.addressRepository = addressRepository;
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public List<DeliveryAddressDto> getUserAddresses(UUID userId) {
        return addressRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(this::mapToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public DeliveryAddressDto getDefaultOrLatestAddress(UUID userId) {
        return addressRepository.findFirstByUserIdAndIsDefaultTrue(userId)
                .map(this::mapToDto)
                .orElseGet(() -> {
                    List<DeliveryAddress> all = addressRepository.findByUserIdOrderByCreatedAtDesc(userId);
                    return all.isEmpty() ? null : mapToDto(all.get(0));
                });
    }

    @Transactional
    public DeliveryAddressDto createAddress(UUID userId, CreateAddressRequest req) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BidlyException.notFound("User not found: " + userId));

        List<DeliveryAddress> existing = addressRepository.findByUserIdOrderByCreatedAtDesc(userId);
        boolean isFirst = existing.isEmpty();

        DeliveryAddress address = new DeliveryAddress(
                user,
                req.getFullName().trim(),
                req.getPhone().trim(),
                req.getAddressLine().trim(),
                req.getCity().trim(),
                req.getPincode().trim(),
                isFirst || req.isDefault()
        );

        DeliveryAddress saved = addressRepository.save(address);
        return mapToDto(saved);
    }

    public DeliveryAddressDto mapToDto(DeliveryAddress a) {
        return new DeliveryAddressDto(
                a.getId(),
                a.getFullName(),
                a.getPhone(),
                a.getAddressLine(),
                a.getCity(),
                a.getPincode(),
                a.isDefault()
        );
    }
}
