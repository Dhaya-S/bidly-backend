-- V36: Create order reports table for disputes & moderation
CREATE TABLE IF NOT EXISTS order_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason VARCHAR(255) NOT NULL,
    details TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING_REVIEW',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_reports_order ON order_reports(order_id);
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON order_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON order_reports(status);
