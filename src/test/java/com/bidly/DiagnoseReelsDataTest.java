package com.bidly;

import org.junit.jupiter.api.Test;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

public class DiagnoseReelsDataTest {

    @Test
    void testReelCounts() throws Exception {
        String dbUrl = "jdbc:postgresql://ep-fragrant-union-ayftexwy-pooler.c-5.us-east-2.aws.neon.tech/neondb?sslmode=require";
        String user = "neondb_owner";
        String pass = "npg_BLlnutq2yzo0";

        try (Connection conn = DriverManager.getConnection(dbUrl, user, pass);
             Statement stmt = conn.createStatement()) {

            System.out.println("=== LISTING AUDIT ===");
            ResultSet rs = stmt.executeQuery("SELECT id, title, status, reel_url, selling_method, auction_end_time, created_at FROM listings ORDER BY created_at DESC");
            int count = 0;
            while (rs.next()) {
                count++;
                System.out.println(count + ". " + rs.getString("title") + " | status=" + rs.getString("status") + " | reel=" + (rs.getString("reel_url") != null) + " | method=" + rs.getString("selling_method") + " | created=" + rs.getString("created_at"));
            }

            rs = stmt.executeQuery("SELECT count(*) FROM listings WHERE status = 'ACTIVE' AND reel_url IS NOT NULL AND TRIM(reel_url) <> '' AND (selling_method <> 'AUCTION' OR auction_end_time IS NULL OR auction_end_time > CURRENT_TIMESTAMP)");
            if (rs.next()) System.out.println("Eligible active reels: " + rs.getInt(1));
        }
    }
}
