package com.studysync.domain.dto;

/**
 * Kayıp eşya kaydı — GET /lost-found (active reports only).
 */
public record LostItemDto(
        String id,
        String workspaceId,
        String description,
        String reportedAt,
        String expiresAt,
        String category,
        String status
) {}
