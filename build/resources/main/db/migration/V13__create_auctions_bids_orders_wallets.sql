-- ============================================================
-- V13__create_auctions_bids_orders_wallets.sql
-- Complete Bidly Auction, Wallet, Order, Delivery & Review System
-- ============================================================

-- 1. Wallets table (starts at 0.00 balance; transaction-safe)
CREATE TABLE IF NOT EXISTS wallets (
    id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID          NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    balance           NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    reserved_balance  NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_wallet_balance_positive CHECK (balance >= 0.00),
    CONSTRAINT chk_wallet_reserved_valid CHECK (reserved_balance >= 0.00 AND reserved_balance <= balance)
);
CREATE INDEX IF NOT EXISTS idx_wallets_user ON wallets(user_id);

-- 2. Wallet Transactions (ledger for all credits, debits, reservations, releases, and escrow holds)
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id       UUID          NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    amount          NUMERIC(12,2) NOT NULL,
    type            VARCHAR(30)   NOT NULL, -- CREDIT, DEBIT, RESERVE, RELEASE, ESCROW_HOLD, ESCROW_RELEASE
    reference_id    UUID,
    reference_type  VARCHAR(50),            -- AUCTION_BID, ORDER_PAYMENT, TOP_UP, WITHDRAWAL
    description     TEXT,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_ref ON wallet_transactions(reference_id, reference_type);

-- 3. Delivery Addresses
CREATE TABLE IF NOT EXISTS delivery_addresses (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    full_name     VARCHAR(100) NOT NULL,
    phone         VARCHAR(20)  NOT NULL,
    address_line  TEXT         NOT NULL,
    city          VARCHAR(100) NOT NULL,
    pincode       VARCHAR(20)  NOT NULL,
    is_default    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_addresses_user ON delivery_addresses(user_id);

-- 4. Bids Table
CREATE TABLE IF NOT EXISTS bids (
    id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id            UUID          NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    bidder_id             UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount                NUMERIC(12,2) NOT NULL,
    delivery_address_id   UUID          REFERENCES delivery_addresses(id),
    status                VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, OUTBID, WON, LOST, WITHDRAWN
    created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_bid_amount_positive CHECK (amount > 0.00)
);
CREATE INDEX IF NOT EXISTS idx_bids_listing ON bids(listing_id);
CREATE INDEX IF NOT EXISTS idx_bids_bidder ON bids(bidder_id);
CREATE INDEX IF NOT EXISTS idx_bids_status ON bids(status);
CREATE INDEX IF NOT EXISTS idx_bids_listing_amount ON bids(listing_id, amount DESC);

-- 5. Orders Table (Auction Won / Direct Buy order tracking)
CREATE TABLE IF NOT EXISTS orders (
    id                      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number            VARCHAR(50)   NOT NULL UNIQUE,
    listing_id              UUID          NOT NULL REFERENCES listings(id),
    buyer_id                UUID          NOT NULL REFERENCES users(id),
    seller_id               UUID          NOT NULL REFERENCES users(id),
    winning_bid_id          UUID          REFERENCES bids(id),
    delivery_address_id     UUID          REFERENCES delivery_addresses(id),
    amount                  NUMERIC(12,2) NOT NULL,
    platform_fee            NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    total_amount            NUMERIC(12,2) NOT NULL,
    status                  VARCHAR(30)   NOT NULL DEFAULT 'AUCTION_WON', -- AUCTION_WON, SELLER_CONFIRMED, PACKED, SHIPPED, DELIVERED, CANCELLED
    payment_status          VARCHAR(30)   NOT NULL DEFAULT 'IN_ESCROW',   -- PENDING, IN_ESCROW, RELEASED, REFUNDED
    courier_partner         VARCHAR(100)  DEFAULT 'Ekart Logistics',
    tracking_number         VARCHAR(100),
    estimated_delivery_date TIMESTAMPTZ,
    delivered_at            TIMESTAMPTZ,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_orders_buyer ON orders(buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_seller ON orders(seller_id);
CREATE INDEX IF NOT EXISTS idx_orders_listing ON orders(listing_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

-- 6. Order Tracking Timeline Events
CREATE TABLE IF NOT EXISTS order_tracking_events (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id    UUID         NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status      VARCHAR(30)  NOT NULL,
    title       VARCHAR(100) NOT NULL,
    description TEXT,
    event_time  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_tracking_order ON order_tracking_events(order_id);

-- 7. Reviews Table (one review per completed order)
CREATE TABLE IF NOT EXISTS reviews (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id    UUID        NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    reviewer_id UUID        NOT NULL REFERENCES users(id),
    seller_id   UUID        NOT NULL REFERENCES users(id),
    listing_id  UUID        NOT NULL REFERENCES listings(id),
    rating      INT         NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_reviews_seller ON reviews(seller_id);
CREATE INDEX IF NOT EXISTS idx_reviews_listing ON reviews(listing_id);

-- 8. Review Photos
CREATE TABLE IF NOT EXISTS review_photos (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id  UUID        NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    photo_url  TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_review_photos_review ON review_photos(review_id);

-- 9. Column additions on listings table for fast access & denormalized integrity
ALTER TABLE listings ADD COLUMN IF NOT EXISTS bids_count INT NOT NULL DEFAULT 0;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS highest_bidder_id UUID REFERENCES users(id);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS min_bid_increment NUMERIC(12,2) DEFAULT 500.00;
