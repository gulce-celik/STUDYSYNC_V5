/* FILE PURPOSE: Entity-DTO donusumleri; API modeli ile persistence modeli arasinda esleme. */

package com.studysync.domain.mapper;

import com.studysync.domain.dto.ReservationDetailDto;
import com.studysync.domain.dto.ReservationSummaryDto;
import com.studysync.domain.entity.ReservationRecord;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Collections;
import java.util.List;

/**
 * {@link ReservationRecord} ↔ sözleşme DTO’ları; {@code participantsJson} → {@code List<String>}.
 *
 * <p><b>Kullanım:</b> {@link com.fasterxml.jackson.databind.ObjectMapper} veya JDBC JSON tipi; hata durumunda boş liste.
 */
public final class ReservationMapper {

    private ReservationMapper() {}

    public static ReservationSummaryDto toSummary(ReservationRecord r) {
        if (r == null) {
            return null;
        }
        return new ReservationSummaryDto(
                String.valueOf(r.getId()),
                r.getWorkspaceId(),
                r.getDate(),
                r.getSlotLabel() != null ? r.getSlotLabel() : r.getSlotId(),
                r.getStatus());
    }

    public static ReservationDetailDto toDetail(
            ReservationRecord r, ObjectMapper objectMapper, String qrPayload) {
        if (r == null) {
            return null;
        }
        List<String> participants = parseParticipants(r.getParticipantsJson(), objectMapper);
        String qr = qrPayload != null ? qrPayload : "";
        return new ReservationDetailDto(
                String.valueOf(r.getId()),
                r.getWorkspaceId(),
                r.getDate(),
                r.getSlotId(),
                r.getSlotLabel() != null ? r.getSlotLabel() : r.getSlotId(),
                r.getStatus(),
                r.getCourseCode() != null ? r.getCourseCode() : "",
                participants,
                qr,
                r.getScore());
    }

    /**
     * Effective score delta for terminal reservations; legacy rows may have {@code 0} with terminal status.
     */
    public static int resolveScore(ReservationRecord r) {
        if (r.getScore() != 0) {
            return r.getScore();
        }
        return switch (r.getStatus() != null ? r.getStatus().toUpperCase().trim() : "") {
            case "COMPLETED" -> 5;
            case "NO_SHOW" -> -10;
            default -> 0;
        };
    }

    public static String scoreHistoryDescription(ReservationRecord r, int scoreChange) {
        String slot = r.getSlotLabel() != null && !r.getSlotLabel().isBlank()
                ? r.getSlotLabel()
                : r.getSlotId();
        return switch (r.getStatus() != null ? r.getStatus().toUpperCase().trim() : "") {
            case "COMPLETED" -> "Check-in completed · " + r.getWorkspaceId() + " · " + slot;
            case "NO_SHOW" -> "No-show · " + r.getCourseCode() + " · " + slot;
            case "CANCELLED" -> scoreChange >= 3
                    ? "Early cancellation · " + r.getCourseCode()
                    : scoreChange <= -5
                            ? "Late cancellation · " + r.getCourseCode()
                            : "Cancellation · " + r.getCourseCode() + " · " + slot;
            default -> r.getStatus() + " · " + r.getCourseCode();
        };
    }

    public static boolean isTerminalStatus(String status) {
        if (status == null) {
            return false;
        }
        return switch (status.toUpperCase().trim()) {
            case "COMPLETED", "CANCELLED", "NO_SHOW" -> true;
            default -> false;
        };
    }

    private static List<String> parseParticipants(String json, ObjectMapper objectMapper) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<List<String>>() {});
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }
}
