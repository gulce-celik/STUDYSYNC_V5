package com.studysync.domain.dto;

import java.time.Instant;

public record BuddyListingResponseDto(
        boolean success,
        String message,
        Long listingId,
        Integer updatedResponsibilityScore,
        Instant createdAt
) {}
