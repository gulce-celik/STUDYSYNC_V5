package com.studysync.domain.policy;

import com.studysync.domain.entity.ReservationRecord;
import java.time.LocalTime;
import java.util.Map;

/** Resolves slot start time from {@code slotId} or {@code slotLabel} (e.g. {@code 09.00-11.00}). */
public final class SlotStartTimeResolver {

    private static final Map<String, LocalTime> SLOT_START_BY_ID = Map.of(
            "slot-1", LocalTime.of(6, 0),
            "slot-2", LocalTime.of(9, 0),
            "slot-3", LocalTime.of(11, 0),
            "slot-4", LocalTime.of(13, 0),
            "slot-5", LocalTime.of(15, 0),
            "slot-6", LocalTime.of(17, 0),
            "slot-7", LocalTime.of(20, 0),
            "slot-8", LocalTime.of(23, 0));

    private SlotStartTimeResolver() {}

    public static LocalTime resolve(ReservationRecord reservation) {
        if (reservation == null) {
            return null;
        }
        if (reservation.getSlotId() != null) {
            LocalTime byId = SLOT_START_BY_ID.get(reservation.getSlotId());
            if (byId != null) {
                return byId;
            }
        }
        return parseFromSlotLabel(reservation.getSlotLabel());
    }

    static LocalTime parseFromSlotLabel(String slotLabel) {
        if (slotLabel == null || slotLabel.length() < 5) {
            return null;
        }
        try {
            String startTimeStr = slotLabel.substring(0, 5).replace('.', ':');
            return LocalTime.parse(startTimeStr);
        } catch (Exception e) {
            return null;
        }
    }
}
