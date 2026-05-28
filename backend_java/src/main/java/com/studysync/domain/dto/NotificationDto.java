package com.studysync.domain.dto;

/** In-app notification — api-contract-v1. */
public record NotificationDto(
        String id,
        String type,
        String title,
        String body,
        String createdAt,
        boolean read,
        String actionLabel,
        String relatedId) {}
