package com.studysync.domain.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateBuddyListingRequestDto(
        @NotBlank(message = "Course code is required.")
        @Size(max = 16)
        String courseCode,

        @NotBlank(message = "Purpose is required.")
        @Size(max = 64)
        String purpose,

        @Size(max = 32)
        String preferredWeekday,

        @Size(max = 16)
        String preferredSlotId,

        @Size(max = 255)
        String note
) {}
