-- V6__fix_floating_point_types.sql
-- Converts rating and distance_km to DOUBLE PRECISION for Hibernate compatibility

ALTER TABLE listings ALTER COLUMN rating TYPE DOUBLE PRECISION;
ALTER TABLE listings ALTER COLUMN distance_km TYPE DOUBLE PRECISION;
