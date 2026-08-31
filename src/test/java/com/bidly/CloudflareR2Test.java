package com.bidly;

import org.junit.jupiter.api.Test;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

public class CloudflareR2Test {

    @Test
    void testUploadToR2() {
        String accountId = "09bab7db75eb791e40f5ae771a474164";
        String accessKeyId = "ded71d20dfb10bc1416fa2df4f6fc480";
        String secretAccessKey = "4a0f6b8613f06e88c694761257883a57b62f2f922ca7875679450974680df0d3";
        String bucketName = "bidly-media";

        String key = "test/hello-" + UUID.randomUUID() + ".txt";
        byte[] bytes = "Hello from Bidly test!".getBytes(StandardCharsets.UTF_8);

        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(bucketName)
                .key(key)
                .contentType("text/plain")
                .build();

        // 1. Test Path Style
        software.amazon.awssdk.services.s3.S3Configuration pathConfig = software.amazon.awssdk.services.s3.S3Configuration.builder()
                .pathStyleAccessEnabled(true)
                .chunkedEncodingEnabled(false)
                .build();

        S3Client s3Path = S3Client.builder()
                .endpointOverride(URI.create("https://" + accountId + ".r2.cloudflarestorage.com"))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKeyId, secretAccessKey)))
                .region(Region.of("auto"))
                .serviceConfiguration(pathConfig)
                .build();

        try {
            System.out.println("Testing putObject with PATH style...");
            s3Path.putObject(putRequest, RequestBody.fromBytes(bytes));
            System.out.println(">>> SUCCESS (Path Style): Uploaded file to Cloudflare R2!");
            return;
        } catch (Exception e) {
            System.err.println("Path style putObject failed: " + e.getMessage());
        }

        // 2. Test Virtual Host Style
        software.amazon.awssdk.services.s3.S3Configuration virtualConfig = software.amazon.awssdk.services.s3.S3Configuration.builder()
                .pathStyleAccessEnabled(false)
                .chunkedEncodingEnabled(false)
                .build();

        S3Client s3Virtual = S3Client.builder()
                .endpointOverride(URI.create("https://" + accountId + ".r2.cloudflarestorage.com"))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKeyId, secretAccessKey)))
                .region(Region.of("auto"))
                .serviceConfiguration(virtualConfig)
                .build();

        try {
            System.out.println("Testing putObject with VIRTUAL HOST style...");
            s3Virtual.putObject(putRequest, RequestBody.fromBytes(bytes));
            System.out.println(">>> SUCCESS (Virtual Host): Uploaded file to Cloudflare R2!");
            return;
        } catch (Exception e) {
            System.err.println("Virtual Host putObject failed: " + e.getMessage());
        }
    }
}
