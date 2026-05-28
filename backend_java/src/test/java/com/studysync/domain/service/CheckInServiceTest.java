package com.studysync.domain.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.studysync.domain.dto.CheckInResultDto;
import com.studysync.domain.dto.CheckInVerifyRequestDto;
import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.exception.AccessDeniedException;
import com.studysync.domain.policy.GroupCheckInPolicy;
import com.studysync.domain.policy.QrCheckInPolicy;
import com.studysync.domain.policy.ReservationScoringPolicy;
import com.studysync.domain.repository.ReservationCheckInRepository;
import com.studysync.domain.repository.ReservationRecordRepository;
import com.studysync.security.SecurityUtils;
import java.lang.reflect.Field;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class CheckInServiceTest {

    private static final ZoneId CAMPUS = ZoneId.of("Europe/Istanbul");

    @Mock
    private ReservationRecordRepository reservationRepository;

    @Mock
    private ReservationCheckInRepository checkInRepository;

    @Mock
    private QrCheckInPolicy qrCheckInPolicy;

    @Mock
    private ResponsibilityScoreService responsibilityScoreService;

    @Mock
    private GroupInvitationService groupInvitationService;

    @Mock
    private GroupCheckInPolicy groupCheckInPolicy;

    private final ReservationScoringPolicy scoringPolicy = new ReservationScoringPolicy();

    private CheckInService service;
    private UserAccount organizer;
    private UserAccount invitee;
    private ReservationRecord reservation;

    @BeforeEach
    void setUp() throws Exception {
        service = new CheckInService(
                reservationRepository,
                checkInRepository,
                qrCheckInPolicy,
                responsibilityScoreService,
                scoringPolicy,
                groupInvitationService,
                groupCheckInPolicy,
                Clock.fixed(Instant.parse("2026-05-28T09:05:00Z"), CAMPUS));

        organizer = user(1L, "Bob");
        invitee = user(2L, "Alice");

        reservation = new ReservationRecord();
        reservation.setUser(organizer);
        reservation.setWorkspaceId("group-1");
        reservation.setDate("2026-05-28");
        reservation.setSlotId("slot-2");
        reservation.setStatus("ACTIVE");
        reservation.setQrPayload("G1");
        setEntityId(reservation, 10L);

        lenient().when(reservationRepository.findById(10L)).thenReturn(Optional.of(reservation));
        lenient().when(qrCheckInPolicy.checkInRejectionReason(any())).thenReturn(null);
        lenient().when(qrCheckInPolicy.qrMismatchReason(any(), any())).thenReturn(null);
        lenient().when(groupInvitationService.hasUnconfirmedInvites(10L)).thenReturn(false);
    }

    @Test
    void verify_nonParticipant_throwsAccessDenied() throws Exception {
        UserAccount stranger = user(99L, "Stranger");
        when(groupCheckInPolicy.isParticipant(reservation, 99L)).thenReturn(false);

        try (MockedStatic<SecurityUtils> security = mockStatic(SecurityUtils.class)) {
            security.when(SecurityUtils::requireCurrentUser).thenReturn(stranger);

            assertThrows(
                    AccessDeniedException.class,
                    () -> service.verify(new CheckInVerifyRequestDto("10", "G1")));
        }
    }

    @Test
    void verify_groupPartial_staysActiveAndReturnsProgress() throws Exception {
        when(groupCheckInPolicy.isParticipant(reservation, 1L)).thenReturn(true);
        when(groupCheckInPolicy.isGroupReservation(10L)).thenReturn(true);
        when(groupCheckInPolicy.requiredParticipantUserIds(reservation)).thenReturn(Set.of(1L, 2L));
        when(checkInRepository.existsByReservation_IdAndUser_Id(10L, 1L)).thenReturn(false);
        when(groupCheckInPolicy.checkedInCount(10L)).thenReturn(1);
        when(groupCheckInPolicy.allCheckedIn(10L, Set.of(1L, 2L))).thenReturn(false);

        try (MockedStatic<SecurityUtils> security = mockStatic(SecurityUtils.class)) {
            security.when(SecurityUtils::requireCurrentUser).thenReturn(organizer);

            CheckInResultDto result = service.verify(new CheckInVerifyRequestDto("10", "G1"));

            assertTrue(result.success());
            assertFalse(result.completed());
            assertEquals(1, result.checkedInCount());
            assertEquals(2, result.requiredCount());
            assertEquals("ACTIVE", reservation.getStatus());
            verify(responsibilityScoreService).applyDelta(1L, 5);
            verify(reservationRepository, never()).saveAndFlush(reservation);
        }
    }

    @Test
    void verify_groupAllCheckedIn_completesReservation() throws Exception {
        when(groupCheckInPolicy.isParticipant(reservation, 2L)).thenReturn(true);
        when(groupCheckInPolicy.isGroupReservation(10L)).thenReturn(true);
        when(groupCheckInPolicy.requiredParticipantUserIds(reservation)).thenReturn(Set.of(1L, 2L));
        when(checkInRepository.existsByReservation_IdAndUser_Id(10L, 2L)).thenReturn(false);
        when(groupCheckInPolicy.checkedInCount(10L)).thenReturn(2);
        when(groupCheckInPolicy.allCheckedIn(10L, Set.of(1L, 2L))).thenReturn(true);
        when(reservationRepository.countByUser_IdAndStatusIn(any(), any())).thenReturn(1L);

        try (MockedStatic<SecurityUtils> security = mockStatic(SecurityUtils.class)) {
            security.when(SecurityUtils::requireCurrentUser).thenReturn(invitee);

            CheckInResultDto result = service.verify(new CheckInVerifyRequestDto("10", "G1"));

            assertTrue(result.success());
            assertTrue(result.completed());
            assertEquals("COMPLETED", reservation.getStatus());
            verify(reservationRepository).saveAndFlush(reservation);
            verify(responsibilityScoreService).applyDelta(2L, 5);
        }
    }

    @Test
    void verify_alreadyCheckedIn_isIdempotent() throws Exception {
        when(groupCheckInPolicy.isParticipant(reservation, 1L)).thenReturn(true);
        when(groupCheckInPolicy.isGroupReservation(10L)).thenReturn(true);
        when(groupCheckInPolicy.requiredParticipantUserIds(reservation)).thenReturn(Set.of(1L, 2L));
        when(checkInRepository.existsByReservation_IdAndUser_Id(10L, 1L)).thenReturn(true);
        when(groupCheckInPolicy.checkedInCount(10L)).thenReturn(1);
        when(groupCheckInPolicy.allCheckedIn(10L, Set.of(1L, 2L))).thenReturn(false);

        try (MockedStatic<SecurityUtils> security = mockStatic(SecurityUtils.class)) {
            security.when(SecurityUtils::requireCurrentUser).thenReturn(organizer);

            CheckInResultDto result = service.verify(new CheckInVerifyRequestDto("10", "G1"));

            assertTrue(result.success());
            assertEquals("You already checked in.", result.message());
            verify(checkInRepository, never()).save(any());
            verify(responsibilityScoreService, never()).applyDelta(any(Long.class), any(Integer.class));
        }
    }

    @Test
    void verify_individual_completesImmediately() throws Exception {
        when(groupCheckInPolicy.isParticipant(reservation, 1L)).thenReturn(true);
        when(groupCheckInPolicy.isGroupReservation(10L)).thenReturn(false);
        when(groupCheckInPolicy.requiredParticipantUserIds(reservation)).thenReturn(Set.of(1L));
        when(checkInRepository.existsByReservation_IdAndUser_Id(10L, 1L)).thenReturn(false);
        when(groupCheckInPolicy.checkedInCount(10L)).thenReturn(1);
        when(groupCheckInPolicy.allCheckedIn(10L, Set.of(1L))).thenReturn(true);
        when(reservationRepository.countByUser_IdAndStatusIn(any(), any())).thenReturn(1L);

        try (MockedStatic<SecurityUtils> security = mockStatic(SecurityUtils.class)) {
            security.when(SecurityUtils::requireCurrentUser).thenReturn(organizer);

            CheckInResultDto result = service.verify(new CheckInVerifyRequestDto("10", "G1"));

            assertTrue(result.success());
            assertTrue(result.completed());
            assertEquals("COMPLETED", reservation.getStatus());
        }
    }

    @Test
    void verify_blockedUntilInvitesConfirmed() throws Exception {
        when(groupCheckInPolicy.isParticipant(reservation, 1L)).thenReturn(true);
        when(groupInvitationService.hasUnconfirmedInvites(10L)).thenReturn(true);

        try (MockedStatic<SecurityUtils> security = mockStatic(SecurityUtils.class)) {
            security.when(SecurityUtils::requireCurrentUser).thenReturn(organizer);

            CheckInResultDto result = service.verify(new CheckInVerifyRequestDto("10", "G1"));

            assertFalse(result.success());
            verify(checkInRepository, never()).save(any());
        }
    }

    private static UserAccount user(long id, String name) throws Exception {
        UserAccount u = new UserAccount();
        u.setName(name);
        setEntityId(u, id);
        return u;
    }

    private static void setEntityId(Object entity, Long id) throws Exception {
        Field field = entity.getClass().getDeclaredField("id");
        field.setAccessible(true);
        field.set(entity, id);
    }
}
