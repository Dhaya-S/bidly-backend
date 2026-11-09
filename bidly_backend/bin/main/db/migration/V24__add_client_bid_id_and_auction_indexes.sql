-- ============================================================
-- V24__add_client_bid_id_and_auction_indexes.sql
-- Idempotency & High-Performance Real-Time Auction Bidding Indexes
-- ============================================================

-- 1. Add client_bid_id column for idempotency (UUID from client)
ALTER TABLE bids ADD COLUMN IF NOT EXISTS client_bid_id VARCHAR(64);

-- 2. Partial unique index to enforce strict 1-to-1 client bid idempotency
CREATE UNIQUE INDEX IF NOT EXISTS uq_bids_client_bid_id 
    ON bids(client_bid_id) 
    WHERE client_bid_id IS NOT NULL;

-- 3. Composite index for ultra-fast, deterministic live bid feed queries
CREATE INDEX IF NOT EXISTS idx_bids_listing_created_id 
    ON bids(listing_id, created_at DESC, id DESC);
