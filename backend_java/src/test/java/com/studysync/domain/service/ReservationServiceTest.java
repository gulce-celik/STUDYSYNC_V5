package com.studysync.domain.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.studysync.domain.campus.WorkspaceQrRegistry;
import com.studysync.domain.dto.CreateReservationRequestDto;
import com.studysync.domain.dto.GroupInviteSummaryDto;
import com.studysync.domain.dto.ReservationDetailDto;
import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.policy.CancellationScoringPolicy;
import com.studysync.domain.policy.ReservationScoringPolicy;
import com.studysync.domain.repository.ReservationRecordRepository;
import com.studysync.domain.repository.UserAccountRepository;
import java.lang.reflect.Field;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;

@ExtendWith(MockitoExtension.class)
class ReservationServiceTest {

    private static final ZoneId CAMPUS = ZoneId.of("Europe/Istanbul");

    @Mock
    private CancellationScoringPolicy cancellationScoringPolicy;

    @Mock
    private ReservationRecordRepository reservationRepository;

    @Mock
    private UserAccountRepository userAccountRepository;

    @Mock
    private ResponsibilityScoreService responsibilityScoreService;

    @Mock
    private GroupInvitationService groupInvitationService;

    private final ReservationScoringPolicy reservationScoringPolicy = new ReservationScoringPolicy();
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final WorkspaceQrRegistry workspaceQrRegistry = new WorkspaceQrRegistry();

    private ReservationService service;
    private UserAccount organizer;

    @BeforeEach
    void setUp() {
        service = new ReservationService(
                cancellationScoringPolicy,
                reservationScoringPolicy,
                reservationRepository,
                userAccountRepository,
                responsibilityScoreService,
                objectMapper,
                workspaceQrRegistry,
                groupInvitationService,
                fixedClock("2026-05-28T08:00:00"));

        organizer = new UserAccount();
        organizer.setNickname("Organizer");

        when(reservationRepository.existsByWorkspaceIdAndDateAndSlotIdAndStatusIn(any(), any(), any(), any()))
                .thenReturn(false);
        when(reservationRepository.countByUser_IdAndDateAndStatusIn(any(), any(), any()))
                .thenReturn(0);
    }

    @Test
    void createReservation_groupWithValidParticipants_saves() {
        when(userAccountRepository.findByNicknameIgnoreCase("Alice")).thenReturn(Optional.of(new UserAccount()));
        when(reservationRepository.save(any(ReservationRecord.class))).thenAnswer(inv -> {
            ReservationRecord r = inv.getArgument(0);
            setEntityId(r, 99L);
            return r;
        });
        when(groupInvitationService.summaryForReservation(99L))
                .thenReturn(new GroupInviteSummaryDto("2026-05-28T08:15:00Z", false));

        runWithPrincipal(() -> {
            ReservationDetailDto result = service.createReservation(groupRequest(List.of("Alice")));
            assertNotNull(result);
            assertFalse(result.invitesConfirmed());
        });

        verify(reservationRepository).save(any(ReservationRecord.class));
        verify(groupInvitationService).createInvitesFor(any(ReservationRecord.class), eq(List.of("Alice")));
    }

    @Test
    void createReservation_unknownParticipant_throws() {
        when(userAccountRepository.findByNicknameIgnoreCase("Nobody")).thenReturn(Optional.empty());

        runWithPrincipal(() -> {
            IllegalStateException ex = assertThrows(
                    IllegalStateException.class,
                    () -> service.createReservation(groupRequest(List.of("Nobody"))));
            assertEquals("Participant not found: Nobody", ex.getMessage());
        });

        verify(reservationRepository, never()).save(any());
    }

    @Test
    void createReservation_selfInvite_throws() {
        runWithPrincipal(() -> {
            IllegalStateException ex = assertThrows(
                    IllegalStateException.class,
                    () -> service.createReservation(groupRequest(List.of("Organizer"))));
            assertEquals("You cannot add your own nickname as a participant.", ex.getMessage());
        });

        verify(reservationRepository, never()).save(any());
        verify(userAccountRepository, never()).findByNicknameIgnoreCase(any());
    }

    private CreateReservationRequestDto groupRequest(List<String> nicknames) {
        return new CreateReservationRequestDto(
                "2026-05-28",
                "slot-3",
                "group-1",
                "CSE101",
                "GROUP",
                false,
                nicknames);
    }

    private void runWithPrincipal(Runnable action) {
        try (MockedStatic<SecurityContextHolder> security = mockStatic(SecurityContextHolder.class)) {
            SecurityContext ctx = mock(SecurityContext.class);
            Authentication auth = mock(Authentication.class);
            when(ctx.getAuthentication()).thenReturn(auth);
            when(auth.getPrincipal()).thenReturn(organizer);
            security.when(SecurityContextHolder::getContext).thenReturn(ctx);
            action.run();
        }
    }

    private static Clock fixedClock(String isoLocal) {
        Instant instant = LocalDateTime.parse(isoLocal).atZone(CAMPUS).toInstant();
        return Clock.fixed(instant, CAMPUS);
    }

    private static void setEntityId(Object entity, Long id) {
        try {
            Field field = entity.getClass().getDeclaredField("id");
            field.setAccessible(true);
            field.set(entity, id);
        } catch (ReflectiveOperationException e) {
            throw new RuntimeException(e);
        }
    }
}
