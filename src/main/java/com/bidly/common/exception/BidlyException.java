package com.bidly.common.exception;

import org.springframework.http.HttpStatus;

/**
 * Base application exception for all Bidly business errors.
 */
public class BidlyException extends RuntimeException {

    private final HttpStatus status;

    public BidlyException(String message, HttpStatus status) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public static BidlyException notFound(String entity) {
        return new BidlyException(entity + " not found", HttpStatus.NOT_FOUND);
    }

    public static BidlyException badRequest(String message) {
        return new BidlyException(message, HttpStatus.BAD_REQUEST);
    }

    public static BidlyException unauthorized(String message) {
        return new BidlyException(message, HttpStatus.UNAUTHORIZED);
    }

    public static BidlyException forbidden(String message) {
        return new BidlyException(message, HttpStatus.FORBIDDEN);
    }

    public static BidlyException conflict(String message) {
        return new BidlyException(message, HttpStatus.CONFLICT);
    }

    public static BidlyException internal(String message) {
        return new BidlyException(message, HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
