-- Update transcoded legacy listings with their optimized H.264 FastStart URLs and posters
UPDATE listings
SET reel_url = 'listings/reels/e9051d37-4e63-47d8-ab86-ca2342881598.mp4',
    primary_image_url = 'listings/reels/e9051d37-4e63-47d8-ab86-ca2342881598-thumb.jpg'
WHERE id = '06a0a01a-e6ef-4145-99ae-a13b1075af64';

UPDATE listings
SET reel_url = 'listings/reels/4b6f283b-7a46-4b2a-9841-45f99afbbeab.mp4',
    primary_image_url = 'listings/reels/4b6f283b-7a46-4b2a-9841-45f99afbbeab-thumb.jpg'
WHERE id = 'e4666d44-8b97-4251-b80b-940ef0774781';

UPDATE listings
SET reel_url = 'listings/reels/48ed0968-1aaf-4886-881d-f353e8ffc356.mp4',
    primary_image_url = 'listings/reels/48ed0968-1aaf-4886-881d-f353e8ffc356-thumb.jpg'
WHERE id = 'd2e6de93-bf3e-431e-9cff-8458ae845b29';

-- Deactivate remaining untranscoded legacy test listings with invalid camera HEVC
UPDATE listings
SET status = 'DELETED', reel_url = NULL
WHERE id IN (
    'b067cfc1-18c1-4e3f-877b-b3cad25032d2',
    '35179162-5e21-41e9-917a-e8c623ffaeb1',
    'c7f8fe87-739d-4370-b93e-b4c44ace9cd6'
);
