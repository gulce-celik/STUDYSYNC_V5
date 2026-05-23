package com.studysync.domain.service;

import com.studysync.domain.dto.ActionResultDto;
import com.studysync.domain.dto.LostFoundReportResultDto;
import com.studysync.domain.dto.LostItemDto;
import com.studysync.domain.entity.LostItemRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.mapper.LostItemMapper;
import com.studysync.domain.policy.LostFoundPolicy;
import com.studysync.domain.repository.LostItemRecordRepository;
import com.studysync.domain.repository.UserAccountRepository;
import com.studysync.security.SecurityUtils;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LostFoundService {

    private final LostItemRecordRepository lostItemRepository;
    private final UserAccountRepository userAccountRepository;
    private final Clock clock;

    public LostFoundService(
            LostItemRecordRepository lostItemRepository,
            UserAccountRepository userAccountRepository,
            Clock clock) {
        this.lostItemRepository = lostItemRepository;
        this.userAccountRepository = userAccountRepository;
        this.clock = clock;
    }

    /** Active reports only: open status and within the 24h window. */
    @Transactional(readOnly = true)
    public List<LostItemDto> getLostItems() {
        Instant now = clock.instant();
        return lostItemRepository.findByStatusInOrderByReportedAtDesc(LostFoundPolicy.OPEN_STATUSES).stream()
                .filter(r -> LostFoundPolicy.isActive(r, now))
                .map(LostItemMapper::toDto)
                .toList();
    }

    @Transactional
    public LostFoundReportResultDto reportLostItem(
            String workspaceId, String description, UserAccount authenticatedUser) {
        try {
            UserAccount principal =
                    authenticatedUser != null ? authenticatedUser : SecurityUtils.requireCurrentUser();
            if (principal.getId() == null) {
                return new LostFoundReportResultDto(
                        false, "Authentication is missing. Please log in first.", null);
            }
            UserAccount reporter = userAccountRepository.getReferenceById(principal.getId());

            LostItemRecord record = new LostItemRecord();
            record.setWorkspaceId(workspaceId);
            record.setDescription(description);
            record.setReportedAt(clock.instant());
            record.setReportedBy(reporter);
            record.setCategory("GENERAL");
            record.setStatus(LostFoundPolicy.STATUS_REPORTED);

            LostItemRecord saved = lostItemRepository.saveAndFlush(record);
            LostItemDto item = LostItemMapper.toDto(saved, principal.getId());
            return new LostFoundReportResultDto(
                    true, "Item reported successfully at " + workspaceId, item);
        } catch (IllegalStateException ex) {
            return new LostFoundReportResultDto(false, ex.getMessage(), null);
        }
    }

    @Transactional
    public ActionResultDto markAsFound(String id, UserAccount authenticatedUser) {
        UserAccount principal;
        try {
            principal = authenticatedUser != null ? authenticatedUser : SecurityUtils.requireCurrentUser();
        } catch (IllegalStateException ex) {
            return new ActionResultDto(false, ex.getMessage(), null, null);
        }
        if (principal.getId() == null) {
            return new ActionResultDto(false, "Authentication is missing. Please log in first.", null, null);
        }

        String trimmed = id != null ? id.trim() : "";
        Long recordId;
        try {
            recordId = Long.parseLong(trimmed);
        } catch (NumberFormatException e) {
            return new ActionResultDto(
                    false, "Invalid item id \"" + trimmed + "\" — refresh the list and try again", null, null);
        }

        Instant now = clock.instant();
        return lostItemRepository
                .findById(recordId)
                .map(record -> {
                    if (LostFoundPolicy.STATUS_FOUND.equals(record.getStatus())) {
                        return new ActionResultDto(false, "Item is already marked as found", null, null);
                    }
                    if (LostFoundPolicy.STATUS_EXPIRED.equals(record.getStatus())
                            || !LostFoundPolicy.isActive(record, now)) {
                        return new ActionResultDto(false, "Item report has expired", null, null);
                    }
                    record.setStatus(LostFoundPolicy.STATUS_FOUND);
                    lostItemRepository.saveAndFlush(record);
                    return new ActionResultDto(true, "Item marked as found", null, null);
                })
                .orElseGet(() -> new ActionResultDto(
                        false, "Item not found (id=" + recordId + ") — refresh the list", null, null));
    }

    /** Deletes open items past the 24h visibility window. */
    @Transactional
    public int expireStaleReports(Instant now) {
        var stale = lostItemRepository.findByStatusInOrderByReportedAtDesc(LostFoundPolicy.OPEN_STATUSES).stream()
                .filter(record -> !LostFoundPolicy.isActive(record, now))
                .toList();
        if (!stale.isEmpty()) {
            lostItemRepository.deleteAll(stale);
        }
        return stale.size();
    }
}
