package com.studysync;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.Statement;

public class DatabaseInspector {
    public static void main(String[] args) {
        String url = "jdbc:postgresql://ep-noisy-sky-aly613sz-pooler.c-3.eu-central-1.aws.neon.tech/neondb?sslmode=require";
        String user = "neondb_owner";
        String password = "npg_9NPEMQK7zjZm";

        try (Connection conn = DriverManager.getConnection(url, user, password);
             Statement stmt = conn.createStatement()) {
            
            System.out.println("Connected to database successfully!");

            // 1. Inspect table columns for lost_items
            System.out.println("\n--- Table Schema for lost_items ---");
            try (ResultSet rs = stmt.executeQuery("SELECT * FROM lost_items LIMIT 1")) {
                ResultSetMetaData metaData = rs.getMetaData();
                int columnCount = metaData.getColumnCount();
                for (int i = 1; i <= columnCount; i++) {
                    System.out.printf("Column %d: %s (%s)%n", i, metaData.getColumnName(i), metaData.getColumnTypeName(i));
                }
            } catch (Exception e) {
                System.err.println("Error inspecting lost_items schema: " + e.getMessage());
            }

            // 2. Query last 5 reports
            System.out.println("\n--- Last 5 Reports in lost_items ---");
            try (ResultSet rs = stmt.executeQuery("SELECT * FROM lost_items ORDER BY id DESC LIMIT 5")) {
                ResultSetMetaData metaData = rs.getMetaData();
                int columnCount = metaData.getColumnCount();
                while (rs.next()) {
                    for (int i = 1; i <= columnCount; i++) {
                        System.out.print(metaData.getColumnName(i) + "=" + rs.getObject(i) + "  ");
                    }
                    System.out.println();
                }
            } catch (Exception e) {
                System.err.println("Error querying rows: " + e.getMessage());
            }

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
