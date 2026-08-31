package com.bidly.media.controller;

import com.bidly.common.dto.ApiResponse;
import com.bidly.media.dto.PresignedUrlResponse;
import com.bidly.media.service.MediaService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.constraints.NotBlank;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/**
 * Endpoints for Flutter to upload images and videos directly to Cloudflare R2.
 */
@RestController
@RequestMapping("/media")
public class MediaController {

    private static final Logger log = LoggerFactory.getLogger(MediaController.class);

    private final MediaService mediaService;

    public MediaController(MediaService mediaService) {
        this.mediaService = mediaService;
    }

    /**
     * POST /api/media/upload — Upload media file directly to Cloudflare R2
     */
    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<Map<String, String>>> uploadFile(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "folder", defaultValue = "listings") String folder) {

        Map<String, String> data = mediaService.uploadMediaFile(file, folder);

        return ResponseEntity.ok(ApiResponse.success("File uploaded to Cloudflare R2 successfully", data));
    }

    /**
     * GET /api/media/presigned-url?folder=listings/uuid&ext=jpg&contentType=image/jpeg
     */
    @GetMapping("/presigned-url")
    public ResponseEntity<ApiResponse<PresignedUrlResponse>> getPresignedUrl(
            @RequestParam @NotBlank String folder,
            @RequestParam @NotBlank String ext,
            @RequestParam(defaultValue = "image/jpeg") String contentType) {

        PresignedUrlResponse response =
                mediaService.generatePresignedUploadUrl(folder, ext, contentType);

        return ResponseEntity.ok(ApiResponse.success("Pre-signed URL generated", response));
    }

    /**
     * GET /api/media/file/** — Direct chunk streaming for videos & images from R2 bucket.
     */
    @GetMapping("/file/**")
    public void getMediaFile(
            @RequestHeader(value = "Range", required = false) String rangeHeader,
            HttpServletRequest request,
            HttpServletResponse response) throws IOException {

        String fullPath = request.getRequestURI();
        String objectKey = "";
        if (fullPath.contains("/file/")) {
            objectKey = fullPath.substring(fullPath.indexOf("/file/") + 6);
        } else {
            objectKey = fullPath;
        }
        while (objectKey.startsWith("/")) {
            objectKey = objectKey.substring(1);
        }

        String mimeType = "image/jpeg";
        String lowerKey = objectKey.toLowerCase();
        if (lowerKey.endsWith(".png")) {
            mimeType = "image/png";
        } else if (lowerKey.endsWith(".webp")) {
            mimeType = "image/webp";
        } else if (lowerKey.endsWith(".gif")) {
            mimeType = "image/gif";
        } else if (lowerKey.endsWith(".mp4")) {
            mimeType = "video/mp4";
        }

        ResponseInputStream<GetObjectResponse> s3Stream;
        try {
            s3Stream = mediaService.getObjectStream(objectKey, rangeHeader);
        } catch (software.amazon.awssdk.services.s3.model.S3Exception e) {
            if (e.statusCode() == 416) {
                response.setStatus(HttpServletResponse.SC_REQUESTED_RANGE_NOT_SATISFIABLE);
                response.setHeader(HttpHeaders.ACCEPT_RANGES, "bytes");
                response.setHeader(HttpHeaders.CONTENT_RANGE, "bytes */*");
                return;
            } else if (e.statusCode() == 404 || (e.awsErrorDetails() != null && "NoSuchKey".equalsIgnoreCase(e.awsErrorDetails().errorCode()))) {
                response.setStatus(HttpServletResponse.SC_NOT_FOUND);
                return;
            }
            log.warn("S3 error for key '{}': {}", objectKey, e.getMessage());
            response.setStatus(HttpServletResponse.SC_NOT_FOUND);
            return;
        } catch (Exception e) {
            log.warn("Media streaming error for key '{}': {}", objectKey, e.getMessage());
            response.setStatus(HttpServletResponse.SC_NOT_FOUND);
            return;
        }

        GetObjectResponse s3Response = s3Stream.response();
        boolean isPartial = s3Response.contentRange() != null && !s3Response.contentRange().isBlank();

        response.setStatus(isPartial ? HttpServletResponse.SC_PARTIAL_CONTENT : HttpServletResponse.SC_OK);
        response.setContentType(mimeType);
        response.setHeader(HttpHeaders.ACCEPT_RANGES, "bytes");
        response.setHeader(HttpHeaders.CACHE_CONTROL, "public, max-age=2592000");

        if (s3Response.contentRange() != null && !s3Response.contentRange().isBlank()) {
            response.setHeader(HttpHeaders.CONTENT_RANGE, s3Response.contentRange());
        }
        if (s3Response.contentLength() != null) {
            response.setContentLengthLong(s3Response.contentLength());
        }

        try (s3Stream; var out = response.getOutputStream()) {
            byte[] buffer = new byte[65536];
            int bytesRead;
            while ((bytesRead = s3Stream.read(buffer)) != -1) {
                try {
                    out.write(buffer, 0, bytesRead);
                } catch (Exception clientClosed) {
                    break;
                }
            }
            try {
                out.flush();
            } catch (Exception ignored) {}
        } catch (Exception ignored) {}
    }
}
