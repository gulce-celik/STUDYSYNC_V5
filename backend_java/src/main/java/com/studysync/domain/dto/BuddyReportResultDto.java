package com.studysync.domain.dto;

/** {@code POST /study-buddies/reports} — kaydedilen rapor ve işlem sonucu. */
public record BuddyReportResultDto(Boolean success, String message, BuddyReportDto report) {}
