-- ====================================================================
-- Flyway Migration V23: Seed verified eligible Reels for infinite feed pagination
-- ====================================================================

DO $$
DECLARE
    seller_id UUID;
    cat_electronics UUID;
    cat_fashion UUID;
    cat_vehicles UUID;
    cat_home UUID;
    video_1 TEXT := 'listings/reels/48ed0968-1aaf-4886-881d-f353e8ffc356.mp4';
    thumb_1 TEXT := 'listings/reels/48ed0968-1aaf-4886-881d-f353e8ffc356-thumb.jpg';
    video_2 TEXT := 'listings/reels/b0e08cf6-47c2-43cd-873a-6d5d04120cb1.mp4';
    thumb_2 TEXT := 'listings/photos/ed032cb6-ece2-476f-b197-48b44d43e8b3.jpg';
    video_3 TEXT := 'listings/reels/4b6f283b-7a46-4b2a-9841-45f99afbbeab.mp4';
    thumb_3 TEXT := 'listings/reels/4b6f283b-7a46-4b2a-9841-45f99afbbeab-thumb.jpg';
    now_ts TIMESTAMPTZ := NOW();
    i INT;
    new_listing_id UUID;
    chosen_video TEXT;
    chosen_thumb TEXT;
    chosen_cat UUID;
    chosen_method TEXT;
    auction_end TIMESTAMPTZ;
BEGIN
    -- Pick an active seller
    SELECT id INTO seller_id FROM users WHERE is_active = true ORDER BY trust_score DESC LIMIT 1;
    IF seller_id IS NULL THEN
        SELECT id INTO seller_id FROM users LIMIT 1;
    END IF;

    -- Pick categories
    SELECT id INTO cat_electronics FROM categories WHERE name ILIKE '%electronics%' LIMIT 1;
    SELECT id INTO cat_fashion FROM categories WHERE name ILIKE '%fashion%' LIMIT 1;
    SELECT id INTO cat_vehicles FROM categories WHERE name ILIKE '%vehicle%' LIMIT 1;
    SELECT id INTO cat_home FROM categories WHERE name ILIKE '%home%' LIMIT 1;
    IF cat_electronics IS NULL THEN SELECT id INTO cat_electronics FROM categories LIMIT 1; END IF;

    -- Seed 20 active reels with distinct created_at to test multi-page scrolling
    FOR i IN 1..20 LOOP
        new_listing_id := gen_random_uuid();
        
        -- Cycle verified videos
        IF (i % 3 = 0) THEN
            chosen_video := video_1;
            chosen_thumb := thumb_1;
            chosen_cat := COALESCE(cat_electronics, cat_electronics);
        ELSIF (i % 3 = 1) THEN
            chosen_video := video_2;
            chosen_thumb := thumb_2;
            chosen_cat := COALESCE(cat_fashion, cat_electronics);
        ELSE
            chosen_video := video_3;
            chosen_thumb := thumb_3;
            chosen_cat := COALESCE(cat_vehicles, cat_electronics);
        END IF;

        -- Alternate between DIRECT_BUY and AUCTION
        IF (i % 2 = 0) THEN
            chosen_method := 'DIRECT_BUY';
            auction_end := NULL;
        ELSE
            chosen_method := 'AUCTION';
            auction_end := now_ts + INTERVAL '10 days';
        END IF;

        INSERT INTO listings (
            id, seller_id, category_id, title, description,
            price, starting_bid, current_bid, bid_increment, auction_end_time,
            selling_method, selling_scope, status, condition,
            reel_url, primary_image_url, rating, likes_count, bids_count,
            created_at, updated_at
        ) VALUES (
            new_listing_id, seller_id, chosen_cat,
            CASE 
                WHEN i = 1 THEN 'Sony Alpha 7 IV 4K Mirrorless Camera'
                WHEN i = 2 THEN 'Apple MacBook Pro M3 Max 16-inch'
                WHEN i = 3 THEN 'DJI Mavic 3 Pro Cine Drone'
                WHEN i = 4 THEN 'Bose QuietComfort Ultra Headphones'
                WHEN i = 5 THEN 'Yamaha R15 V4 Racing Edition'
                WHEN i = 6 THEN 'Samsung Galaxy S24 Ultra 512GB'
                WHEN i = 7 THEN 'Canon EOS R6 Mark II + 24-70mm'
                WHEN i = 8 THEN 'PlayStation 5 Pro Digital Edition'
                WHEN i = 9 THEN 'Marshall Stanmore III Bluetooth Speaker'
                WHEN i = 10 THEN 'Royal Enfield Continental GT 650'
                WHEN i = 11 THEN 'iPad Pro 13-inch M4 OLED 256GB'
                WHEN i = 12 THEN 'Fujifilm X-T5 Mirrorless Body'
                WHEN i = 13 THEN 'GoPro Hero 12 Black Creator Edition'
                WHEN i = 14 THEN 'Garmin Fenix 7 Pro Solar Edition'
                WHEN i = 15 THEN 'KTM Duke 390 Gen 3 Track Spec'
                WHEN i = 16 THEN 'Sennheiser Momentum 4 Wireless'
                WHEN i = 17 THEN 'ASUS ROG Zephyrus G16 OLED Gaming'
                WHEN i = 18 THEN 'OnePlus 12 5G Emerald Green'
                WHEN i = 19 THEN 'Insta360 X4 8K 360 Action Cam'
                ELSE 'Vintage Leather Motorcycle Jacket'
            END,
            'Verified authentic listing with full documentation, warranty, and fast shipping across India.',
            (500 + (i * 250))::NUMERIC(12,2),
            CASE WHEN chosen_method = 'AUCTION' THEN (400 + (i * 200))::NUMERIC(12,2) ELSE NULL END,
            CASE WHEN chosen_method = 'AUCTION' THEN (450 + (i * 210))::NUMERIC(12,2) ELSE NULL END,
            CASE WHEN chosen_method = 'AUCTION' THEN 50.00 ELSE NULL END,
            auction_end,
            chosen_method,
            'GLOBAL',
            'ACTIVE',
            'LIKE_NEW',
            chosen_video,
            chosen_thumb,
            4.8,
            (i % 5),
            CASE WHEN chosen_method = 'AUCTION' THEN (i % 7) ELSE 0 END,
            -- Distinct descending timestamps to guarantee deterministic pagination
            now_ts - (i * INTERVAL '15 minutes'),
            now_ts - (i * INTERVAL '15 minutes')
        );

        -- Add listing_media entry
        INSERT INTO listing_media (
            id, listing_id, url, type, sort_order, created_at
        ) VALUES (
            gen_random_uuid(), new_listing_id, chosen_video, 'VIDEO', 0, now_ts - (i * INTERVAL '15 minutes')
        );
    END LOOP;
END $$;
