package com.bidly.auction.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class AuctionScheduler {

    private static final Logger log = LoggerFactory.getLogger(AuctionScheduler.class);
    private final AuctionService auctionService;

    public AuctionScheduler(AuctionService auctionService) {
        this.auctionService = auctionService;
    }

    /**
     * Periodically check for expired active auctions every 10 seconds and finalize winners.
     */
    @Scheduled(fixedRate = 10000)
    public void processExpiredAuctions() {
        try {
            auctionService.finalizeExpiredAuctions();
        } catch (Exception e) {
            log.error("Error in background auction finalizer: {}", e.getMessage());
        }
    }
}
