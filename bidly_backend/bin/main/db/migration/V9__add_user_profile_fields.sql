-- V9__add_user_profile_fields.sql
-- Adds email and seller_type to users table

ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(150);
ALTER TABLE users ADD COLUMN IF NOT EXISTS seller_type VARCHAR(50) NOT NULL DEFAULT 'INDIVIDUAL';
