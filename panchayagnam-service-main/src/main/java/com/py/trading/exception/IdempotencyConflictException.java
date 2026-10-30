package com.py.trading.exception;

public class IdempotencyConflictException extends RuntimeException {

    private final int statusCode;

    public IdempotencyConflictException(String message) {
        super(message);
        this.statusCode = 409;
    }

    public IdempotencyConflictException(int statusCode, String message) {
        super(message);
        this.statusCode = statusCode;
    }

    public int getStatusCode() {
        return statusCode;
    }
}
