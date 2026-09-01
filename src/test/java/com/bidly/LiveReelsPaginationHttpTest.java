package com.bidly;

import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.*;

public class LiveReelsPaginationHttpTest {

    @Test
    void testLiveReelsPaginationAcrossPages() throws Exception {
        boolean serverRunning = false;
        try (Socket socket = new Socket()) {
            socket.connect(new InetSocketAddress("localhost", 8081), 1000);
            serverRunning = true;
        } catch (Exception ignored) {}

        Assumptions.assumeTrue(serverRunning, "Standalone backend server on port 8081 is not running; skipping live HTTP test");

        HttpClient client = HttpClient.newHttpClient();
        String baseUrl = "http://localhost:8081/api/listings/reels";

        Set<String> allLoadedIds = new HashSet<>();

        // Test Page 0
        HttpRequest req0 = HttpRequest.newBuilder().uri(URI.create(baseUrl + "?page=0&size=10")).GET().build();
        HttpResponse<String> res0 = client.send(req0, HttpResponse.BodyHandlers.ofString());
        assertEquals(200, res0.statusCode());
        Set<String> page0Ids = extractIds(res0.body());
        assertEquals(10, page0Ids.size(), "Page 0 must return exactly 10 reels");
        allLoadedIds.addAll(page0Ids);

        // Test Page 1
        HttpRequest req1 = HttpRequest.newBuilder().uri(URI.create(baseUrl + "?page=1&size=10")).GET().build();
        HttpResponse<String> res1 = client.send(req1, HttpResponse.BodyHandlers.ofString());
        assertEquals(200, res1.statusCode());
        Set<String> page1Ids = extractIds(res1.body());
        assertEquals(10, page1Ids.size(), "Page 1 must return exactly 10 reels");
        for (String id : page1Ids) {
            assertFalse(allLoadedIds.contains(id), "Page 1 ID " + id + " must not duplicate Page 0");
        }
        allLoadedIds.addAll(page1Ids);

        // Test Page 2
        HttpRequest req2 = HttpRequest.newBuilder().uri(URI.create(baseUrl + "?page=2&size=10")).GET().build();
        HttpResponse<String> res2 = client.send(req2, HttpResponse.BodyHandlers.ofString());
        assertEquals(200, res2.statusCode());
        Set<String> page2Ids = extractIds(res2.body());
        assertEquals(10, page2Ids.size(), "Page 2 must return exactly 10 reels");
        for (String id : page2Ids) {
            assertFalse(allLoadedIds.contains(id), "Page 2 ID " + id + " must not duplicate Page 0/1");
        }
        allLoadedIds.addAll(page2Ids);

        // Test Page 3 (End of Feed / Beyond Max)
        HttpRequest req3 = HttpRequest.newBuilder().uri(URI.create(baseUrl + "?page=3&size=10")).GET().build();
        HttpResponse<String> res3 = client.send(req3, HttpResponse.BodyHandlers.ofString());
        assertEquals(200, res3.statusCode());
        Set<String> page3Ids = extractIds(res3.body());
        for (String id : page3Ids) {
            assertFalse(allLoadedIds.contains(id), "Page 3 ID " + id + " must not duplicate earlier pages");
        }
        allLoadedIds.addAll(page3Ids);

        assertTrue(allLoadedIds.size() >= 30, "Total accumulated distinct reels across pages must be at least 30");
        System.out.println("=== LIVE PAGINATION TEST PASSED: " + allLoadedIds.size() + " distinct reels across pages ===");
    }

    private Set<String> extractIds(String json) {
        Set<String> ids = new HashSet<>();
        Pattern pattern = Pattern.compile("\"id\"\\s*:\\s*\"([^\"]+)\"");
        Matcher matcher = pattern.matcher(json);
        while (matcher.find()) {
            ids.add(matcher.group(1));
        }
        return ids;
    }
}
