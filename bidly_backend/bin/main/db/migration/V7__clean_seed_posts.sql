-- V7__clean_seed_posts.sql
-- Removes hardcoded default posts so only real user posts are displayed in the feed

DELETE FROM post_likes;
DELETE FROM community_posts;
