/* FILE PURPOSE: API veri tasima modeli (request/response); istemci sozlesmesiyle birebir alanlar. */

package com.studysync.domain.dto;

import java.util.List;

/**
 * Rezervasyon detayı — POST oluşturma yanıtı ve GET /reservations/me öğeleri.
 *
 * <p>{@code participants}: grup rezervasyonlarında nickname veya user id listesi; bireyselde boş veya tek eleman.
 */
public record ReservationDetailDto(
        String id,
        String workspaceId,
        String date,
        String slotId,
        String slotLabel,
        String status,
        String courseCode,
        List<String> participants,
        String qrPayload,
        int score
) {
}
