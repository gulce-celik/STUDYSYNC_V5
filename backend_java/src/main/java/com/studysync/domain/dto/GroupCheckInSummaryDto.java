package com.studysync.domain.dto;

/** Per-reservation group check-in progress for API responses. */
public record GroupCheckInSummaryDto(
        boolean checkedIn,
        int groupCheckInDone,
        int groupCheckInRequired) {

    public static GroupCheckInSummaryDto individual(boolean checkedIn) {
        return new GroupCheckInSummaryDto(checkedIn, checkedIn ? 1 : 0, checkedIn ? 1 : 0);
    }

    public static GroupCheckInSummaryDto none() {
        return new GroupCheckInSummaryDto(false, 0, 0);
    }
}
