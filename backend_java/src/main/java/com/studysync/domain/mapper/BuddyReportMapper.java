/* FILE PURPOSE: Entity-DTO donusumleri; API modeli ile persistence modeli arasinda esleme. */

package com.studysync.domain.mapper;

import com.studysync.domain.dto.BuddyReportDto;
import com.studysync.domain.entity.BuddyReportRecord;
import com.studysync.domain.entity.UserAccount;
import java.time.format.DateTimeFormatter;

/** {@link BuddyReportRecord} → {@link BuddyReportDto}; {@code createdAt} ISO-8601. */
public final class BuddyReportMapper {

    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_INSTANT;

    private BuddyReportMapper() {}

    public static BuddyReportDto toDto(BuddyReportRecord r) {
        if (r == null) {
            return null;
        }
        final String createdAt = r.getCreatedAt() != null ? ISO.format(r.getCreatedAt()) : "";
        final UserAccount reported = r.getReportedUser();
        final UserAccount reporter = r.getReportedBy();
        final String reportedUserId =
                reported != null && reported.getId() != null ? String.valueOf(reported.getId()) : "";
        final String reportedName = reported != null && reported.getName() != null ? reported.getName() : "";
        final String reporterLabel = reporter != null && reporter.getName() != null ? reporter.getName() : "Student";
        return new BuddyReportDto(
                r.getId() != null ? String.valueOf(r.getId()) : "",
                reportedUserId,
                reportedName,
                reporterLabel,
                r.getReason() != null ? r.getReason() : "",
                r.getComment() != null ? r.getComment() : "",
                createdAt,
                r.getStatus() != null ? r.getStatus() : "");
    }
}
