package com.studysync.domain.dto;

/** Computed invite state for reservation detail responses (not stored on ReservationRecord). */
public record GroupInviteSummaryDto(String expiresAt, boolean invitesConfirmed) {

    public static GroupInviteSummaryDto none() {
        return new GroupInviteSummaryDto(null, true);
    }
}
