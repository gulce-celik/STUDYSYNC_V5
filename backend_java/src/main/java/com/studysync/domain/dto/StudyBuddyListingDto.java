package com.studysync.domain.dto;

import java.time.Instant;

public record StudyBuddyListingDto(
        Long id,
        String courseCode,
        String purpose,
        String preferredWeekday,
        String preferredSlotId,
        String note,
        String status,
        Instant createdAt
) {}
