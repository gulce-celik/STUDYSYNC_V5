/* FILE PURPOSE: API veri tasima modeli (request/response); istemci sozlesmesiyle birebir alanlar. */

package com.studysync.domain.dto;

import java.util.List;

/** {@code GET /dashboard/home} — ana ekran kartları. */
public record HomeDashboardResponseDto(
        int responsibilityScore,
        List<ReservationSummaryDto> upcomingReservations,
        QuickStatsDto quickStats,
        List<ScoreHistoryEntryDto> scoreHistory) {}
