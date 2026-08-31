package com.bidly.wallet.controller;

import com.bidly.common.dto.ApiResponse;
import com.bidly.wallet.dto.WalletDto;
import com.bidly.wallet.service.WalletService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/wallet")
public class WalletController {

    private final WalletService walletService;

    public WalletController(WalletService walletService) {
        this.walletService = walletService;
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
        Map<String, Object> result = new java.util.HashMap<>();
        result.put("wallet", dto);
        result.put("amountAdded", amount);
        result.put("transactionId", txnId);
        result.put("updatedBalance", dto.getBalance());
        result.put("status", "SUCCESS");
        result.put("timestamp", java.time.Instant.now().toString());

        return ResponseEntity.ok(ApiResponse.success("Funds added successfully", result));
    }
}
