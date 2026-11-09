-- V26: Add media processing status to listings and create media_jobs table

-- 1. Add media_processing_status column to listings table
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS media_processing_status VARCHAR(20) DEFAULT 'READY' NOT NULL;

-- 2. Create media_jobs table for background transcoding job tracking
CREATE TABLE IF NOT EXISTS media_jobs (
    id UUID PRIMARY KEY,
    media_url TEXT NOT NULL,
    thumbnail_url TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'PROCESSING',
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 3. Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_media_jobs_url ON media_jobs(media_url);
CREATE INDEX IF NOT EXISTS idx_media_jobs_status ON media_jobs(status);
CREATE INDEX IF NOT EXISTS idx_listings_reel_status ON listings(media_processing_status, status);
