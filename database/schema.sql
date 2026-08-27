-- ==========================================
-- NEO SOCIAL DATABASE
-- ==========================================

-- USERS
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,

    email TEXT UNIQUE NOT NULL,

    username TEXT UNIQUE NOT NULL,

    password_hash TEXT NOT NULL,

    role TEXT NOT NULL DEFAULT 'user',

    neo_tier INTEGER NOT NULL DEFAULT 0,

    pfp_url TEXT,

    banner_url TEXT,

    bio TEXT,

    banned_until TIMESTAMPTZ,

    muted_until TIMESTAMPTZ,

    strikes INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ==========================================
-- POSTS
-- ==========================================

CREATE TABLE IF NOT EXISTS posts (
    id BIGSERIAL PRIMARY KEY,

    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    body TEXT NOT NULL DEFAULT '',

    media_url TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    deleted_at TIMESTAMPTZ
);


-- ==========================================
-- REACTIONS
-- ==========================================

CREATE TABLE IF NOT EXISTS reactions (
    id BIGSERIAL PRIMARY KEY,

    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    post_id BIGINT NOT NULL
        REFERENCES posts(id)
        ON DELETE CASCADE,

    type TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(user_id, post_id)
);


-- ==========================================
-- COMMENTS
-- Supports nested replies
-- ==========================================

CREATE TABLE IF NOT EXISTS comments (
    id BIGSERIAL PRIMARY KEY,

    post_id BIGINT NOT NULL
        REFERENCES posts(id)
        ON DELETE CASCADE,

    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    parent_id BIGINT
        REFERENCES comments(id)
        ON DELETE CASCADE,

    body TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    deleted_at TIMESTAMPTZ
);


-- ==========================================
-- FOLLOW SYSTEM
-- ==========================================

CREATE TABLE IF NOT EXISTS follows (
    follower_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    following_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (
        follower_id,
        following_id
    ),

    CHECK (
        follower_id <> following_id
    )
);


-- ==========================================
-- FRIEND SYSTEM
-- ==========================================

CREATE TABLE IF NOT EXISTS friendships (
    id BIGSERIAL PRIMARY KEY,

    requester_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    receiver_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    status TEXT NOT NULL DEFAULT 'pending',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (
        requester_id <> receiver_id
    )
);


-- ==========================================
-- STORIES
-- Automatically considered expired
-- after 24 hours using created_at
-- ==========================================

CREATE TABLE IF NOT EXISTS stories (
    id BIGSERIAL PRIMARY KEY,

    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    body TEXT,

    media_url TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ==========================================
-- MESSAGES
-- ==========================================

CREATE TABLE IF NOT EXISTS messages (
    id BIGSERIAL PRIMARY KEY,

    sender_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    receiver_id BIGINT
        REFERENCES users(id)
        ON DELETE CASCADE,

    group_id BIGINT,

    body TEXT NOT NULL DEFAULT '',

    media_url TEXT,

    reply_to_id BIGINT
        REFERENCES messages(id)
        ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    deleted_at TIMESTAMPTZ
);


-- ==========================================
-- GROUPS / COMMUNITIES
-- ==========================================

CREATE TABLE IF NOT EXISTS communities (
    id BIGSERIAL PRIMARY KEY,

    owner_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    name TEXT NOT NULL,

    description TEXT DEFAULT '',

    avatar_url TEXT,

    banner_url TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ==========================================
-- COMMUNITY MEMBERS
-- ==========================================

CREATE TABLE IF NOT EXISTS community_members (
    community_id BIGINT NOT NULL
        REFERENCES communities(id)
        ON DELETE CASCADE,

    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    role TEXT NOT NULL DEFAULT 'member',

    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (
        community_id,
        user_id
    )
);


-- ==========================================
-- NOTIFICATIONS
-- ==========================================

CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,

    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    actor_id BIGINT
        REFERENCES users(id)
        ON DELETE CASCADE,

    type TEXT NOT NULL,

    message TEXT NOT NULL,

    post_id BIGINT
        REFERENCES posts(id)
        ON DELETE CASCADE,

    is_read BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ==========================================
-- REPOSTS
-- ==========================================

CREATE TABLE IF NOT EXISTS reposts (
    id BIGSERIAL PRIMARY KEY,

    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    post_id BIGINT NOT NULL
        REFERENCES posts(id)
        ON DELETE CASCADE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(user_id, post_id)
);


-- ==========================================
-- HASHTAGS
-- ==========================================

CREATE TABLE IF NOT EXISTS hashtags (
    id BIGSERIAL PRIMARY KEY,

    tag TEXT UNIQUE NOT NULL
);


-- ==========================================
-- POST HASHTAGS
-- ==========================================

CREATE TABLE IF NOT EXISTS post_hashtags (
    post_id BIGINT NOT NULL
        REFERENCES posts(id)
        ON DELETE CASCADE,

    hashtag_id BIGINT NOT NULL
        REFERENCES hashtags(id)
        ON DELETE CASCADE,

    PRIMARY KEY (
        post_id,
        hashtag_id
    )
);


-- ==========================================
-- MENTIONS
-- ==========================================

CREATE TABLE IF NOT EXISTS mentions (
    id BIGSERIAL PRIMARY KEY,

    post_id BIGINT NOT NULL
        REFERENCES posts(id)
        ON DELETE CASCADE,

    mentioned_user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE
);


-- ==========================================
-- ACTIVITY / AUDIT LOG
-- ==========================================

CREATE TABLE IF NOT EXISTS activity_logs (
    id BIGSERIAL PRIMARY KEY,

    actor_id BIGINT
        REFERENCES users(id)
        ON DELETE SET NULL,

    action TEXT NOT NULL,

    target_type TEXT,

    target_id BIGINT,

    metadata JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ==========================================
-- NEO TRANSACTIONS
-- Developer grants/removes Neo
-- ==========================================

CREATE TABLE IF NOT EXISTS neo_transactions (
    id BIGSERIAL PRIMARY KEY,

    developer_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    tier INTEGER NOT NULL,

    action TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ==========================================
-- INDEXES
-- ==========================================

CREATE INDEX IF NOT EXISTS
idx_posts_created
ON posts(created_at DESC);


CREATE INDEX IF NOT EXISTS
idx_comments_post
ON comments(post_id);


CREATE INDEX IF NOT EXISTS
idx_comments_parent
ON comments(parent_id);


CREATE INDEX IF NOT EXISTS
idx_stories_created
ON stories(created_at DESC);


CREATE INDEX IF NOT EXISTS
idx_messages_sender
ON messages(sender_id);


CREATE INDEX IF NOT EXISTS
idx_messages_receiver
ON messages(receiver_id);


CREATE INDEX IF NOT EXISTS
idx_notifications_user
ON notifications(user_id);


CREATE INDEX IF NOT EXISTS
idx_activity_created
ON activity_logs(created_at DESC);


-- ==========================================
-- 24-HOUR STORY HELPER
-- ==========================================

CREATE OR REPLACE VIEW active_stories AS
SELECT *
FROM stories
WHERE created_at >= NOW() - INTERVAL '24 hours';
