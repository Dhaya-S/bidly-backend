package com.bidly.wallet.service;

import com.bidly.common.exception.BidlyException;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import com.bidly.wallet.dto.WalletDto;
import com.bidly.wallet.entity.Wallet;
import com.bidly.wallet.entity.WalletTransaction;
import com.bidly.wallet.repository.WalletRepository;
import com.bidly.wallet.repository.WalletTransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.UUID;

@Service
public class WalletService {

    private final WalletRepository walletRepository;
    private final WalletTransactionRepository transactionRepository;
    private final UserRepository userRepository;

    public WalletService(WalletRepository walletRepository,
                         WalletTransactionRepository transactionRepository,
                         UserRepository userRepository) {
        this.walletRepository = walletRepository;
        this.transactionRepository = transactionRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public Wallet getOrCreateWalletEntity(UUID userId) {
        return walletRepository.findByUserId(userId).orElseGet(() -> {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> BidlyException.notFound("User not found: " + userId));
            Wallet newWallet = new Wallet(user);
            newWallet.setBalance(BigDecimal.ZERO);
            newWallet.setReservedBalance(BigDecimal.ZERO);
            return walletRepository.save(newWallet);
        });
    }

    @Transactional(readOnly = true)
    public WalletDto getWallet(UUID userId) {
        Wallet wallet = getOrCreateWalletEntity(userId);
        return new WalletDto(
                wallet.getId(),
                wallet.getBalance(),
                wallet.getReservedBalance(),
                wallet.getAvailableBalance()
        );
    }

    /**
     * Top-up demo / user funds and record transaction
     */
    @Transactional
    public WalletDto topUpFunds(UUID userId, BigDecimal amount, String description) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw BidlyException.badRequest("Top-up amount must be greater than zero");
        }

        Wallet wallet = walletRepository.findByUserIdWithLock(userId).orElseGet(() -> {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> BidlyException.notFound("User not found: " + userId));
            return walletRepository.save(new Wallet(user));
        });

        wallet.setBalance(wallet.getBalance().add(amount));
        walletRepository.save(wallet);

        WalletTransaction tx = new WalletTransaction(
                wallet,
                amount,
                WalletTransaction.TransactionType.CREDIT,
                null,
                "TOP_UP",
                description != null ? description : "Wallet balance top-up"
        );
        transactionRepository.save(tx);

        return new WalletDto(
                wallet.getId(),
                wallet.getBalance(),
                wallet.getReservedBalance(),
                wallet.getAvailableBalance()
        );
    }

    /**
     * Cryptographically verified Razorpay credit with idempotency protection.
     */
    @Transactional
    public WalletDto creditFromRazorpay(UUID userId, BigDecimal amount, String paymentLinkId, String paymentId) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw BidlyException.badRequest("Credit amount must be greater than zero");
        }

        Wallet wallet = walletRepository.findByUserIdWithLock(userId).orElseGet(() -> {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> BidlyException.notFound("User not found: " + userId));
            return walletRepository.save(new Wallet(user));
        });

        String marker = "[RAZORPAY:" + (paymentId != null ? paymentId : paymentLinkId) + "]";
        boolean alreadyCredited = transactionRepository.findByWalletIdOrderByCreatedAtDesc(wallet.getId()).stream()
                .anyMatch(t -> t.getDescription() != null && t.getDescription().contains(marker));

        if (alreadyCredited) {
            return new WalletDto(
                    wallet.getId(),
                    wallet.getBalance(),
                    wallet.getReservedBalance(),
                    wallet.getAvailableBalance()
            );
        }

        wallet.setBalance(wallet.getBalance().add(amount));
        walletRepository.save(wallet);

        WalletTransaction creditTx = new WalletTransaction(
                wallet,
                amount,
                WalletTransaction.TransactionType.CREDIT,
                null,
                "RAZORPAY",
                "Razorpay wallet credit " + marker + " (Link: " + paymentLinkId + ")"
        );
        transactionRepository.save(creditTx);

        return new WalletDto(
                wallet.getId(),
                wallet.getBalance(),
                wallet.getReservedBalance(),
                wallet.getAvailableBalance()
        );
    }

    @Transactional(readOnly = true)
    public boolean validateAvailableFunds(UUID userId, BigDecimal amount) {
        Wallet wallet = getOrCreateWalletEntity(userId);
        return wallet.getAvailableBalance().compareTo(amount) >= 0;
    }

    /**
     * Atomically reserves funds for an auction bid.
     */
    @Transactional
    public void reserveFunds(UUID userId, BigDecimal amount, UUID listingId) {
        Wallet wallet = walletRepository.findByUserIdWithLock(userId)
                .orElseThrow(() -> BidlyException.notFound("Wallet not found for user: " + userId));

        if (wallet.getAvailableBalance().compareTo(amount) < 0) {
            throw BidlyException.badRequest("Insufficient available funds in wallet to place this bid");
        }

        wallet.setReservedBalance(wallet.getReservedBalance().add(amount));
        walletRepository.save(wallet);

        WalletTransaction tx = new WalletTransaction(
                wallet,
                amount,
                WalletTransaction.TransactionType.RESERVE,
                listingId,
                "AUCTION_BID",
                "Reserved funds for auction bid on listing: " + listingId
        );
        transactionRepository.save(tx);
    }

    /**
     * Atomically releases previously reserved funds (e.g. when outbid or withdrawn).
     */
    @Transactional
    public void releaseFunds(UUID userId, BigDecimal amount, UUID listingId, String reason) {
        Wallet wallet = walletRepository.findByUserIdWithLock(userId)
                .orElseThrow(() -> BidlyException.notFound("Wallet not found for user: " + userId));

        BigDecimal releaseAmt = amount.min(wallet.getReservedBalance());
        wallet.setReservedBalance(wallet.getReservedBalance().subtract(releaseAmt));
        walletRepository.save(wallet);

        WalletTransaction tx = new WalletTransaction(
                wallet,
                releaseAmt,
                WalletTransaction.TransactionType.RELEASE,
                listingId,
                "AUCTION_BID",
                reason != null ? reason : "Released reserved funds for listing: " + listingId
        );
        transactionRepository.save(tx);
    }

    /**
     * Finalizes escrow hold when auction is won.
     */
    @Transactional
    public void convertReservationToEscrow(UUID userId, BigDecimal amount, UUID orderId) {
        Wallet wallet = walletRepository.findByUserIdWithLock(userId)
                .orElseThrow(() -> BidlyException.notFound("Wallet not found for user: " + userId));

        BigDecimal holdAmt = amount.min(wallet.getReservedBalance());
        wallet.setReservedBalance(wallet.getReservedBalance().subtract(holdAmt));
        wallet.setBalance(wallet.getBalance().subtract(holdAmt));
        walletRepository.save(wallet);

        WalletTransaction tx = new WalletTransaction(
                wallet,
                holdAmt,
                WalletTransaction.TransactionType.ESCROW_HOLD,
                orderId,
                "ORDER_PAYMENT",
                "Payment secured in escrow for order: " + orderId
        );
        transactionRepository.save(tx);
    }

    /**
     * Development-only helper to reset test wallet balance.
     */
    @Transactional
    public WalletDto devResetWallet(UUID userId) {
        Wallet wallet = walletRepository.findByUserIdWithLock(userId).orElseGet(() -> {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> BidlyException.notFound("User not found: " + userId));
            return walletRepository.save(new Wallet(user));
        });
        wallet.setBalance(BigDecimal.ZERO);
        wallet.setReservedBalance(BigDecimal.ZERO);
        Wallet saved = walletRepository.save(wallet);
        return new WalletDto(saved.getId(), saved.getBalance(), saved.getReservedBalance(), saved.getAvailableBalance());
    }
}
