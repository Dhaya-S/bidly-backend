-- V14: Create offers table and extend orders for direct sale negotiation and in-person meetup

-- 1. Create Offers Table
CREATE TABLE IF NOT EXISTS offers (
    id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id     UUID          NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    buyer_id       UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    seller_id      UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount         NUMERIC(12,2) NOT NULL,
    counter_amount NUMERIC(12,2),
    status         VARCHAR(30)   NOT NULL DEFAULT 'PENDING', -- PENDING, ACCEPTED, REJECTED, COUNTERED, CANCELLED, EXPIRED
    message        TEXT,
    expires_at     TIMESTAMPTZ,
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_offers_listing_buyer ON offers(listing_id, buyer_id);
CREATE INDEX IF NOT EXISTS idx_offers_seller        ON offers(seller_id);
CREATE INDEX IF NOT EXISTS idx_offers_status        ON offers(status);

-- 2. Extend Orders Table for Direct Sale and In-Person Meetup
ALTER TABLE orders ADD COLUMN IF NOT EXISTS offer_id UUID REFERENCES offers(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_source VARCHAR(30) NOT NULL DEFAULT 'AUCTION'; -- AUCTION, DIRECT_SALE
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_type VARCHAR(30) NOT NULL DEFAULT 'COURIER'; -- COURIER, IN_PERSON_MEETUP
ALTER TABLE orders ADD COLUMN IF NOT EXISTS meetup_location VARCHAR(255);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS meetup_time TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS meetup_otp VARCHAR(10);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS meetup_otp_verified BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_orders_offer ON orders(offer_id);
