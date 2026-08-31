package com.bidly.common.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.net.URI;

/**
 * AWS SDK v2 configuration pointing to Cloudflare R2.
 * R2 is S3-compatible; we override the endpoint URL with the R2 account endpoint.
 */
@Configuration
public class CloudflareR2Config {

    @Value("${cloudflare.r2.account-id}")
    private String accountId;

    @Value("${cloudflare.r2.access-key-id}")
    private String accessKeyId;

    @Value("${cloudflare.r2.secret-access-key}")
    private String secretAccessKey;

    /** S3Client configured for Cloudflare R2 endpoint. */
    @Bean
    public S3Client s3Client() {
        software.amazon.awssdk.services.s3.S3Configuration s3Config = software.amazon.awssdk.services.s3.S3Configuration.builder()
                .pathStyleAccessEnabled(true)
                .chunkedEncodingEnabled(false)
                .build();

        return S3Client.builder()
                .endpointOverride(r2Endpoint())
                .credentialsProvider(credentials())
                .region(Region.of("auto"))          // R2 uses "auto" region
                .serviceConfiguration(s3Config)
                .build();
    }

    /** S3Presigner for generating pre-signed upload/download URLs. */
    @Bean
    public S3Presigner s3Presigner() {
        return S3Presigner.builder()
                .endpointOverride(r2Endpoint())
                .credentialsProvider(credentials())
                .region(Region.of("auto"))
                .build();
    }

    private URI r2Endpoint() {
        return URI.create("https://" + accountId + ".r2.cloudflarestorage.com");
    }

    private StaticCredentialsProvider credentials() {
        return StaticCredentialsProvider.create(
                AwsBasicCredentials.create(accessKeyId, secretAccessKey)
        );
    }
}
