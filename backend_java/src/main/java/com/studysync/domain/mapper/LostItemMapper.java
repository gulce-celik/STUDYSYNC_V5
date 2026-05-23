/* FILE PURPOSE: Entity-DTO donusumleri; API modeli ile persistence modeli arasinda esleme. */

package com.studysync.domain.mapper;

import com.studysync.domain.dto.LostItemDto;
import com.studysync.domain.entity.LostItemRecord;
import com.studysync.domain.policy.LostFoundPolicy;
import java.time.format.DateTimeFormatter;

/**
 * {@link LostItemRecord} → {@link LostItemDto}; {@code reportedAt} / {@code expiresAt} ISO-8601 (Flutter parse).
 */
public final class LostItemMapper {

    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_INSTANT;

    private LostItemMapper() {}

    public static LostItemDto toDto(LostItemRecord r) {
        if (r == null) {
            return null;
        }
        final String reportedAt = r.getReportedAt() != null ? ISO.format(r.getReportedAt()) : "";
        final String expiresAt = r.getReportedAt() != null
                ? ISO.format(LostFoundPolicy.expiresAt(r.getReportedAt()))
                : "";
        final String reporterId = r.getReportedBy() != null && r.getReportedBy().getId() != null
                ? String.valueOf(r.getReportedBy().getId())
                : null;
        return new LostItemDto(
                String.valueOf(r.getId()),
                r.getWorkspaceId(),
                r.getDescription(),
                reportedAt,
                expiresAt,
                r.getCategory() != null ? r.getCategory() : "GENERAL",
                r.getStatus() != null ? r.getStatus() : LostFoundPolicy.STATUS_REPORTED,
                reporterId);
    }
}
