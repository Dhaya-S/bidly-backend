package com.bidly.auth.service;

import com.bidly.common.exception.BidlyException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

/**
 * Service for communicating with Fast2SMS Quick OTP API.
 */
@Service
public class Fast2SmsService {

    private static final Logger log = LoggerFactory.getLogger(Fast2SmsService.class);

    @Value("${fast2sms.api-key}")
    private String apiKey;

    @Value("${fast2sms.otp-id}")
    private String otpId;

    @Value("${fast2sms.send-url:https://www.fast2sms.com/dev/otp/send}")
    private String sendUrl;

    @Value("${fast2sms.verify-url:https://www.fast2sms.com/dev/otp/verify}")
    private String verifyUrl;

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * Sends OTP to a 10-digit mobile number via Fast2SMS.
     */
    public String sendOtp(String mobile) {
        String cleanMobile = cleanPhone(mobile);
        try {
            HttpHeaders headers = createHeaders();

            Map<String, String> body = new HashMap<>();
            body.put("mobile", cleanMobile);
            body.put("otp_id", otpId);

            HttpEntity<Map<String, String>> requestEntity = new HttpEntity<>(body, headers);

            log.info("Sending OTP via Fast2SMS to mobile: {}", cleanMobile);
            ResponseEntity<String> response = restTemplate.postForEntity(sendUrl, requestEntity, String.class);

            log.info("Fast2SMS send response status: {}, body: {}", response.getStatusCode(), response.getBody());

            JsonNode root = objectMapper.readTree(response.getBody());
            if (root.has("return") && root.get("return").asBoolean()) {
                if (root.has("request_id") && !root.get("request_id").isNull()) {
                    return root.get("request_id").asText();
                }
                return java.util.UUID.randomUUID().toString();
            }

            String message = "Fast2SMS service rejected OTP dispatch";
            if (root.has("message")) {
                JsonNode msgNode = root.get("message");
                message = msgNode.isArray() && msgNode.size() > 0 ? msgNode.get(0).asText() : msgNode.asText();
            }

            log.warn("Fast2SMS returned failure for {}: {}", cleanMobile, message);
            throw BidlyException.badRequest("Failed to deliver OTP SMS: " + message);
        } catch (BidlyException ex) {
            throw ex;
        } catch (Exception ex) {
            log.error("Fast2SMS send error for {}: {}", cleanMobile, ex.getMessage(), ex);
            throw BidlyException.badRequest("Unable to send OTP: " + ex.getMessage());
        }
    }

    /**
     * Verifies OTP for a 10-digit mobile number via Fast2SMS.
     */
    public boolean verifyOtp(String mobile, String otp) {
        String cleanMobile = cleanPhone(mobile);
        try {
            HttpHeaders headers = createHeaders();

            Map<String, String> body = new HashMap<>();
            body.put("mobile", cleanMobile);
            body.put("otp", otp != null ? otp.trim() : "");

            HttpEntity<Map<String, String>> requestEntity = new HttpEntity<>(body, headers);

            log.info("Verifying OTP via Fast2SMS for mobile: {}", cleanMobile);
            ResponseEntity<String> response = restTemplate.postForEntity(verifyUrl, requestEntity, String.class);

            log.info("Fast2SMS verify response status: {}, body: {}", response.getStatusCode(), response.getBody());

            JsonNode root = objectMapper.readTree(response.getBody());
            if (root.has("return") && root.get("return").asBoolean()) {
                return true;
            }

            String message = "Invalid or expired OTP";
            if (root.has("message")) {
                JsonNode msgNode = root.get("message");
                message = msgNode.isArray() && msgNode.size() > 0 ? msgNode.get(0).asText() : msgNode.asText();
            }
            throw BidlyException.badRequest(message);
        } catch (BidlyException ex) {
            throw ex;
        } catch (Exception ex) {
            log.error("Fast2SMS verify error for {}: {}", cleanMobile, ex.getMessage(), ex);
            throw BidlyException.badRequest("OTP verification failed: " + ex.getMessage());
        }
    }

    private String cleanPhone(String phone) {
        if (phone == null) return "";
        String digits = phone.replaceAll("\\D", "");
        return digits.length() > 10 ? digits.substring(digits.length() - 10) : digits;
    }

    private HttpHeaders createHeaders() {
        HttpHeaders headers = new HttpHeaders();
        headers.set("authorization", apiKey);
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("accept", "application/json");
        return headers;
    }
}
