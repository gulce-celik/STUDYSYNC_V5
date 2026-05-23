package com.studysync.domain.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.studysync.domain.entity.LostItemRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.policy.LostFoundPolicy;
import com.studysync.domain.repository.LostItemRecordRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class LostFoundServiceTest {

    private static final Instant NOW = Instant.parse("2026-05-23T12:00:00Z");

    @Mock
    private LostItemRecordRepository lostItemRepository;

    private LostFoundService service;

    @BeforeEach
    void setUp() {
        Clock clock = Clock.fixed(NOW, ZoneId.of("UTC"));
        service = new LostFoundService(lostItemRepository, clock);
    }

    @Test
    void getLostItems_returnsOnlyActiveReportedItems() {
        LostItemRecord active = reportedItem("desk-active", NOW.minus(2, ChronoUnit.HOURS));
        LostItemRecord stale = reportedItem("desk-stale", NOW.minus(25, ChronoUnit.HOURS));

        when(lostItemRepository.findByStatusOrderByReportedAtDesc(LostFoundPolicy.STATUS_REPORTED))
                .thenReturn(List.of(active, stale));

        var items = service.getLostItems();

        assertEquals(1, items.size());
        assertEquals("desk-active", items.get(0).workspaceId());
        assertEquals(
                LostFoundPolicy.expiresAt(active.getReportedAt()).toString(),
                items.get(0).expiresAt());
    }

    @Test
    void reportLostItem_setsReporterAndReportedStatus() {
        UserAccount user = new UserAccount();
        user.setEmail("alice@example.com");

        service.reportLostItem("desk-3", "Blue bottle", user);

        ArgumentCaptor<LostItemRecord> captor = ArgumentCaptor.forClass(LostItemRecord.class);
        verify(lostItemRepository).save(captor.capture());
        LostItemRecord saved = captor.getValue();
        assertEquals("desk-3", saved.getWorkspaceId());
        assertEquals(user, saved.getReportedBy());
        assertEquals(LostFoundPolicy.STATUS_REPORTED, saved.getStatus());
        assertEquals(NOW, saved.getReportedAt());
    }

    @Test
    void markAsFound_rejectsExpiredReport() {
        LostItemRecord record = reportedItem("desk-5", NOW.minus(25, ChronoUnit.HOURS));
        when(lostItemRepository.findById(5L)).thenReturn(Optional.of(record));

        var result = service.markAsFound("5");

        assertFalse(result.success());
        assertEquals("Item report has expired", result.message());
    }

    @Test
    void markAsFound_updatesActiveReport() {
        LostItemRecord record = reportedItem("desk-6", NOW.minus(1, ChronoUnit.HOURS));
        when(lostItemRepository.findById(6L)).thenReturn(Optional.of(record));

        var result = service.markAsFound("6");

        assertTrue(result.success());
        assertEquals(LostFoundPolicy.STATUS_FOUND, record.getStatus());
        verify(lostItemRepository).save(record);
    }

    @Test
    void expireStaleReports_marksPastTtlAsExpired() {
        LostItemRecord active = reportedItem("desk-10", NOW.minus(1, ChronoUnit.HOURS));
        LostItemRecord stale = reportedItem("desk-11", NOW.minus(25, ChronoUnit.HOURS));
        when(lostItemRepository.findByStatusOrderByReportedAtDesc(LostFoundPolicy.STATUS_REPORTED))
                .thenReturn(List.of(active, stale));

        int count = service.expireStaleReports(NOW);

        assertEquals(1, count);
        assertEquals(LostFoundPolicy.STATUS_EXPIRED, stale.getStatus());
        assertEquals(LostFoundPolicy.STATUS_REPORTED, active.getStatus());
        verify(lostItemRepository).save(stale);
    }

    private static LostItemRecord reportedItem(String workspaceId, Instant reportedAt) {
        LostItemRecord record = new LostItemRecord();
        record.setWorkspaceId(workspaceId);
        record.setDescription("item");
        record.setReportedAt(reportedAt);
        record.setCategory("GENERAL");
        record.setStatus(LostFoundPolicy.STATUS_REPORTED);
        return record;
    }
}
