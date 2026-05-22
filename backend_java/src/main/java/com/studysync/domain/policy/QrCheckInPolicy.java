/* FILE PURPOSE: Tekrar kullanilan is kurali/politika hesabi (iptal skoru, QR dogrulama vb.). */

package com.studysync.domain.policy;

import com.studysync.domain.campus.WorkspaceQrRegistry;
import com.studysync.domain.entity.ReservationRecord;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import org.springframework.stereotype.Component;

/**
 * QR yükü ile rezervasyon eşlemesi ve zaman penceresi — {@code POST /checkin/verify}.
 *
 * <p>Check-in window: from 15 minutes before slot start until 15 minutes after slot start (same calendar day).
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
        if (reservation == null) {
            return false;
        }

        LocalDate today = LocalDate.now(clock);
        LocalDate reservationDate;
        try {
            reservationDate = LocalDate.parse(reservation.getDate());
        } catch (Exception e) {
            return false;
        }
        if (!today.equals(reservationDate)) {
            return false;
        }

        LocalTime start = SlotStartTimeResolver.resolve(reservation);
        if (start == null) {
            return false;
        }

        LocalTime now = LocalTime.now(clock);
        LocalTime opens = start.minusMinutes(EARLY_OPEN_MINUTES);
        LocalTime closes = start.plusMinutes(GRACE_AFTER_START_MINUTES);
        return !now.isBefore(opens) && !now.isAfter(closes);
    }

    public boolean payloadMatchesReservation(ReservationRecord reservation, String qrPayload) {
        if (reservation == null || qrPayload == null) {
            return false;
        }
        String expected = workspaceQrRegistry.qrFor(reservation.getWorkspaceId());
        return qrPayload.trim().equals(expected);
    }

    public Instant now() {
        return clock.instant();
    }
}
