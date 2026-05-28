package com.studysync.domain.mapper;

import com.studysync.domain.dto.NotificationDto;
import com.studysync.domain.entity.NotificationRecord;

public final class NotificationMapper {

    private NotificationMapper() {}

    public static NotificationDto toDto(NotificationRecord record) {
        if (record == null) {
            return null;
        }
        return new NotificationDto(
                String.valueOf(record.getId()),
                record.getType(),
                record.getTitle(),
                record.getBody(),
                record.getCreatedAt() != null ? record.getCreatedAt().toString() : null,
                record.isRead(),
                record.getActionLabel(),
                record.getRelatedId());
    }
}
