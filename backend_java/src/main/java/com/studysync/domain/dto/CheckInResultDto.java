/* FILE PURPOSE: API veri tasima modeli (request/response); istemci sozlesmesiyle birebir alanlar. */

package com.studysync.domain.dto;

/** Check-in response — success, message, and optional group progress. */
public record CheckInResultDto(
        boolean success,
        String message,
        boolean completed,
        int checkedInCount,
        int requiredCount) {

    public static CheckInResultDto failure(String message) {
        return new CheckInResultDto(false, message, false, 0, 0);
    }
}
