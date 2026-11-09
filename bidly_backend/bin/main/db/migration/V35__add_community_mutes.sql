-- ============================================================
-- V35: Add community_mutes table
-- Tracks which communities a user has muted notifications for
-- ============================================================

CREATE TABLE IF NOT EXISTS community_mutes (
    user_id UUID NOT NULL,
    community_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, community_id),
    CONSTRAINT fk_community_mutes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_community_mutes_community FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_community_mutes_user ON community_mutes(user_id);
CREATE INDEX IF NOT EXISTS idx_community_mutes_community ON community_mutes(community_id);
