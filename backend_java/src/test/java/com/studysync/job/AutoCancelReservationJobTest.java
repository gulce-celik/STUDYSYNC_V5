package com.studysync.job;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.policy.GroupCheckInPolicy;
import com.studysync.domain.policy.ReservationScoringPolicy;
import com.studysync.domain.repository.ReservationRecordRepository;
import com.studysync.domain.service.ResponsibilityScoreService;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AutoCancelReservationJobTest {

    private static final ZoneId CAMPUS = ZoneId.of("Europe/Istanbul");

    @Mock
    private ReservationRecordRepository reservationRepository;

    @Mock
    private ResponsibilityScoreService responsibilityScoreService;

    @Mock
    private GroupCheckInPolicy groupCheckInPolicy;

    private final ReservationScoringPolicy scoringPolicy = new ReservationScoringPolicy();

    private AutoCancelReservationJob job;

    @BeforeEach
    void setUp() {
        job = new AutoCancelReservationJob(
                reservationRepository,
                responsibilityScoreService,
                scoringPolicy,
                groupCheckInPolicy,
                fixedClock("2026-05-22T10:00:00"));
        lenient().when(groupCheckInPolicy.isGroupReservation(any())).thenReturn(false);
    }

    @Test
    void cancelNoShows_queriesActiveReservationsOnOrBeforeToday() {
        when(reservationRepository.findByDateLessThanEqualAndStatusIn(eq("2026-05-22"), any()))
                .thenReturn(List.of());

        job.cancelNoShows();

        verify(reservationRepository)
                .findByDateLessThanEqualAndStatusIn(eq("2026-05-22"), eq(List.of("ACTIVE", "PENDING")));
    }

    @Test
    void processRecordIfNoShow_marksPastReservationAfterGraceWindow() {
        ReservationRecord record = activeReservation("2026-05-21", "slot-2");

        job.processRecordIfNoShow(record, LocalDateTime.parse("2026-05-22T10:00:00"));

        assertEquals("NO_SHOW", record.getStatus());
        assertEquals(ReservationScoringPolicy.NO_SHOW_SCORE, record.getScore());
        verify(reservationRepository).saveAndFlush(record);
        verify(responsibilityScoreService).applyDelta(7L, ReservationScoringPolicy.NO_SHOW_SCORE);
    }

    @Test
    void processRecordIfNoShow_leavesTodayReservationBeforeDeadline() {
        ReservationRecord record = activeReservation("2026-05-22", "slot-2");

        job.processRecordIfNoShow(record, LocalDateTime.parse("2026-05-22T09:10:00"));

        assertEquals("ACTIVE", record.getStatus());
        assertEquals(0, record.getScore());
        verify(reservationRepository, never()).saveAndFlush(any());
        verify(responsibilityScoreService, never()).applyDelta(any(Long.class), any(Integer.class));
    }

    @Test
    void processRecordIfNoShow_marksTodayReservationAfterDeadline() {
        ReservationRecord record = activeReservation("2026-05-22", "slot-2");

        job.processRecordIfNoShow(record, LocalDateTime.parse("2026-05-22T09:16:00"));

        assertEquals("NO_SHOW", record.getStatus());
        assertEquals(ReservationScoringPolicy.NO_SHOW_SCORE, record.getScore());
        verify(reservationRepository).saveAndFlush(record);
        verify(responsibilityScoreService).applyDelta(7L, ReservationScoringPolicy.NO_SHOW_SCORE);
    }

    @Test
    void processRecordIfNoShow_doesNotMarkAtExactDeadline() {
        ReservationRecord record = activeReservation("2026-05-22", "slot-2");

        job.processRecordIfNoShow(record, LocalDateTime.parse("2026-05-22T09:15:00"));

        assertEquals("ACTIVE", record.getStatus());
        verify(reservationRepository, never()).saveAndFlush(any());
    }

    @Test
    void cancelNoShows_processesStaleActiveReservationFromRepository() {
        ReservationRecord stale = activeReservation("2026-05-20", "slot-2");
        when(reservationRepository.findByDateLessThanEqualAndStatusIn(eq("2026-05-22"), any()))
                .thenReturn(List.of(stale));

        job.cancelNoShows();

        assertEquals("NO_SHOW", stale.getStatus());
        verify(responsibilityScoreService).applyDelta(7L, ReservationScoringPolicy.NO_SHOW_SCORE);
    }

    @Test
    void processRecordIfNoShow_groupIncomplete_penalizesAllParticipants() throws Exception {
        ReservationRecord record = activeReservation("2026-05-22", "slot-2");
        setEntityId(record, 5L);

        when(groupCheckInPolicy.isGroupReservation(5L)).thenReturn(true);
        when(groupCheckInPolicy.requiredParticipantUserIds(record)).thenReturn(Set.of(7L, 8L));
        when(groupCheckInPolicy.allCheckedIn(5L, Set.of(7L, 8L))).thenReturn(false);

        job.processRecordIfNoShow(record, LocalDateTime.parse("2026-05-22T09:16:00"));

        assertEquals("NO_SHOW", record.getStatus());
        verify(responsibilityScoreService).applyDelta(7L, ReservationScoringPolicy.NO_SHOW_SCORE);
        verify(responsibilityScoreService).applyDelta(8L, ReservationScoringPolicy.NO_SHOW_SCORE);
    }

    @Test
    void processRecordIfNoShow_groupAllCheckedIn_skipsNoShow() throws Exception {
        ReservationRecord record = activeReservation("2026-05-22", "slot-2");
        setEntityId(record, 5L);

        when(groupCheckInPolicy.isGroupReservation(5L)).thenReturn(true);
        when(groupCheckInPolicy.requiredParticipantUserIds(record)).thenReturn(Set.of(7L, 8L));
        when(groupCheckInPolicy.allCheckedIn(5L, Set.of(7L, 8L))).thenReturn(true);

        job.processRecordIfNoShow(record, LocalDateTime.parse("2026-05-22T09:16:00"));

        assertEquals("ACTIVE", record.getStatus());
        verify(reservationRepository, never()).saveAndFlush(any());
        verify(responsibilityScoreService, never()).applyDelta(any(Long.class), any(Integer.class));
    }

    @Test
    void processRecordIfNoShow_skipsInvalidDate() {
        ReservationRecord record = activeReservation("not-a-date", "slot-2");

        job.processRecordIfNoShow(record, LocalDateTime.parse("2026-05-22T10:00:00"));

        assertEquals("ACTIVE", record.getStatus());
        verify(reservationRepository, never()).saveAndFlush(any());
    }

    private static ReservationRecord activeReservation(String date, String slotId) {
        ReservationRecord record = new ReservationRecord();
        record.setDate(date);
        record.setSlotId(slotId);
        record.setStatus("ACTIVE");
        record.setScore(0);
        record.setWorkspaceId("ws-1");
        UserAccount user = mock(UserAccount.class);
        lenient().when(user.getId()).thenReturn(7L);
        record.setUser(user);
        return record;
    }

    private static Clock fixedClock(String campusLocalDateTime) {
        Instant instant = LocalDateTime.parse(campusLocalDateTime).atZone(CAMPUS).toInstant();
        return Clock.fixed(instant, CAMPUS);
    }

    private static void setEntityId(Object entity, Long id) throws Exception {
        java.lang.reflect.Field field = entity.getClass().getDeclaredField("id");
        field.setAccessible(true);
        field.set(entity, id);
    }
}
