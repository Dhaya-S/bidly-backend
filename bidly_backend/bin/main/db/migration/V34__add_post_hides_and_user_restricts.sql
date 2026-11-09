-- ============================================================
-- V34: Add post_hides and user_restricts tables
-- Powers "Not Interested" and "Restrict" features on posts
-- ============================================================

-- Table: post_hides — tracks which posts a user has hidden
CREATE TABLE IF NOT EXISTS post_hides (
    user_id UUID NOT NULL,
    post_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id),
    CONSTRAINT fk_post_hides_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_post_hides_post FOREIGN KEY (post_id) REFERENCES community_posts(id) ON DELETE CASCADE
);

-- Table: user_restricts — tracks which users someone has restricted
CREATE TABLE IF NOT EXISTS user_restricts (
    user_id UUID NOT NULL,
    restricted_user_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, restricted_user_id),
    CONSTRAINT fk_user_restricts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_restricts_restricted FOREIGN KEY (restricted_user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Indexes for fast lookup during feed queries
CREATE INDEX IF NOT EXISTS idx_post_hides_user_id ON post_hides(user_id);
CREATE INDEX IF NOT EXISTS idx_user_restricts_user_id ON user_restricts(user_id);
