-- V2__fast2sms_otp_session.sql
-- Update otp_verifications table to support Fast2SMS session-based verification and registration name

ALTER TABLE otp_verifications ADD COLUMN IF NOT EXISTS session_id VARCHAR(100);
ALTER TABLE otp_verifications ADD COLUMN IF NOT EXISTS name VARCHAR(100);
ALTER TABLE otp_verifications ALTER COLUMN otp_code DROP NOT NULL;
