package com.studysync.domain.dto;

/**
 * Study Buddy raporu — GET /admin/buddy-reports ve POST yanıtındaki {@code report} alanı.
 */
public record BuddyReportDto(
        String id,
        String reportedUserId,
        String reportedName,
        String reporterLabel,
        String reason,
        String comment,
        String createdAt,
        String status) {}
