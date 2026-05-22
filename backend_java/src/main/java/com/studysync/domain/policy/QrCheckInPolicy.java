/* FILE PURPOSE: Tekrar kullanilan is kurali/politika hesabi (iptal skoru, QR dogrulama vb.). */

package com.studysync.domain.policy;

import com.studysync.config.TimeConfig;
import com.studysync.domain.campus.WorkspaceQrRegistry;
import com.studysync.domain.entity.ReservationRecord;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import org.springframework.stereotype.Component;

/**
 * QR yükü ile rezervasyon eşlemesi ve zaman penceresi — {@code POST /checkin/verify}.
 *
 * <p>Check-in window: from 15 minutes before slot start until 15 minutes after slot start (same calendar day,
 * {@link TimeConfig#CAMPUS_ZONE}).
 */
@Component
public class QrCheckInPolicy {

    public static final int EARLY_OPEN_MINUTES = 15;
    public static final int GRACE_AFTER_START_MINUTES = 15;

    private final Clock clock;
    private final WorkspaceQrRegistry workspaceQrRegistry;

    public QrCheckInPolicy(Clock clock, WorkspaceQrRegistry workspaceQrRegistry) {
        this.clock = clock;
        this.workspaceQrRegistry = workspaceQrRegistry;
    }

    public boolean isWithinCheckInWindow(ReservationRecord reservation) {
        return checkInRejectionReason(reservation) == null;
    }

    /**
     * @return human-readable rejection reason, or {@code null} if check-in is allowed now
     */
    public String checkInRejectionReason(ReservationRecord reservation) {
        if (reservation == null) {
            return "Reservation not found.";
        }

        ZoneId zone = TimeConfig.CAMPUS_ZONE;
        LocalDate today = LocalDate.now(clock);
        LocalDate reservationDate;
        try {
            reservationDate = LocalDate.parse(reservation.getDate());
        } catch (Exception e) {
            return "Invalid reservation date.";
        }
        if (!today.equals(reservationDate)) {
            return "Check-in is only available on your reservation date ("
                    + reservationDate + "). Today is " + today + " (Istanbul).";
        }

        LocalTime start = SlotStartTimeResolver.resolve(reservation);
        if (start == null) {
            return "Could not determine slot start time for this reservation.";
        }

        LocalTime now = LocalTime.now(clock);
        LocalTime opens = start.minusMinutes(EARLY_OPEN_MINUTES);
        LocalTime closes = start.plusMinutes(GRACE_AFTER_START_MINUTES);

        if (now.isBefore(opens)) {
            return "Check-in opens at " + opens + " (15 min before slot start at " + start + ", Istanbul).";
        }
        if (now.isAfter(closes)) {
            return "Check-in closed at " + closes + " (15 min after slot start at " + start + ", Istanbul).";
        }
        return null;
    }

    public boolean payloadMatchesReservation(ReservationRecord reservation, String qrPayload) {
        if (reservation == null || qrPayload == null) {
            return false;
        }
        String expected = workspaceQrRegistry.qrFor(reservation.getWorkspaceId());
        return qrPayload.trim().equals(expected);
    }

    public String qrMismatchReason(ReservationRecord reservation, String qrPayload) {
        if (reservation == null) {
            return "Reservation not found.";
        }
        String expected = workspaceQrRegistry.qrFor(reservation.getWorkspaceId());
        if (qrPayload == null || !qrPayload.trim().equals(expected)) {
            return "Invalid QR code. Expected " + expected + " for workspace "
                    + reservation.getWorkspaceId() + ".";
        }
        return null;
    }

    public Instant now() {
        return clock.instant();
    }
}
