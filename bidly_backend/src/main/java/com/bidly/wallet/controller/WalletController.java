package com.bidly.wallet.controller;

import com.bidly.common.dto.ApiResponse;
import com.bidly.common.exception.BidlyException;
import com.bidly.wallet.dto.WalletDto;
import com.bidly.wallet.service.RazorpayService;
import com.bidly.wallet.service.WalletService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/wallet")
public class WalletController {

    private static final Logger log = LoggerFactory.getLogger(WalletController.class);

    private final WalletService walletService;
    private final RazorpayService razorpayService;
    private final UserRepository userRepository;

    public WalletController(WalletService walletService, RazorpayService razorpayService, UserRepository userRepository) {
        this.walletService = walletService;
        this.razorpayService = razorpayService;
        this.userRepository = userRepository;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<WalletDto>> getWallet(@AuthenticationPrincipal UUID currentUserId) {
        WalletDto dto = walletService.getWallet(currentUserId);
        return ResponseEntity.ok(ApiResponse.success(dto));
    }

    /**
     * Top-up endpoint with rich transaction details for Add Money flow
     */
    @PostMapping("/top-up")
    public ResponseEntity<ApiResponse<Map<String, Object>>> topUp(
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody Map<String, Object> body) {
        BigDecimal amount = new BigDecimal(body.getOrDefault("amount", "500").toString());
        String paymentMethod = (String) body.getOrDefault("paymentMethod", "UPI");
        String desc = (String) body.getOrDefault("description", "Wallet Top-up via " + paymentMethod);
        WalletDto dto = walletService.topUpFunds(currentUserId, amount, desc);

        String txnId = "BDW" + String.format("%08d", new java.util.Random().nextInt(90000000) + 10000000);
        Map<String, Object> result = new HashMap<>();
        result.put("wallet", dto);
        result.put("amountAdded", amount);
        result.put("transactionId", txnId);
        result.put("updatedBalance", dto.getBalance());
        result.put("status", "SUCCESS");
        result.put("paymentMethod", paymentMethod);
        result.put("timestamp", java.time.Instant.now().toString());

        return ResponseEntity.ok(ApiResponse.success("Funds added successfully", result));
    }

    /**
     * Get Razorpay configuration (Public Key ID) for mobile client
     */
    @GetMapping("/razorpay/config")
    public ResponseEntity<ApiResponse<Map<String, String>>> getRazorpayConfig() {
        Map<String, String> config = new HashMap<>();
        config.put("keyId", razorpayService.getKeyId());
        config.put("currency", "INR");
        return ResponseEntity.ok(ApiResponse.success(config));
    }

    /**
     * Initiates a Razorpay Order for in-app wallet top-up
     */
    @PostMapping("/razorpay/create-order")
    public ResponseEntity<ApiResponse<Map<String, Object>>> createRazorpayOrder(
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody Map<String, Object> body) {
        BigDecimal amount = new BigDecimal(body.getOrDefault("amount", "500").toString());
        Map<String, Object> order = razorpayService.createOrder(currentUserId, amount, "wallet_");
        return ResponseEntity.ok(ApiResponse.success("Razorpay order created", order));
    }

    /**
     * Verifies the cryptographic payment signature and credits the user's wallet
     */
    @PostMapping("/razorpay/verify-payment")
    public ResponseEntity<ApiResponse<Map<String, Object>>> verifyRazorpayPayment(
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody Map<String, Object> body) {
        String razorpayOrderId = (String) body.get("razorpayOrderId");
        String razorpayPaymentId = (String) body.get("razorpayPaymentId");
        String razorpaySignature = (String) body.get("razorpaySignature");

        boolean valid = razorpayService.verifyPaymentSignature(razorpayOrderId, razorpayPaymentId, razorpaySignature);
        if (!valid) {
            throw BidlyException.badRequest("Invalid payment signature. Verification failed.");
        }

        // Verify authoritative payment status & amount from Razorpay API
        Map<String, Object> paymentInfo = razorpayService.fetchPayment(razorpayPaymentId);
        String paymentStatus = (String) paymentInfo.get("status");
        if (!"captured".equalsIgnoreCase(paymentStatus) && !"authorized".equalsIgnoreCase(paymentStatus)) {
            throw BidlyException.badRequest("Payment status is not captured: " + paymentStatus);
        }

        BigDecimal verifiedAmount = (BigDecimal) paymentInfo.get("amount");
        if (verifiedAmount == null || verifiedAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw BidlyException.badRequest("Invalid authorized amount on gateway");
        }

        // Credit with idempotency protection
        WalletDto dto = walletService.creditFromRazorpay(currentUserId, verifiedAmount, razorpayOrderId, razorpayPaymentId);

        Map<String, Object> result = new HashMap<>();
        result.put("wallet", dto);
        result.put("amountAdded", verifiedAmount);
        result.put("transactionId", razorpayPaymentId);
        result.put("orderId", razorpayOrderId);
        result.put("updatedBalance", dto.getBalance());
        result.put("status", "SUCCESS");
        result.put("paymentMethod", "RAZORPAY");
        result.put("timestamp", java.time.Instant.now().toString());

        return ResponseEntity.ok(ApiResponse.success("Payment verified and wallet credited", result));
    }

    /**
     * Generates a hosted Razorpay payment link for external browser or UPI app launch
     */
    @PostMapping("/razorpay/create-payment-link")
    public ResponseEntity<ApiResponse<Map<String, Object>>> createRazorpayPaymentLink(
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody Map<String, Object> body) {
        BigDecimal amount = new BigDecimal(body.getOrDefault("amount", "500").toString());
        String name = (String) body.get("name");
        String phone = (String) body.get("phone");
        String description = (String) body.getOrDefault("description", "Bidly Wallet Top-up");

        User user = userRepository.findById(currentUserId).orElse(null);
        if (user != null) {
            if (name == null || name.isBlank()) name = user.getName();
            if (phone == null || phone.isBlank()) phone = user.getPhone();
        }

        Map<String, Object> link = razorpayService.createPaymentLink(currentUserId, amount, name, phone, description);
        return ResponseEntity.ok(ApiResponse.success("Payment link generated", link));
    }

    /**
     * Checks status of a Razorpay Payment Link and credits wallet if status is "paid"
     */
    @PostMapping("/razorpay/check-payment-link")
    public ResponseEntity<ApiResponse<Map<String, Object>>> checkPaymentLink(
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody Map<String, Object> body) {
        String paymentLinkId = (String) body.get("paymentLinkId");
        if (paymentLinkId == null || paymentLinkId.isBlank()) {
            throw BidlyException.badRequest("paymentLinkId is required");
        }

        Map<String, Object> plink = razorpayService.getPaymentLink(paymentLinkId);
        String status = (String) plink.get("status");

        if ("paid".equalsIgnoreCase(status)) {
            BigDecimal amount = (BigDecimal) plink.get("amountPaid");
            String paymentId = (String) plink.get("paymentId");

            WalletDto dto = walletService.creditFromRazorpay(currentUserId, amount, paymentLinkId, paymentId);

            Map<String, Object> result = new HashMap<>();
            result.put("wallet", dto);
            result.put("amountAdded", amount);
            result.put("transactionId", paymentId);
            result.put("paymentLinkId", paymentLinkId);
            result.put("updatedBalance", dto.getBalance());
            result.put("status", "SUCCESS");
            result.put("paymentMethod", "RAZORPAY");
            result.put("timestamp", java.time.Instant.now().toString());

            return ResponseEntity.ok(ApiResponse.success("Payment verified and wallet credited", result));
        }

        Map<String, Object> pendingResult = new HashMap<>();
        pendingResult.put("status", status != null ? status.toUpperCase() : "PENDING");
        pendingResult.put("paymentLinkId", paymentLinkId);
        return ResponseEntity.ok(ApiResponse.success("Payment status: " + status, pendingResult));
    }

    /**
     * Razorpay Server-to-Server Webhook receiver for real-time payment events
     */
    @PostMapping("/razorpay/webhook")
    public ResponseEntity<String> handleRazorpayWebhook(
            @RequestHeader(value = "X-Razorpay-Signature", required = false) String signature,
            @RequestBody String payload) {
        log.info("[RAZORPAY_WEBHOOK] Incoming webhook event received");

        if (signature != null && !signature.isBlank()) {
            boolean isValid = razorpayService.validateWebhook(payload, signature);
            if (!isValid) {
                log.warn("[RAZORPAY_WEBHOOK] Invalid HMAC signature, rejecting webhook");
                return ResponseEntity.status(org.springframework.http.HttpStatus.BAD_REQUEST).body("Invalid signature");
            }
        } else {
            log.warn("[RAZORPAY_WEBHOOK] No signature header provided on webhook request");
        }

        try {
            com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
            com.fasterxml.jackson.databind.JsonNode root = mapper.readTree(payload);
            String event = root.path("event").asText("");
            log.info("[RAZORPAY_WEBHOOK] Handling event: {}", event);

            if ("payment_link.paid".equalsIgnoreCase(event)) {
                com.fasterxml.jackson.databind.JsonNode plinkNode = root.path("payload").path("payment_link").path("entity");
                String paymentLinkId = plinkNode.path("id").asText();
                long amountPaise = plinkNode.path("amount_paid").asLong(0);
                if (amountPaise == 0) amountPaise = plinkNode.path("amount").asLong(0);
                BigDecimal amount = BigDecimal.valueOf(amountPaise).divide(BigDecimal.valueOf(100));

                String userIdStr = plinkNode.path("notes").path("userId").asText(null);
                String paymentId = plinkNode.path("payments").isArray() && !plinkNode.path("payments").isEmpty()
                        ? plinkNode.path("payments").get(0).path("payment_id").asText(paymentLinkId)
                        : paymentLinkId;

                if (userIdStr != null && !userIdStr.isBlank() && !"anonymous".equalsIgnoreCase(userIdStr)) {
                    UUID userId = UUID.fromString(userIdStr);
                    walletService.creditFromRazorpay(userId, amount, paymentLinkId, paymentId);
                    log.info("[RAZORPAY_WEBHOOK] Auto-credited {} to user {} for payment link {}", amount, userId, paymentLinkId);
                }
            } else if ("payment.captured".equalsIgnoreCase(event)) {
                com.fasterxml.jackson.databind.JsonNode paymentNode = root.path("payload").path("payment").path("entity");
                String paymentId = paymentNode.path("id").asText();
                String orderId = paymentNode.path("order_id").asText(paymentId);
                long amountPaise = paymentNode.path("amount").asLong(0);
                BigDecimal amount = BigDecimal.valueOf(amountPaise).divide(BigDecimal.valueOf(100));
                String userIdStr = paymentNode.path("notes").path("userId").asText(null);

                if (userIdStr != null && !userIdStr.isBlank() && !"anonymous".equalsIgnoreCase(userIdStr)) {
                    UUID userId = UUID.fromString(userIdStr);
                    walletService.creditFromRazorpay(userId, amount, orderId, paymentId);
                    log.info("[RAZORPAY_WEBHOOK] Auto-credited {} to user {} for payment {}", amount, userId, paymentId);
                }
            }

            return ResponseEntity.ok("OK");
        } catch (Exception e) {
            log.error("[RAZORPAY_WEBHOOK] Exception processing webhook payload", e);
            return ResponseEntity.ok("Handled with error");
        }
    }
}
