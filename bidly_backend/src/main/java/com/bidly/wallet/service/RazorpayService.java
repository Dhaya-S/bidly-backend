package com.bidly.wallet.service;

import com.bidly.common.exception.BidlyException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Service
public class RazorpayService {

    private static final Logger log = LoggerFactory.getLogger(RazorpayService.class);
    private static final String RAZORPAY_API_BASE = "https://api.razorpay.com/v1";

    @Value("${razorpay.key-id}")
    private String keyId;

    @Value("${razorpay.key-secret}")
    private String keySecret;

    @Value("${razorpay.webhook-secret:}")
    private String webhookSecret;

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    public RazorpayService(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    public String getKeyId() {
        return keyId;
    }

    /**
     * Creates a real Razorpay Order for in-app or checkout payment
     */
    public Map<String, Object> createOrder(UUID userId, BigDecimal amount, String receiptPrefix) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw BidlyException.badRequest("Amount must be greater than zero");
        }

        // Razorpay amounts are strictly in paise (1 INR = 100 paise)
        long amountInPaise = amount.multiply(BigDecimal.valueOf(100)).longValue();
        String receipt = (receiptPrefix != null ? receiptPrefix : "rcpt_") + System.currentTimeMillis();

        try {
            Map<String, Object> payload = new HashMap<>();
            payload.put("amount", amountInPaise);
            payload.put("currency", "INR");
            payload.put("receipt", receipt);

            Map<String, String> notes = new HashMap<>();
            notes.put("userId", userId != null ? userId.toString() : "anonymous");
            notes.put("type", "WALLET_TOPUP");
            payload.put("notes", notes);

            String requestBody = objectMapper.writeValueAsString(payload);
            String basicAuth = Base64.getEncoder().encodeToString((keyId + ":" + keySecret).getBytes(StandardCharsets.UTF_8));

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(RAZORPAY_API_BASE + "/orders"))
                    .header("Authorization", "Basic " + basicAuth)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .timeout(Duration.ofSeconds(15))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                JsonNode root = objectMapper.readTree(response.body());
                Map<String, Object> result = new HashMap<>();
                result.put("orderId", root.path("id").asText());
                result.put("amount", amount);
                result.put("amountInPaise", amountInPaise);
                result.put("currency", root.path("currency").asText("INR"));
                result.put("receipt", root.path("receipt").asText(receipt));
                result.put("keyId", keyId);
                result.put("status", root.path("status").asText());
                return result;
            } else {
                log.error("Failed to create Razorpay order: Status={}, Body={}", response.statusCode(), response.body());
                throw BidlyException.badRequest("Razorpay order creation failed: " + response.body());
            }
        } catch (BidlyException be) {
            throw be;
        } catch (Exception e) {
            log.error("Exception creating Razorpay order", e);
            throw BidlyException.internal("Error initiating Razorpay payment: " + e.getMessage());
        }
    }

    /**
     * Verifies the Razorpay payment signature cryptographically using HMAC SHA-256
     */
    public boolean verifyPaymentSignature(String razorpayOrderId, String razorpayPaymentId, String razorpaySignature) {
        if (razorpayOrderId == null || razorpayPaymentId == null || razorpaySignature == null) {
            return false;
        }

        try {
            String data = razorpayOrderId + "|" + razorpayPaymentId;
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKeySpec = new SecretKeySpec(keySecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(secretKeySpec);
            byte[] hash = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));

            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }

            return hexString.toString().equalsIgnoreCase(razorpaySignature.trim());
        } catch (Exception e) {
            log.error("Error verifying Razorpay signature", e);
            return false;
        }
    }

    /**
     * Creates a hosted Razorpay payment link (UPI apps, cards, net banking)
     */
    public Map<String, Object> createPaymentLink(UUID userId, BigDecimal amount, String customerName, String customerPhone, String description) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw BidlyException.badRequest("Amount must be greater than zero");
        }

        long amountInPaise = amount.multiply(BigDecimal.valueOf(100)).longValue();

        try {
            Map<String, Object> payload = new HashMap<>();
            payload.put("amount", amountInPaise);
            payload.put("currency", "INR");
            payload.put("accept_partial", false);
            payload.put("description", description != null ? description : "Bidly Wallet Top-up");

            Map<String, Object> customer = new HashMap<>();
            if (customerName != null && !customerName.isBlank()) customer.put("name", customerName);
            if (customerPhone != null && !customerPhone.isBlank()) customer.put("contact", customerPhone);
            if (!customer.isEmpty()) {
                payload.put("customer", customer);
            }

            Map<String, Object> notify = new HashMap<>();
            notify.put("sms", false);
            notify.put("email", false);
            payload.put("notify", notify);

            Map<String, String> notes = new HashMap<>();
            notes.put("userId", userId != null ? userId.toString() : "anonymous");
            notes.put("type", "WALLET_TOPUP");
            payload.put("notes", notes);

            String requestBody = objectMapper.writeValueAsString(payload);
            String basicAuth = Base64.getEncoder().encodeToString((keyId + ":" + keySecret).getBytes(StandardCharsets.UTF_8));

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(RAZORPAY_API_BASE + "/payment_links"))
                    .header("Authorization", "Basic " + basicAuth)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .timeout(Duration.ofSeconds(15))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                JsonNode root = objectMapper.readTree(response.body());
                Map<String, Object> result = new HashMap<>();
                result.put("paymentLinkId", root.path("id").asText());
                result.put("shortUrl", root.path("short_url").asText());
                result.put("amount", amount);
                result.put("status", root.path("status").asText());
                return result;
            } else {
                log.error("Failed to create Razorpay payment link: Status={}, Body={}", response.statusCode(), response.body());
                throw BidlyException.badRequest("Razorpay payment link failed: " + response.body());
            }
        } catch (BidlyException be) {
            throw be;
        } catch (Exception e) {
            log.error("Exception creating Razorpay payment link", e);
            throw BidlyException.internal("Error initiating Razorpay payment link: " + e.getMessage());
        }
    }

    /**
     * Retrieves current details and live payment status of a Razorpay Payment Link
     */
    public Map<String, Object> getPaymentLink(String paymentLinkId) {
        if (paymentLinkId == null || paymentLinkId.isBlank()) {
            throw BidlyException.badRequest("paymentLinkId is required");
        }

        try {
            String basicAuth = Base64.getEncoder().encodeToString((keyId + ":" + keySecret).getBytes(StandardCharsets.UTF_8));

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(RAZORPAY_API_BASE + "/payment_links/" + paymentLinkId.trim()))
                    .header("Authorization", "Basic " + basicAuth)
                    .header("Content-Type", "application/json")
                    .GET()
                    .timeout(Duration.ofSeconds(15))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                JsonNode root = objectMapper.readTree(response.body());
                Map<String, Object> result = new HashMap<>();
                result.put("paymentLinkId", root.path("id").asText());
                result.put("status", root.path("status").asText());

                long amountPaidPaise = root.path("amount_paid").asLong(0);
                if (amountPaidPaise == 0) {
                    amountPaidPaise = root.path("amount").asLong(0);
                }
                BigDecimal amountPaid = BigDecimal.valueOf(amountPaidPaise).divide(BigDecimal.valueOf(100));
                result.put("amountPaid", amountPaid);

                String paymentId = null;
                JsonNode payments = root.path("payments");
                if (payments.isArray() && !payments.isEmpty()) {
                    paymentId = payments.get(0).path("payment_id").asText(null);
                }
                if (paymentId == null || paymentId.isBlank()) {
                    paymentId = paymentLinkId;
                }
                result.put("paymentId", paymentId);
                return result;
            } else {
                log.error("Failed to query Razorpay payment link {}: Status={}, Body={}", paymentLinkId, response.statusCode(), response.body());
                throw BidlyException.badRequest("Razorpay payment link check failed: " + response.body());
            }
        } catch (BidlyException be) {
            throw be;
        } catch (Exception e) {
            log.error("Exception querying Razorpay payment link {}", paymentLinkId, e);
            throw BidlyException.internal("Error querying Razorpay payment link: " + e.getMessage());
        }
    }

    /**
     * Fetches authoritative payment details directly from Razorpay
     */
    public Map<String, Object> fetchPayment(String paymentId) {
        if (paymentId == null || paymentId.isBlank()) {
            throw BidlyException.badRequest("paymentId is required");
        }

        try {
            String basicAuth = Base64.getEncoder().encodeToString((keyId + ":" + keySecret).getBytes(StandardCharsets.UTF_8));

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(RAZORPAY_API_BASE + "/payments/" + paymentId.trim()))
                    .header("Authorization", "Basic " + basicAuth)
                    .header("Content-Type", "application/json")
                    .GET()
                    .timeout(Duration.ofSeconds(15))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                JsonNode root = objectMapper.readTree(response.body());
                Map<String, Object> result = new HashMap<>();
                result.put("paymentId", root.path("id").asText());
                result.put("orderId", root.path("order_id").asText());
                result.put("status", root.path("status").asText());

                long amountPaise = root.path("amount").asLong(0);
                BigDecimal amount = BigDecimal.valueOf(amountPaise).divide(BigDecimal.valueOf(100));
                result.put("amount", amount);

                String userId = root.path("notes").path("userId").asText(null);
                if (userId != null && !userId.isBlank() && !"anonymous".equalsIgnoreCase(userId)) {
                    result.put("userId", userId);
                }

                return result;
            } else {
                log.error("Failed to fetch Razorpay payment {}: Status={}, Body={}", paymentId, response.statusCode(), response.body());
                throw BidlyException.badRequest("Failed to verify payment with Razorpay: " + response.body());
            }
        } catch (BidlyException be) {
            throw be;
        } catch (Exception e) {
            log.error("Exception fetching Razorpay payment {}", paymentId, e);
            throw BidlyException.internal("Error communicating with Razorpay: " + e.getMessage());
        }
    }

    /**
     * Validates incoming Razorpay Webhook signature using configured webhook secret (or keySecret fallback)
     */
    public boolean validateWebhook(String payload, String signature) {
        if (signature == null || signature.isBlank()) {
            return false;
        }
        String secret = (webhookSecret != null && !webhookSecret.isBlank()) ? webhookSecret : keySecret;
        return verifyWebhookSignature(payload, signature, secret);
    }

    /**
     * Verifies the authenticity of Razorpay Webhook signatures using HMAC SHA-256
     */
    public boolean verifyWebhookSignature(String payload, String signature, String secret) {
        if (payload == null || signature == null || secret == null || secret.isBlank()) {
            return false;
        }

        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKeySpec = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(secretKeySpec);
            byte[] hash = mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));

            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }

            return hexString.toString().equalsIgnoreCase(signature.trim());
        } catch (Exception e) {
            log.error("Error verifying Razorpay webhook signature", e);
            return false;
        }
    }
}

