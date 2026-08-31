-- V12: Chat system -- rooms and messages for buyer-seller negotiation

CREATE TABLE chat_rooms (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id      UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    buyer_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    seller_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status          VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    last_message_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_chat_room UNIQUE (listing_id, buyer_id)
);

CREATE INDEX idx_chat_rooms_buyer   ON chat_rooms (buyer_id);
CREATE INDEX idx_chat_rooms_seller  ON chat_rooms (seller_id);
CREATE INDEX idx_chat_rooms_listing ON chat_rooms (listing_id);

CREATE TABLE chat_messages (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id      UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    sender_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content      TEXT,
    offer_amount NUMERIC(12, 2),
    type         VARCHAR(20) NOT NULL DEFAULT 'TEXT',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_chat_messages_room   ON chat_messages (room_id, created_at);
CREATE INDEX idx_chat_messages_sender ON chat_messages (sender_id);
