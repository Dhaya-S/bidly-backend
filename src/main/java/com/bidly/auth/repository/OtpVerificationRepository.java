package com.bidly.auth.repository;

import com.bidly.auth.entity.OtpVerification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface OtpVerificationRepository extends JpaRepository<OtpVerification, UUID> {

    Optional<OtpVerification> findTopByPhoneAndVerifiedFalseOrderByCreatedAtDesc(String phone);

    Optional<OtpVerification> findBySessionIdAndVerifiedFalse(String sessionId);

    @Modifying
    @Transactional
    @Query("DELETE FROM OtpVerification o WHERE o.phone = :phone")
    void deleteAllByPhone(String phone);
}
