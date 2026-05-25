package com.studysync.domain.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.studysync.domain.dto.CreateBuddyReportRequestDto;
import com.studysync.domain.entity.BuddyReportRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.policy.BuddyReportPolicy;
import com.studysync.domain.repository.BuddyReportRecordRepository;
import com.studysync.domain.repository.UserAccountRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
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
class BuddyReportServiceTest {

    private static final Instant NOW = Instant.parse("2026-05-25T10:00:00Z");

    @Mock
    private BuddyReportRecordRepository buddyReportRepository;

    @Mock
    private UserAccountRepository userAccountRepository;

    private BuddyReportService service;

    @BeforeEach
    void setUp() {
        Clock clock = Clock.fixed(NOW, ZoneId.of("UTC"));
        service = new BuddyReportService(buddyReportRepository, userAccountRepository, clock);
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void submitReport_savesReportAndReturnsDto() {
        UserAccount reporter = user(9L, "Alice");
        UserAccount reported = user(12L, "Bob");
        setPrincipalId(reporter, 9L);

        when(userAccountRepository.findById(9L)).thenReturn(Optional.of(reporter));
        when(userAccountRepository.findById(12L)).thenReturn(Optional.of(reported));

        BuddyReportRecord persisted = new BuddyReportRecord();
        setEntityId(persisted, 1L);
        persisted.setReportedUser(reported);
        persisted.setReportedBy(reporter);
        persisted.setReason("Harassment");
        persisted.setComment("Details");
        persisted.setCreatedAt(NOW);
        persisted.setStatus(BuddyReportPolicy.STATUS_OPEN);

        when(buddyReportRepository.saveAndFlush(org.mockito.ArgumentMatchers.any())).thenReturn(persisted);
        when(buddyReportRepository.findByIdWithUsers(1L)).thenReturn(Optional.of(persisted));

        var body = new CreateBuddyReportRequestDto("12", "Harassment", "Details");
        var result = service.submitReport(body, null);

        assertTrue(result.success());
        assertNotNull(result.report());
        assertEquals("1", result.report().id());
        assertEquals("12", result.report().reportedUserId());
        assertEquals("Bob", result.report().reportedName());
        assertEquals("Alice", result.report().reporterLabel());
        assertEquals(BuddyReportPolicy.STATUS_OPEN, result.report().status());

        ArgumentCaptor<BuddyReportRecord> captor = ArgumentCaptor.forClass(BuddyReportRecord.class);
        verify(buddyReportRepository).saveAndFlush(captor.capture());
        assertEquals(reported, captor.getValue().getReportedUser());
        assertEquals(reporter, captor.getValue().getReportedBy());
        assertEquals("Harassment", captor.getValue().getReason());
    }

    @Test
    void submitReport_rejectsSelfReport() {
        UserAccount reporter = user(9L, "Alice");
        setPrincipalId(reporter, 9L);
        when(userAccountRepository.findById(9L)).thenReturn(Optional.of(reporter));

        var body = new CreateBuddyReportRequestDto("9", "Spam", null);
        var result = service.submitReport(body, null);

        assertFalse(result.success());
        assertEquals("You cannot report yourself.", result.message());
    }

    @Test
    void submitReport_rejectsUnknownReportedUser() {
        UserAccount reporter = user(9L, "Alice");
        setPrincipalId(reporter, 9L);
        when(userAccountRepository.findById(9L)).thenReturn(Optional.of(reporter));
        when(userAccountRepository.findById(99L)).thenReturn(Optional.empty());

        var body = new CreateBuddyReportRequestDto("99", "No-show", null);
        var result = service.submitReport(body, null);

        assertFalse(result.success());
        assertTrue(result.message().contains("Reported user not found"));
    }

    @Test
    void listOpenReports_mapsEntitiesToDtos() {
        UserAccount reported = user(12L, "Bob");
        UserAccount reporter = user(9L, "Alice");
        BuddyReportRecord record = new BuddyReportRecord();
        setEntityId(record, 5L);
        record.setReportedUser(reported);
        record.setReportedBy(reporter);
        record.setReason("No-show");
        record.setCreatedAt(NOW);
        record.setStatus(BuddyReportPolicy.STATUS_OPEN);

        when(buddyReportRepository.findByStatusWithUsersOrderByCreatedAtDesc(BuddyReportPolicy.STATUS_OPEN))
                .thenReturn(List.of(record));

        var items = service.listOpenReports();

        assertEquals(1, items.size());
        assertEquals("5", items.get(0).id());
        assertEquals("12", items.get(0).reportedUserId());
        assertEquals("Bob", items.get(0).reportedName());
    }

    private static UserAccount user(long id, String name) {
        UserAccount user = new UserAccount();
        setEntityId(user, id);
        user.setName(name);
        return user;
    }

    private void setPrincipalId(UserAccount principal, long id) {
        setEntityId(principal, id);
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(principal, null, List.of()));
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
}
