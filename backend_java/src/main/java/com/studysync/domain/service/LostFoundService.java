package com.studysync.domain.service;

import com.studysync.domain.dto.ActionResultDto;
import com.studysync.domain.dto.LostItemDto;
import com.studysync.domain.entity.LostItemRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.mapper.LostItemMapper;
import com.studysync.domain.policy.LostFoundPolicy;
import com.studysync.domain.repository.LostItemRecordRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class LostFoundService {

    private final LostItemRecordRepository lostItemRepository;
    private final Clock clock;

    public LostFoundService(LostItemRecordRepository lostItemRepository, Clock clock) {
        this.lostItemRepository = lostItemRepository;
        this.clock = clock;
    }

    /** Active reports only: {@code REPORTED} and not past the 24h window. */
    public List<LostItemDto> getLostItems() {
        Instant now = clock.instant();
        return lostItemRepository.findByStatusOrderByReportedAtDesc(LostFoundPolicy.STATUS_REPORTED).stream()
                .filter(r -> LostFoundPolicy.isActive(r, now))
                .map(LostItemMapper::toDto)
                .toList();
    }

    public ActionResultDto reportLostItem(String workspaceId, String description, UserAccount reporter) {
        if (reporter == null) {
            return new ActionResultDto(false, "Authentication is missing. Please log in first.", null, null);
        }

        LostItemRecord record = new LostItemRecord();
        record.setWorkspaceId(workspaceId);
        record.setDescription(description);
        record.setReportedAt(clock.instant());
        record.setReportedBy(reporter);
        record.setCategory("GENERAL");
        record.setStatus(LostFoundPolicy.STATUS_REPORTED);

        lostItemRepository.save(record);
        return new ActionResultDto(true, "Item reported successfully at " + workspaceId, null, null);
    }

    public ActionResultDto markAsFound(String id) {
        Long recordId;
        try {
            recordId = Long.parseLong(id);
        } catch (NumberFormatException e) {
            return new ActionResultDto(false, "Invalid ID format", null, null);
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
                    lostItemRepository.save(record);
                    return new ActionResultDto(true, "Item marked as found", null, null);
                })
                .orElseGet(() -> new ActionResultDto(false, "Item not found", null, null));
    }

    /** Marks {@code REPORTED} items past the 24h window as {@code EXPIRED}. */
    public int expireStaleReports(Instant now) {
        int expired = 0;
        for (LostItemRecord record :
                lostItemRepository.findByStatusOrderByReportedAtDesc(LostFoundPolicy.STATUS_REPORTED)) {
            if (LostFoundPolicy.isActive(record, now)) {
                continue;
            }
            record.setStatus(LostFoundPolicy.STATUS_EXPIRED);
            lostItemRepository.save(record);
            expired++;
        }
        return expired;
    }
}
