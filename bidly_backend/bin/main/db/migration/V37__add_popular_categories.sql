-- V37: Ensure popular categories (Smartphones, Gaming, Cameras, Computers) exist
INSERT INTO categories (name, icon_url, sort_order, is_active)
SELECT 'Smartphones', NULL, 2, TRUE
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name ILIKE '%smartphone%');

INSERT INTO categories (name, icon_url, sort_order, is_active)
SELECT 'Gaming', NULL, 4, TRUE
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name ILIKE '%gaming%');

INSERT INTO categories (name, icon_url, sort_order, is_active)
SELECT 'Cameras', NULL, 5, TRUE
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name ILIKE '%camera%');

INSERT INTO categories (name, icon_url, sort_order, is_active)
SELECT 'Computers & Laptops', NULL, 6, TRUE
WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name ILIKE '%computer%');

