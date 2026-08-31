package com.bidly.wallet.controller;

import com.bidly.common.dto.ApiResponse;
import com.bidly.wallet.dto.WalletDto;
import com.bidly.wallet.service.WalletService;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

/**
 * DEVELOPMENT-ONLY Wallet Controller for testing dummy funds, reservations, outbidding, and escrow.
 * Automatically disabled when bidly.dev-wallet.enabled is false (e.g. in production).
 */
@RestController
@RequestMapping("/dev/wallet")
@ConditionalOnProperty(prefix = "bidly.dev-wallet", name = "enabled", havingValue = "true", matchIfMissing = true)
public class DevWalletController {

    private final WalletService walletService;

    public DevWalletController(WalletService walletService) {
        this.walletService = walletService;
    }

    /**
     * POST /api/dev/wallet/top-up
     * Request: { "amount": 50000 }
     */
    @PostMapping("/top-up")
    public ResponseEntity<ApiResponse<WalletDto>> devTopUp(
            @AuthenticationPrincipal UUID currentUserId,
            @RequestBody(required = false) Map<String, Object> body) {
        BigDecimal amount = BigDecimal.valueOf(50000.00);
        if (body != null && body.containsKey("amount") && body.get("amount") != null) {
            amount = new BigDecimal(body.get("amount").toString());
        }
        String desc = (body != null && body.containsKey("description") && body.get("description") != null)
                ? body.get("description").toString()
                : "[DEV] Manual dummy wallet top-up";

        WalletDto updated = walletService.topUpFunds(currentUserId, amount, desc);
        return ResponseEntity.ok(ApiResponse.success("Development dummy funds added successfully", updated));
    }

    /**
     * POST /api/dev/wallet/reset
     * Resets test user's wallet to standard testing baseline (₹50,000 balance, ₹0 reserved).
     */
    @PostMapping("/reset")
    public ResponseEntity<ApiResponse<WalletDto>> devReset(
            @AuthenticationPrincipal UUID currentUserId) {
        WalletDto reset = walletService.devResetWallet(currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Development wallet reset successfully", reset));
    }
}
