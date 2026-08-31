package com.bidly.auth.entity;

import com.bidly.common.entity.BaseEntity;
import jakarta.persistence.*;

import java.time.Instant;

/**
 * Stores pending OTP session details for Fast2SMS verification.
 */
@Entity
@Table(name = "otp_verifications",
        indexes = {
                @Index(name = "idx_otp_phone", columnList = "phone"),
                @Index(name = "idx_otp_session", columnList = "session_id")
        })
public class OtpVerification extends BaseEntity {

    @Column(nullable = false, length = 20)
    private String phone;

    @Column(name = "session_id", length = 100)
    private String sessionId;

    @Column(name = "otp_code", length = 10)
    private String otpCode;

    @Column(name = "name", length = 100)
    private String name;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "verified", nullable = false)
    private boolean verified = false;

    @Column(name = "attempts")
    private int attempts = 0;

    public OtpVerification() {}

    public boolean isExpired() {
        return expiresAt != null && Instant.now().isAfter(expiresAt);
    }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getSessionId() { return sessionId; }
    public void setSessionId(String sessionId) { this.sessionId = sessionId; }

    public String getOtpCode() { return otpCode; }
    public void setOtpCode(String otpCode) { this.otpCode = otpCode; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Instant getExpiresAt() { return expiresAt; }
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }

    public boolean isVerified() { return verified; }
    public void setVerified(boolean verified) { this.verified = verified; }

    public int getAttempts() { return attempts; }
    public void setAttempts(int attempts) { this.attempts = attempts; }
}
