package com.studysync.domain.policy;

import com.studysync.domain.entity.LostItemRecord;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Set;

/** 24-hour visibility window for lost-item reports. */
public final class LostFoundPolicy {

    public static final int REPORT_TTL_HOURS = 24;

    public static final String STATUS_REPORTED = "REPORTED";
    /** Legacy rows created before status normalization. */
    public static final String STATUS_LOST = "LOST";
    public static final String STATUS_FOUND = "FOUND";
    public static final String STATUS_EXPIRED = "EXPIRED";

    public static final List<String> OPEN_STATUSES = List.of(STATUS_REPORTED, STATUS_LOST);
    public static final List<String> VISIBLE_STATUSES = List.of(STATUS_REPORTED, STATUS_LOST, STATUS_FOUND);

    private static final Set<String> OPEN_STATUS_SET = Set.copyOf(OPEN_STATUSES);
    private static final Set<String> VISIBLE_STATUS_SET = Set.copyOf(VISIBLE_STATUSES);

    private LostFoundPolicy() {}

    public static Instant expiresAt(Instant reportedAt) {
        return reportedAt.plus(REPORT_TTL_HOURS, ChronoUnit.HOURS);
    }

    public static boolean isOpenStatus(String status) {
        return status != null && OPEN_STATUS_SET.contains(status);
    }

    public static boolean isVisibleStatus(String status) {
        return status != null && VISIBLE_STATUS_SET.contains(status);
    }

    public static boolean isActive(LostItemRecord record, Instant now) {
        if (record == null || record.getReportedAt() == null) {
            return false;
        }
        return isVisibleStatus(record.getStatus()) && expiresAt(record.getReportedAt()).isAfter(now);
    }
}
