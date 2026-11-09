-- Add missing updated_at column to reviews table (required by BaseEntity / JPA auditing)
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Also add updated_at to review_photos for consistency
ALTER TABLE review_photos ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
