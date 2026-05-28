package com.studysync.domain.dto;

import java.util.List;

/** Pending group invitation for invitee home card — api-contract-v1. */
public record GroupInvitationDto(
        String id,
        String reservationId,
        String organizerName,
        String workspaceId,
        String date,
        String slotLabel,
        String expiresAt,
        List<String> memberPreview) {}
