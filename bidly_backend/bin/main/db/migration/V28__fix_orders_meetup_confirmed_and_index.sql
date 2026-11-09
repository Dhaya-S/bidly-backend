-- V28: Fix unique index violation on orders.client_action_id and add dedicated is_meetup_confirmed column

-- 1. Drop unique index on client_action_id so repeated actions don't fail with unique constraint violations
DROP INDEX IF EXISTS idx_orders_client_action_id;
CREATE INDEX IF NOT EXISTS idx_orders_client_action_id ON orders(client_action_id);

-- 2. Add dedicated is_meetup_confirmed column to orders
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_meetup_confirmed BOOLEAN NOT NULL DEFAULT FALSE;

-- 3. Backfill any existing confirmed orders
UPDATE orders SET is_meetup_confirmed = TRUE WHERE client_action_id = 'MEETUP_CONFIRMED' OR meetup_otp_verified = TRUE;

-- 4. Clear static client_action_id values so future queries are clean
UPDATE orders SET client_action_id = NULL WHERE client_action_id IN ('MEETUP_CONFIRMED', 'MEETUP_SCHEDULED');
