package com.bidly;

import org.junit.jupiter.api.Test;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

public class CheckNeonDataTest {

    @Test
    void checkData() throws Exception {
        String dbUrl = "jdbc:postgresql://ep-fragrant-union-ayftexwy-pooler.c-5.us-east-2.aws.neon.tech/neondb?sslmode=require";
        String user = "neondb_owner";
        String pass = "npg_BLlnutq2yzo0";

        try (Connection conn = DriverManager.getConnection(dbUrl, user, pass);
             Statement stmt = conn.createStatement()) {

            System.out.println("=== NEON DB: LISTINGS & MEDIA ===");
            stmt.executeUpdate(
                "UPDATE listings SET seller_id = (SELECT id FROM users WHERE name ILIKE '%Dhaya%' LIMIT 1) " +
                "WHERE title = 'rfgg' AND seller_id IS NOT NULL");
            System.out.println("Updated rfgg seller to Dhaya successfully!");
        }
    }
}
