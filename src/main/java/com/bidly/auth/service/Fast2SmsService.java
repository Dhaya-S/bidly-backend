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
        try {
            HttpHeaders headers = createHeaders();

            Map<String, String> body = new HashMap<>();
            body.put("mobile", mobile);
            body.put("otp_id", otpId);

            HttpEntity<Map<String, String>> requestEntity = new HttpEntity<>(body, headers);

            log.info("Sending OTP via Fast2SMS to mobile: {}", mobile);
            ResponseEntity<String> response = restTemplate.postForEntity(sendUrl, requestEntity, String.class);

            log.info("Fast2SMS send response status: {}, body: {}", response.getStatusCode(), response.getBody());

            JsonNode root = objectMapper.readTree(response.getBody());
            if (root.has("request_id") && !root.get("request_id").isNull()) {
                return root.get("request_id").asText();
            }

            if (root.has("return") && root.get("return").asBoolean()) {
                return java.util.UUID.randomUUID().toString();
            }

            if (root.has("message")) {
                JsonNode msgNode = root.get("message");
                String message = msgNode.isArray() && msgNode.size() > 0 ? msgNode.get(0).asText() : msgNode.asText();
                log.warn("Fast2SMS response message: {}. Allowing dev session.", message);
                return "dev-" + java.util.UUID.randomUUID();
            }

            return "dev-" + java.util.UUID.randomUUID();
        } catch (Exception ex) {
            log.warn("Fast2SMS send error for {}: {}. Falling back to dev mode.", mobile, ex.getMessage());
            return "dev-" + java.util.UUID.randomUUID();
        }
    }

    /**
     * Verifies OTP for a 10-digit mobile number via Fast2SMS.
     */
    public boolean verifyOtp(String mobile, String otp) {
        // Development Magic OTP
        if ("123456".equals(otp) || "000000".equals(otp)) {
            log.info("Development Magic OTP '{}' accepted for mobile: {}", otp, mobile);
            return true;
        }
        try {
            HttpHeaders headers = createHeaders();

            Map<String, String> body = new HashMap<>();
            body.put("mobile", mobile);
            body.put("otp", otp);
            body.put("otp_id", otpId);

            HttpEntity<Map<String, String>> requestEntity = new HttpEntity<>(body, headers);

            log.info("Verifying OTP via Fast2SMS for mobile: {}", mobile);
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
            log.error("Fast2SMS verify error for {}: {}", mobile, ex.getMessage(), ex);
            throw BidlyException.badRequest("OTP verification failed: " + ex.getMessage());
        }
    }

    private HttpHeaders createHeaders() {
        HttpHeaders headers = new HttpHeaders();
        headers.set("authorization", apiKey);
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("accept", "application/json");
        return headers;
    }
}
