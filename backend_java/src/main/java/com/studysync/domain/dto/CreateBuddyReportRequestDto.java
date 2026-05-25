/* FILE PURPOSE: API veri tasima modeli (request/response); istemci sozlesmesiyle birebir alanlar. */

package com.studysync.domain.dto;

import jakarta.validation.constraints.NotBlank;

/** {@code POST /study-buddies/reports} — Study Buddy kullanıcı şikayeti. */
public record CreateBuddyReportRequestDto(
        @NotBlank String reportedUserId, @NotBlank String reason, String comment) {}
