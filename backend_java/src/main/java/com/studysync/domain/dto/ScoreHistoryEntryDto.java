package com.studysync.domain.dto;

/** One responsibility score event for profile / history UI. */
public record ScoreHistoryEntryDto(
        String id,
        String date,
        int scoreChange,
        String description,
        String status
) {}
