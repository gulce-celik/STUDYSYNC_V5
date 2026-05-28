package com.studysync.domain.service;

import com.studysync.domain.dto.NotificationDto;
import com.studysync.domain.entity.NotificationRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.exception.AccessDeniedException;
import com.studysync.domain.exception.ResourceNotFoundException;
import com.studysync.domain.mapper.NotificationMapper;
import com.studysync.domain.repository.NotificationRecordRepository;
import com.studysync.security.SecurityUtils;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NotificationService {

    public static final String TYPE_GROUP_INVITATION = "GROUP_INVITATION";

    private final NotificationRecordRepository notificationRepository;
    private final Clock clock;

    public NotificationService(NotificationRecordRepository notificationRepository, Clock clock) {
        this.notificationRepository = notificationRepository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<NotificationDto> listForCurrentUser() {
        UserAccount user = SecurityUtils.requireCurrentUser();
        return notificationRepository.findByUser_IdOrderByCreatedAtDesc(user.getId()).stream()
                .map(NotificationMapper::toDto)
                .toList();
    }

    @Transactional
    public void markRead(String notificationId) {
        UserAccount user = SecurityUtils.requireCurrentUser();
        NotificationRecord record = notificationRepository
                .findById(Long.parseLong(notificationId))
                .orElseThrow(() -> new ResourceNotFoundException("Notification", notificationId));
        if (!record.getUser().getId().equals(user.getId())) {
            throw new AccessDeniedException("You can only update your own notifications.");
        }
        record.setRead(true);
        notificationRepository.save(record);
    }

    @Transactional
    public void markAllRead() {
        UserAccount user = SecurityUtils.requireCurrentUser();
        notificationRepository.markAllReadForUser(user.getId());
    }

    @Transactional
    public NotificationRecord emitGroupInvitation(
            UserAccount recipient,
            String inviteId,
            String organizerName,
            String workspaceId,
            String slotLabel,
            String date) {
        NotificationRecord record = new NotificationRecord();
        record.setUser(recipient);
        record.setType(TYPE_GROUP_INVITATION);
        record.setTitle("Group study invitation");
        record.setBody(organizerName + " invited you to " + workspaceId + " · " + slotLabel + " on " + date);
        record.setCreatedAt(clock.instant());
        record.setRead(false);
        record.setActionLabel("View on Home");
        record.setRelatedId(inviteId);
        return notificationRepository.save(record);
    }
}
