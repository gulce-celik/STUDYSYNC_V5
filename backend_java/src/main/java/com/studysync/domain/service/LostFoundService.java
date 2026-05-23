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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LostFoundService {

    private static final Logger logger = LoggerFactory.getLogger(LostFoundService.class);

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
            UserAccount reporter = resolveAuthenticatedUser(authenticatedUser);

            LostItemRecord record = new LostItemRecord();
            record.setWorkspaceId(workspaceId);
            record.setDescription(description);
            record.setReportedAt(clock.instant());
            record.setReportedBy(reporter);
            record.setCategory("GENERAL");
            record.setStatus(LostFoundPolicy.STATUS_REPORTED);

            LostItemRecord saved = lostItemRepository.saveAndFlush(record);
            LostItemRecord loaded = lostItemRepository
                    .findByIdWithReporter(saved.getId())
                    .orElse(saved);
            LostItemDto item = LostItemMapper.toDto(loaded);
            return new LostFoundReportResultDto(
                    true, "Item reported successfully at " + workspaceId, item);
        } catch (IllegalStateException ex) {
            return new LostFoundReportResultDto(false, ex.getMessage(), null);
        } catch (DataIntegrityViolationException ex) {
            logger.warn("Lost-item report failed — reporter FK: {}", ex.getMessage());
            return new LostFoundReportResultDto(
                    false, "Could not save report — log out, log in again, and retry.", null);
        }
    }

    @Transactional
    public ActionResultDto markAsFound(String id, UserAccount authenticatedUser) {
        try {
            resolveAuthenticatedUser(authenticatedUser);
        } catch (IllegalStateException ex) {
            return new ActionResultDto(false, ex.getMessage(), null, null);
        }

        String trimmed = id != null ? id.trim() : "";
        Long recordId;
        try {
            recordId = Long.parseLong(trimmed);
        } catch (NumberFormatException e) {
            return new ActionResultDto(
                    false, "Invalid item id \"" + trimmed + "\" — refresh the list and try again", null, null);
        }

        final Long itemId = recordId;
        Instant now = clock.instant();
        return lostItemRepository
                .findByIdWithReporter(itemId)
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
                .orElseGet(() -> {
                    logger.warn("markAsFound: no lost_items row for id={}", itemId);
                    return new ActionResultDto(
                            false, "Item not found (id=" + itemId + ") — pull to refresh the list", null, null);
                });
    }

    /**
     * Resolves the JWT user to a managed {@link UserAccount} row so {@code reported_by_user_id} is always set.
     */
    private UserAccount resolveAuthenticatedUser(UserAccount fromPrincipal) {
        Long userId = null;
        if (fromPrincipal != null && fromPrincipal.getId() != null) {
            userId = fromPrincipal.getId();
        } else {
            UserAccount fromContext = SecurityUtils.requireCurrentUser();
            userId = fromContext.getId();
        }
        if (userId == null) {
            throw new IllegalStateException("Authentication is missing. Please log in first.");
        }
        final Long resolvedUserId = userId;
        return userAccountRepository
                .findById(resolvedUserId)
                .orElseThrow(() -> new IllegalStateException(
                        "User account not found (id=" + resolvedUserId + "). Log out and log in again."));
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
