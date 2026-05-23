package com.studysync.domain.policy;

import com.studysync.domain.entity.LostItemRecord;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

/** 24-hour visibility window for lost-item reports. */
public final class LostFoundPolicy {

    public static final int REPORT_TTL_HOURS = 24;

    public static final String STATUS_REPORTED = "REPORTED";
    public static final String STATUS_FOUND = "FOUND";
    public static final String STATUS_EXPIRED = "EXPIRED";

    private LostFoundPolicy() {}

    public static Instant expiresAt(Instant reportedAt) {
        return reportedAt.plus(REPORT_TTL_HOURS, ChronoUnit.HOURS);
    }

    public static boolean isActive(LostItemRecord record, Instant now) {
        if (record == null || record.getReportedAt() == null) {
            return false;
        }
        return STATUS_REPORTED.equals(record.getStatus()) && expiresAt(record.getReportedAt()).isAfter(now);
    }
}
