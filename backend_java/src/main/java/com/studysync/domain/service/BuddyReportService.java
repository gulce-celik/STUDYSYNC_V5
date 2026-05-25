package com.studysync.domain.service;

import com.studysync.domain.dto.BuddyReportDto;
import com.studysync.domain.dto.BuddyReportResultDto;
import com.studysync.domain.dto.CreateBuddyReportRequestDto;
import com.studysync.domain.entity.BuddyReportRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.mapper.BuddyReportMapper;
import com.studysync.domain.policy.BuddyReportPolicy;
import com.studysync.domain.repository.BuddyReportRecordRepository;
import com.studysync.domain.repository.UserAccountRepository;
import com.studysync.security.SecurityUtils;
import java.time.Clock;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BuddyReportService {

    private static final Logger logger = LoggerFactory.getLogger(BuddyReportService.class);

    private final BuddyReportRecordRepository buddyReportRepository;
    private final UserAccountRepository userAccountRepository;
    private final Clock clock;

    public BuddyReportService(
            BuddyReportRecordRepository buddyReportRepository,
            UserAccountRepository userAccountRepository,
            Clock clock) {
        this.buddyReportRepository = buddyReportRepository;
        this.userAccountRepository = userAccountRepository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<BuddyReportDto> listOpenReports() {
        return buddyReportRepository.findByStatusWithUsersOrderByCreatedAtDesc(BuddyReportPolicy.STATUS_OPEN).stream()
                .map(BuddyReportMapper::toDto)
                .toList();
    }

    @Transactional
    public BuddyReportResultDto submitReport(
            CreateBuddyReportRequestDto body, UserAccount authenticatedUser) {
        try {
            UserAccount reporter = resolveAuthenticatedUser(authenticatedUser);
            UserAccount reported = resolveReportedUser(body.reportedUserId());

            if (reported.getId().equals(reporter.getId())) {
                return new BuddyReportResultDto(false, "You cannot report yourself.", null);
            }

            BuddyReportRecord record = new BuddyReportRecord();
            record.setReportedUser(reported);
            record.setReportedBy(reporter);
            record.setReason(body.reason().trim());
            String comment = body.comment();
            record.setComment(comment != null && !comment.isBlank() ? comment.trim() : null);
            record.setCreatedAt(clock.instant());
            record.setStatus(BuddyReportPolicy.STATUS_OPEN);

            BuddyReportRecord saved = buddyReportRepository.saveAndFlush(record);
            BuddyReportRecord loaded =
                    buddyReportRepository.findByIdWithUsers(saved.getId()).orElse(saved);
            BuddyReportDto dto = BuddyReportMapper.toDto(loaded);
            return new BuddyReportResultDto(true, "Report submitted successfully.", dto);
        } catch (IllegalStateException ex) {
            return new BuddyReportResultDto(false, ex.getMessage(), null);
        } catch (DataIntegrityViolationException ex) {
            logger.warn("Buddy report failed — FK: {}", ex.getMessage());
            return new BuddyReportResultDto(
                    false, "Could not save report — log out, log in again, and retry.", null);
        }
    }

    private UserAccount resolveReportedUser(String reportedUserId) {
        String trimmed = reportedUserId != null ? reportedUserId.trim() : "";
        if (trimmed.isEmpty()) {
            throw new IllegalStateException("Reported user id is required.");
        }
        Long id;
        try {
            id = Long.parseLong(trimmed);
        } catch (NumberFormatException e) {
            throw new IllegalStateException(
                    "Invalid reported user id \"" + trimmed + "\" — refresh and try again.");
        }
        return userAccountRepository
                .findById(id)
                .orElseThrow(() -> new IllegalStateException(
                        "Reported user not found (id=" + id + "). Refresh the buddy list and try again."));
    }

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
}
