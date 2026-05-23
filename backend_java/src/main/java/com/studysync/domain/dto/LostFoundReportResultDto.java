package com.studysync.domain.dto;

/** {@code POST /lost-found} — persisted item plus action result. */
public record LostFoundReportResultDto(Boolean success, String message, LostItemDto item) {}
