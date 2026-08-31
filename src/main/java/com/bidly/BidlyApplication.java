package com.bidly;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@SpringBootApplication
@EnableJpaAuditing
@org.springframework.scheduling.annotation.EnableScheduling
public class BidlyApplication {
    public static void main(String[] args) {
        SpringApplication.run(BidlyApplication.class, args);
    }
}
