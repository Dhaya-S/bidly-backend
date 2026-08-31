package com.bidly;

import org.junit.jupiter.api.Test;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

public class CleanDatabaseTest {

    @Test
    void cleanDummyData() throws Exception {
        String dbUrl = "jdbc:postgresql://ep-fragrant-union-ayftexwy-pooler.c-5.us-east-2.aws.neon.tech/neondb?sslmode=require";
        String user = "neondb_owner";
        String pass = "npg_BLlnutq2yzo0";

        try (Connection conn = DriverManager.getConnection(dbUrl, user, pass);
             Statement stmt = conn.createStatement()) {

            System.out.println("=== CLEANING DUMMY DATA FROM NEON DB ===");

            // 1. Clean listing_media with unsplash.com dummy images
            int deletedMedia = stmt.executeUpdate("DELETE FROM listing_media WHERE url LIKE '%unsplash.com%' OR listing_id IN (SELECT id FROM listings WHERE title IN ('Phone', 'iPhone 13', 'iPhone 14 Pro Max', 'Gaming Laptop', 'Sony Headphones', 'Smart Watch', 'Study Chair', 'PS5 Controller', 'Monitor 27\"', 'Canon DSLR'))");
            System.out.println("Deleted dummy listing media: " + deletedMedia);

            // 2. Clean dummy listings
            int deletedListings = stmt.executeUpdate("DELETE FROM listings WHERE title IN ('Phone', 'iPhone 13', 'iPhone 14 Pro Max', 'Gaming Laptop', 'Sony Headphones', 'Smart Watch', 'Study Chair', 'PS5 Controller', 'Monitor 27\"', 'Canon DSLR')");
            System.out.println("Deleted dummy listings: " + deletedListings);

            // 3. Clean dummy communities (seeded IDs: a1111111-..., a2222222-..., a3333333-..., a4444444-..., etc.)
            int deletedCommMembers = stmt.executeUpdate("DELETE FROM community_members WHERE community_id IN ('a1111111-1111-1111-1111-111111111111', 'a2222222-2222-2222-2222-222222222222', 'a3333333-3333-3333-3333-333333333333', 'a4444444-4444-4444-4444-444444444444', '5cac5c7b-9433-4ed1-b486-ad9c5ada9dde', 'a464ff1c-63d4-433f-b11c-7d2231b29e6a', '8f24e3a9-2782-40a1-aedc-28f968a75aaa')");
            System.out.println("Deleted dummy community members: " + deletedCommMembers);

            int deletedCommunities = stmt.executeUpdate("DELETE FROM communities WHERE id IN ('a1111111-1111-1111-1111-111111111111', 'a2222222-2222-2222-2222-222222222222', 'a3333333-3333-3333-3333-333333333333', 'a4444444-4444-4444-4444-444444444444', '5cac5c7b-9433-4ed1-b486-ad9c5ada9dde', 'a464ff1c-63d4-433f-b11c-7d2231b29e6a', '8f24e3a9-2782-40a1-aedc-28f968a75aaa')");
            System.out.println("Deleted dummy communities: " + deletedCommunities);

            // 4. Print remaining live listings
            System.out.println("\n=== REMAINING LIVE LISTINGS ===");
            try (ResultSet rs = stmt.executeQuery("SELECT id, title, price, city FROM listings")) {
                while (rs.next()) {
                    System.out.println("Listing: " + rs.getString("id") + " | " + rs.getString("title") + " | ₹" + rs.getString("price") + " | " + rs.getString("city"));
                }
            }

            // 5. Print remaining live communities
            System.out.println("\n=== REMAINING LIVE COMMUNITIES ===");
            try (ResultSet rs = stmt.executeQuery("SELECT id, name, category, city FROM communities")) {
                while (rs.next()) {
                    System.out.println("Community: " + rs.getString("id") + " | " + rs.getString("name") + " | " + rs.getString("category") + " | " + rs.getString("city"));
                }
            }
        }
    }
}
