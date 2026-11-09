-- V32: Seed diverse, verified playable marketplace video reels for rich infinite scroll
DO $$
DECLARE
    seller_arun UUID := 'c0d02ec2-54d4-43a0-9204-89da3bcc09ac';
    seller_meena UUID := 'eafbeeb7-443e-4e15-a3eb-296b6f859f72';
    seller_priya UUID := '189520ea-f8f6-4039-891c-0b3f931d52f0';
    seller_karthik UUID := '2f5c43aa-ad54-43f0-a2b5-389fbff94b26';
    seller_balu UUID := '065a1ef0-640a-44f1-bef8-7fb8052993e0';

    cat_electronics UUID := '77de57a7-015c-442a-bc4b-1e2f57711a6d';
    cat_smartphones UUID := 'd01716cd-aa9a-4774-97cc-e5971b9f5b98';
    cat_cameras UUID := '82a9cd4a-3356-4e2e-9577-596bb5906ba4';
    cat_gaming UUID := '352cdc96-3620-4075-8dd9-47557d6dcbdc';
    cat_vehicles UUID := '4337fee0-8ca1-48fb-a2c0-600bc76ed1d7';
    cat_computers UUID := '2813536b-2e3e-488b-912e-29340d000ba6';

    -- Verified working MP4 video files in R2 storage
    v_drone_1 TEXT := 'listings/reels/0ecbfca6-7b9d-4a0e-bddb-f85130707c24.mp4';
    t_drone_1 TEXT := 'listings/reels/0ecbfca6-7b9d-4a0e-bddb-f85130707c24-thumb.jpg';

    v_drone_2 TEXT := 'listings/reels/382e2f5d-ee5d-483e-b8da-ebac57bbbe81.mp4';
    t_drone_2 TEXT := 'listings/reels/382e2f5d-ee5d-483e-b8da-ebac57bbbe81-thumb.jpg';

    v_tech_1 TEXT := 'listings/reels/af3a22c9-4f9f-4e3f-9c6b-866de4b6afbb.mp4';
    t_tech_1 TEXT := 'listings/reels/af3a22c9-4f9f-4e3f-9c6b-866de4b6afbb-thumb.jpg';

    v_phone_1 TEXT := 'listings/reels/e9051d37-4e63-47d8-ab86-ca2342881598.mp4';
    t_phone_1 TEXT := 'listings/reels/e9051d37-4e63-47d8-ab86-ca2342881598-thumb.jpg';

    v_cam_1 TEXT := 'listings/reels/ca51b768-4609-4532-ba2d-fe59d1b69c3c.mp4';
    t_cam_1 TEXT := 'listings/reels/ca51b768-4609-4532-ba2d-fe59d1b69c3c-thumb.jpg';

    v_gadget_1 TEXT := 'listings/reels/bff21717-78ab-432c-bfc6-dd92ffdb16c5.mp4';
    t_gadget_1 TEXT := 'listings/reels/bff21717-78ab-432c-bfc6-dd92ffdb16c5-thumb.jpg';

    v_device_1 TEXT := 'listings/reels/a707ed5f-d384-437e-ac13-af55d97d10f0.mp4';
    t_device_1 TEXT := 'listings/reels/a707ed5f-d384-437e-ac13-af55d97d10f0-thumb.jpg';

    v_device_2 TEXT := 'listings/reels/003c4502-99da-453f-96ae-c66560adda92.mp4';
    t_device_2 TEXT := 'listings/reels/003c4502-99da-453f-96ae-c66560adda92-thumb.jpg';

    v_device_3 TEXT := 'listings/reels/57eff038-2863-422e-87ce-c10ebaa0afec.mp4';
    t_device_3 TEXT := 'listings/reels/57eff038-2863-422e-87ce-c10ebaa0afec-thumb.jpg';

    v_drone_3 TEXT := 'listings/reels/51788b5f-f434-490b-b33d-91e6445c02e9.mp4';
    t_drone_3 TEXT := 'listings/reels/51788b5f-f434-490b-b33d-91e6445c02e9-thumb.jpg';
BEGIN
    -- 1. Sony PlayStation 5 Slim
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_karthik, cat_gaming, 'Sony PlayStation 5 Slim (1TB Disc Edition)', 'Mint condition PS5 Slim with 2 DualSense controllers and Spider-Man 2 included. Barely used 2 months.', 42999.00, 'LIKE_NEW', 'DIRECT_BUY', 'ACTIVE', v_device_1, t_device_1, 'READY', 'Bangalore', 'Karnataka', 'Indiranagar', 24, 4.9, NOW() - INTERVAL '1 hour', NOW());

    -- 2. Apple MacBook Air M3
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_priya, cat_computers, 'MacBook Air 15" M3 - Midnight (16GB/512GB)', 'Stunning M3 MacBook Air with AppleCare+ until 2027. Battery health 100%, 18 cycles only. Box and original MagSafe charger included.', 98500.00, 'LIKE_NEW', 'DIRECT_BUY', 'ACTIVE', v_tech_1, t_tech_1, 'READY', 'Chennai', 'Tamil Nadu', 'Adyar', 38, 5.0, NOW() - INTERVAL '2 hours', NOW());

    -- 3. DJI Avata 2 FPV Drone Fly More Combo (AUCTION)
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, starting_bid, current_bid, bid_increment, auction_end_time, bids_count, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_arun, cat_cameras, 'DJI Avata 2 FPV Drone Fly More Combo', 'Full FPV kit with Goggles 3, Motion Controller 3, and 3 batteries. Crisp 4K/60fps HDR video. Test flight reel attached!', 75000.00, 'EXCELLENT', 'AUCTION', 'ACTIVE', v_drone_1, t_drone_1, 'READY', 45000.00, 52000.00, 1000.00, NOW() + INTERVAL '3 days', 7, 'Bangalore', 'Karnataka', 'Koramangala', 42, 4.9, NOW() - INTERVAL '3 hours', NOW());

    -- 4. Canon EOS R6 Mark II Mirrorless Camera
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_meena, cat_cameras, 'Canon EOS R6 Mark II + 24-105mm F4 L IS USM', 'Professional hybrid camera. 24.2MP full-frame, 40fps electronic shutter, 6K RAW HDMI out. Shutter count under 3,000.', 185000.00, 'EXCELLENT', 'DIRECT_BUY', 'ACTIVE', v_cam_1, t_cam_1, 'READY', 'Mumbai', 'Maharashtra', 'Bandra West', 56, 4.95, NOW() - INTERVAL '4 hours', NOW());

    -- 5. iPhone 15 Pro Max Natural Titanium (AUCTION)
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, starting_bid, current_bid, bid_increment, auction_end_time, bids_count, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_balu, cat_smartphones, 'Apple iPhone 15 Pro Max 256GB Titanium', 'Clean pristine condition with Spigen case and tempered glass since day one. 99% battery health. Live auction!', 110000.00, 'LIKE_NEW', 'AUCTION', 'ACTIVE', v_phone_1, t_phone_1, 'READY', 70000.00, 84000.00, 2000.00, NOW() + INTERVAL '2 days', 11, 'Chennai', 'Tamil Nadu', 'OMR', 65, 4.85, NOW() - INTERVAL '5 hours', NOW());

    -- 6. Nothing Phone (2) Dark Edition
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_karthik, cat_smartphones, 'Nothing Phone (2) 12GB/256GB Dark Grey', 'Unique Glyph interface with Snapdragon 8+ Gen 1. Smooth 120Hz LTPO display. Bill, box, and unused cable.', 29500.00, 'EXCELLENT', 'DIRECT_BUY', 'ACTIVE', v_device_2, t_device_2, 'READY', 'Bangalore', 'Karnataka', 'HSR Layout', 19, 4.8, NOW() - INTERVAL '6 hours', NOW());

    -- 7. Bose QuietComfort Ultra Wireless Headphones
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_priya, cat_electronics, 'Bose QuietComfort Ultra ANC Headphones', 'World-class active noise cancellation with immersive spatial audio. Used for only 3 flights. Immaculate condition with hard case.', 23500.00, 'LIKE_NEW', 'DIRECT_BUY', 'ACTIVE', v_gadget_1, t_gadget_1, 'READY', 'Hyderabad', 'Telangana', 'Jubilee Hills', 31, 4.9, NOW() - INTERVAL '7 hours', NOW());

    -- 8. Apple Watch Ultra 2 (Titanium & Alpine Loop)
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_arun, cat_electronics, 'Apple Watch Ultra 2 GPS + Cellular 49mm', 'Rugged 49mm titanium case with sapphire crystal glass. 3000 nits brightness. Includes Orange Alpine loop and Midnight Ocean band.', 62000.00, 'EXCELLENT', 'DIRECT_BUY', 'ACTIVE', v_device_3, t_device_3, 'READY', 'Bangalore', 'Karnataka', 'Whitefield', 45, 4.9, NOW() - INTERVAL '8 hours', NOW());

    -- 9. Yamaha R15 V4 Racing Blue (AUCTION)
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, starting_bid, current_bid, bid_increment, auction_end_time, bids_count, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_balu, cat_vehicles, '2023 Yamaha R15 V4 Dual ABS Racing Blue', 'Single owner, 8,200 km genuine reading. Quickshifter, traction control, Bluetooth Y-Connect. Insured till late 2027.', 155000.00, 'EXCELLENT', 'AUCTION', 'ACTIVE', v_drone_2, t_drone_2, 'READY', 100000.00, 118000.00, 3000.00, NOW() + INTERVAL '4 days', 9, 'Chennai', 'Tamil Nadu', 'Velachery', 82, 4.95, NOW() - INTERVAL '9 hours', NOW());

    -- 10. Royal Enfield Continental GT 650
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_meena, cat_vehicles, 'Royal Enfield Continental GT 650 British Racing Green', 'Cafe racer twin cylinder 648cc. Red Rooster exhausts (originals also provided), touring seat, bar-end mirrors. Only 5,400 kms.', 280000.00, 'LIKE_NEW', 'DIRECT_BUY', 'ACTIVE', v_drone_3, t_drone_3, 'READY', 'Pune', 'Maharashtra', 'Koregaon Park', 94, 5.0, NOW() - INTERVAL '10 hours', NOW());

    -- 11. iPad Pro 13" M4 OLED 256GB Space Black
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_priya, cat_computers, 'Apple iPad Pro 13" M4 Ultra Retina XDR OLED', 'The thinnest Apple product ever made with dual-layer OLED. Includes Apple Pencil Pro and Magic Keyboard.', 115000.00, 'LIKE_NEW', 'DIRECT_BUY', 'ACTIVE', v_tech_1, t_tech_1, 'READY', 'Chennai', 'Tamil Nadu', 'T Nagar', 49, 4.9, NOW() - INTERVAL '11 hours', NOW());

    -- 12. Fujifilm X100VI Digital Camera (Silver) (AUCTION)
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, starting_bid, current_bid, bid_increment, auction_end_time, bids_count, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_karthik, cat_cameras, 'Fujifilm X100VI 40.2MP Film Simulation Camera', 'Highly sought after hybrid compact with IBIS and 20 Film Simulation recipes. Brand new condition with lens hood and thumb grip.', 165000.00, 'NEW', 'AUCTION', 'ACTIVE', v_cam_1, t_cam_1, 'READY', 120000.00, 142000.00, 2000.00, NOW() + INTERVAL '5 days', 14, 'Bangalore', 'Karnataka', 'MG Road', 103, 5.0, NOW() - INTERVAL '12 hours', NOW());

    -- 13. Google Pixel 8 Pro Bay Blue 256GB
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_arun, cat_smartphones, 'Google Pixel 8 Pro Bay Blue (256GB / 12GB)', 'Best-in-class AI computational photography with 7 years of OS updates. Flawless condition with original Google silicone case.', 56000.00, 'LIKE_NEW', 'DIRECT_BUY', 'ACTIVE', v_phone_1, t_phone_1, 'READY', 'Delhi', 'Delhi', 'Connaught Place', 27, 4.8, NOW() - INTERVAL '13 hours', NOW());

    -- 14. GoPro HERO12 Black Creator Edition
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_balu, cat_cameras, 'GoPro HERO12 Black Creator Edition Bundle', '5.3K60 HDR video, Volta battery grip, Media Mod, Light Mod, and 2 Enduro batteries. Ready for motovlog and adventure.', 36000.00, 'EXCELLENT', 'DIRECT_BUY', 'ACTIVE', v_device_2, t_device_2, 'READY', 'Chennai', 'Tamil Nadu', 'Besant Nagar', 35, 4.85, NOW() - INTERVAL '14 hours', NOW());

    -- 15. Steam Deck OLED 512GB Handheld Console
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_meena, cat_gaming, 'Valve Steam Deck OLED 512GB Handheld PC', 'Gorgeous 90Hz HDR OLED screen with significantly improved battery life and lighter body. Comes with carry case and dock.', 48500.00, 'LIKE_NEW', 'DIRECT_BUY', 'ACTIVE', v_device_1, t_device_1, 'READY', 'Mumbai', 'Maharashtra', 'Powai', 60, 4.9, NOW() - INTERVAL '15 hours', NOW());

    -- 16. Marshall Stanmore III Bluetooth Home Speaker
    INSERT INTO listings (id, seller_id, category_id, title, description, price, condition, selling_method, status, reel_url, primary_image_url, media_processing_status, city, state, locality, likes_count, rating, created_at, updated_at)
    VALUES (gen_random_uuid(), seller_priya, cat_electronics, 'Marshall Stanmore III Wireless Speaker - Black', 'Classic vintage Marshall brass accents with room-filling spatial stereo sound. Mint condition in original packaging.', 27000.00, 'LIKE_NEW', 'DIRECT_BUY', 'ACTIVE', v_gadget_1, t_gadget_1, 'READY', 'Bangalore', 'Karnataka', 'Lavelle Road', 41, 4.9, NOW() - INTERVAL '16 hours', NOW());

END $$;
