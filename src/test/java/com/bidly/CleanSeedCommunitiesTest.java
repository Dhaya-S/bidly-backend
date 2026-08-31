package com.bidly;

import org.junit.jupiter.api.Test;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

public class CleanSeedCommunitiesTest {

    @Test
    void cleanSeeds() throws Exception {
        String dbUrl = "jdbc:postgresql://ep-fragrant-union-ayftexwy-pooler.c-5.us-east-2.aws.neon.tech/neondb?sslmode=require";
        String user = "neondb_owner";
        String pass = "npg_BLlnutq2yzo0";

        try (Connection conn = DriverManager.getConnection(dbUrl, user, pass);
             Statement stmt = conn.createStatement()) {

            // Keep communities that have created_by set (real user created)
            int deleted = stmt.executeUpdate(
                    "DELETE FROM communities WHERE created_by IS NULL " +
                    "AND name IN (" +
                    "'Anna Nagar Neighbourhood', 'Coimbatore Tech Hub', 'SRM College Campus', " +
                    "'Adyar Books & Study', 'T. Nagar Fashion Deals', 'Tambaram Swap Circle', " +
                    "'OMR Tech Community', 'Electronics Resellers TN', 'Vintage & Antiques Club')"
            );
            System.out.println("Deleted " + deleted + " dummy seed communities from Neon DB.");

            try (ResultSet rs = stmt.executeQuery("SELECT id, name, created_by, members_count FROM communities")) {
                while (rs.next()) {
                    System.out.println("Remaining Community: " + rs.getString("id") + " | " + rs.getString("name") + " | created_by: " + rs.getString("created_by"));
                }
            }
        }
    }
}
