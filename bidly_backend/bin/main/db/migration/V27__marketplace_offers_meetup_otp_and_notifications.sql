-- V27: Create notifications table, extend offers with rejection and idempotency,
-- extend orders with meetup details and OTP lifecycle, and enforce chat room integrity.

-- 1. Create Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
    id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type           VARCHAR(50)   NOT NULL,
    title          VARCHAR(200)  NOT NULL,
    body           TEXT          NOT NULL,
    is_read        BOOLEAN       NOT NULL DEFAULT FALSE,
    listing_id     UUID          REFERENCES listings(id) ON DELETE SET NULL,
    offer_id       UUID          REFERENCES offers(id) ON DELETE SET NULL,
    order_id       UUID          REFERENCES orders(id) ON DELETE SET NULL,
    action_label   VARCHAR(100),
    target_route   VARCHAR(255),
    target_id      UUID,
    metadata       TEXT,
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread  ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_offer        ON notifications(offer_id);
CREATE INDEX IF NOT EXISTS idx_notifications_order        ON notifications(order_id);
CREATE INDEX IF NOT EXISTS idx_notifications_listing      ON notifications(listing_id);

-- 2. Extend Offers Table for Rejection Audit and Client Idempotency
ALTER TABLE offers ADD COLUMN IF NOT EXISTS rejection_reason VARCHAR(100);
ALTER TABLE offers ADD COLUMN IF NOT EXISTS rejection_note   TEXT;
ALTER TABLE offers ADD COLUMN IF NOT EXISTS rejected_at      TIMESTAMPTZ;
ALTER TABLE offers ADD COLUMN IF NOT EXISTS client_offer_id  VARCHAR(100);

CREATE UNIQUE INDEX IF NOT EXISTS idx_offers_client_offer_id ON offers(client_offer_id) WHERE client_offer_id IS NOT NULL;

-- 3. Extend Orders Table for Meetup Notes, OTP Expiry, Attempt Counter, and Idempotency
ALTER TABLE orders ADD COLUMN IF NOT EXISTS meetup_notes      TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS client_action_id  VARCHAR(100);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS otp_expires_at    TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS otp_attempt_count INT DEFAULT 0;

CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_client_action_id ON orders(client_action_id) WHERE client_action_id IS NOT NULL;

-- 4. Clean up any corrupted Chat Rooms where buyer_id = seller_id and enforce strict check constraint
DELETE FROM chat_messages WHERE room_id IN (SELECT id FROM chat_rooms WHERE buyer_id = seller_id);
DELETE FROM chat_rooms WHERE buyer_id = seller_id;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_chat_rooms_different_users'
    ) THEN
        ALTER TABLE chat_rooms ADD CONSTRAINT chk_chat_rooms_different_users CHECK (buyer_id <> seller_id);
    END IF;
END $$;
