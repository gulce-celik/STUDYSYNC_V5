package com.studysync.domain.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.studysync.domain.entity.LostItemRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.policy.LostFoundPolicy;
import com.studysync.domain.repository.LostItemRecordRepository;
import com.studysync.domain.repository.UserAccountRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

@ExtendWith(MockitoExtension.class)
class LostFoundServiceTest {

    private static final Instant NOW = Instant.parse("2026-05-23T12:00:00Z");

    @Mock
    private LostItemRecordRepository lostItemRepository;

    @Mock
    private UserAccountRepository userAccountRepository;

    private LostFoundService service;

    @BeforeEach
    void setUp() {
        Clock clock = Clock.fixed(NOW, ZoneId.of("UTC"));
        service = new LostFoundService(lostItemRepository, userAccountRepository, clock);
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void getLostItems_returnsOnlyActiveOpenItems() {
        LostItemRecord active = reportedItem("desk-active", NOW.minus(2, ChronoUnit.HOURS));
        LostItemRecord stale = reportedItem("desk-stale", NOW.minus(25, ChronoUnit.HOURS));

        when(lostItemRepository.findByStatusInOrderByReportedAtDesc(LostFoundPolicy.OPEN_STATUSES))
                .thenReturn(List.of(active, stale));

        var items = service.getLostItems();

        assertEquals(1, items.size());
        assertEquals("desk-active", items.get(0).workspaceId());
    }

    @Test
    void reportLostItem_setsManagedReporterAndReturnsItem() {
        UserAccount principal = new UserAccount();
        principal.setEmail("alice@example.com");
        setPrincipalId(principal, 9L);

        UserAccount managed = new UserAccount();
        setEntityId(managed, 9L);
        when(userAccountRepository.getReferenceById(9L)).thenReturn(managed);

        LostItemRecord persisted = reportedItem("desk-3", NOW);
        setRecordId(persisted, 42L);
        persisted.setReportedBy(managed);
        when(lostItemRepository.saveAndFlush(org.mockito.ArgumentMatchers.any())).thenReturn(persisted);

        var result = service.reportLostItem("desk-3", "Blue bottle");

        assertTrue(result.success());
        assertNotNull(result.item());
        assertEquals("42", result.item().id());
        assertEquals("9", result.item().reportedByUserId());

        ArgumentCaptor<LostItemRecord> captor = ArgumentCaptor.forClass(LostItemRecord.class);
        verify(lostItemRepository).saveAndFlush(captor.capture());
        assertEquals(managed, captor.getValue().getReportedBy());
    }

    @Test
    void markAsFound_rejectsNonNumericId() {
        var result = service.markAsFound("lost-1");

        assertFalse(result.success());
        assertTrue(result.message().contains("Invalid item id"));
    }

    @Test
    void markAsFound_rejectsExpiredReport() {
        LostItemRecord record = reportedItem("desk-5", NOW.minus(25, ChronoUnit.HOURS));
        setRecordId(record, 5L);
        when(lostItemRepository.findById(5L)).thenReturn(Optional.of(record));

        var result = service.markAsFound("5");

        assertFalse(result.success());
        assertEquals("Item report has expired", result.message());
    }

    @Test
    void markAsFound_updatesActiveReport() {
        LostItemRecord record = reportedItem("desk-6", NOW.minus(1, ChronoUnit.HOURS));
        setRecordId(record, 6L);
        when(lostItemRepository.findById(6L)).thenReturn(Optional.of(record));

        var result = service.markAsFound("6");

        assertTrue(result.success());
        assertEquals(LostFoundPolicy.STATUS_FOUND, record.getStatus());
        verify(lostItemRepository).saveAndFlush(record);
    }

    @Test
    void expireStaleReports_marksPastTtlAsExpired() {
        LostItemRecord active = reportedItem("desk-10", NOW.minus(1, ChronoUnit.HOURS));
        LostItemRecord stale = reportedItem("desk-11", NOW.minus(25, ChronoUnit.HOURS));
        when(lostItemRepository.findByStatusInOrderByReportedAtDesc(LostFoundPolicy.OPEN_STATUSES))
                .thenReturn(List.of(active, stale));

        int count = service.expireStaleReports(NOW);

        assertEquals(1, count);
        assertEquals(LostFoundPolicy.STATUS_EXPIRED, stale.getStatus());
        verify(lostItemRepository).save(stale);
    }

    private void setPrincipalId(UserAccount principal, long id) {
        try {
            var field = UserAccount.class.getDeclaredField("id");
            field.setAccessible(true);
            field.set(principal, id);
        } catch (ReflectiveOperationException e) {
            throw new RuntimeException(e);
        }
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(principal, null, List.of()));
    }

    private static void setRecordId(LostItemRecord record, long id) {
        setEntityId(record, id);
    }

    private static void setEntityId(Object entity, long id) {
        try {
            var field = entity.getClass().getDeclaredField("id");
            field.setAccessible(true);
            field.set(entity, id);
        } catch (ReflectiveOperationException e) {
            throw new RuntimeException(e);
        }
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
