-- V25: Add chat message idempotency, delivery/read status, media attachments, and performance indexes

ALTER TABLE chat_messages
    ADD COLUMN IF NOT EXISTS client_message_id VARCHAR(64),
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'SENT',
    ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS media_url TEXT,
    ADD COLUMN IF NOT EXISTS metadata TEXT;

-- Enforce clientMessageId idempotency per room
CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_messages_client_id
    ON chat_messages (room_id, client_message_id)
    WHERE client_message_id IS NOT NULL;

-- High-performance deterministic message ordering index
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_created_id
    ON chat_messages (room_id, created_at DESC, id DESC);

-- Unread message lookup index
CREATE INDEX IF NOT EXISTS idx_chat_messages_unread
    ON chat_messages (room_id, sender_id, read_at)
    WHERE read_at IS NULL;

-- Room sorting index for real-time conversation list
CREATE INDEX IF NOT EXISTS idx_chat_rooms_updated_at
    ON chat_rooms (updated_at DESC);
