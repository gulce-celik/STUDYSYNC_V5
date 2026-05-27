package com.studysync.domain.exception;

import org.springframework.http.HttpStatus;

public class UserNotFoundException extends StudySyncException {
    public UserNotFoundException(String message) {
        super(message, HttpStatus.NOT_FOUND);
    }
}
