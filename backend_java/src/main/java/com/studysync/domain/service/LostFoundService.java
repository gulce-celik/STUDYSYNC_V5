package com.studysync.domain.service;

import com.studysync.domain.dto.ActionResultDto;
import com.studysync.domain.dto.LostItemDto;
import com.studysync.domain.entity.LostItemRecord;
import com.studysync.domain.repository.LostItemRecordRepository;
import java.util.List;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

@Service
public class LostFoundService {

    private final LostItemRecordRepository lostItemRepository;

    public LostFoundService(LostItemRecordRepository lostItemRepository) {
        this.lostItemRepository = lostItemRepository;
    }

    public List<LostItemDto> getLostItems() {
        return lostItemRepository.findAll().stream()
            .map(r -> new LostItemDto(
                r.getId().toString(),
                r.getWorkspaceId(),
                r.getDescription(),
                r.getReportedAt().toString(),
                r.getCategory() != null ? r.getCategory() : "GENERAL",
                r.getStatus() != null ? r.getStatus() : "REPORTED"
            ))
            .collect(Collectors.toList());
    }

    public ActionResultDto reportLostItem(String workspaceId, String description) {
        LostItemRecord record = new LostItemRecord();
        record.setWorkspaceId(workspaceId);
        record.setDescription(description);
        record.setReportedAt(java.time.Instant.now());
        record.setCategory("GENERAL");
        record.setStatus("REPORTED");
        
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

        return lostItemRepository.findById(recordId).map(record -> {
            record.setStatus("FOUND");
            lostItemRepository.save(record);
            return new ActionResultDto(true, "Item marked as found", null, null);
        }).orElseGet(() -> new ActionResultDto(false, "Item not found", null, null));
    }
}
