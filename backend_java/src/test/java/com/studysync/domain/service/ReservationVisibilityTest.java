package com.studysync.domain.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.studysync.domain.campus.WorkspaceQrRegistry;
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
import java.time.ZoneId;
import java.util.List;
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
class ReservationVisibilityTest {

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

    private ReservationService reservationService;
    private UserAccount invitee;

    @BeforeEach
    void setUp() throws Exception {
        reservationService = new ReservationService(
                cancellationScoringPolicy,
                new ReservationScoringPolicy(),
                reservationRepository,
                userAccountRepository,
                responsibilityScoreService,
                new ObjectMapper(),
                new WorkspaceQrRegistry(),
                groupInvitationService,
                Clock.fixed(Instant.parse("2026-05-28T10:00:00Z"), CAMPUS));

        invitee = new UserAccount();
        invitee.setNickname("Alice");
        setEntityId(invitee, 2L);
    }

    @Test
    void myReservations_includesAcceptedGroupBookingAsInvitee() throws Exception {
        UserAccount organizer = new UserAccount();
        organizer.setNickname("Bobby");
        setEntityId(organizer, 1L);

        ReservationRecord groupBooking = new ReservationRecord();
        groupBooking.setUser(organizer);
        groupBooking.setWorkspaceId("group-2");
        groupBooking.setDate("2026-05-28");
        groupBooking.setSlotId("slot-3");
        groupBooking.setSlotLabel("11.00-13.00");
        groupBooking.setStatus("ACTIVE");
        groupBooking.setCourseCode("MATH131");
        groupBooking.setParticipantsJson("[\"Alice\"]");
        setEntityId(groupBooking, 10L);

        when(reservationRepository.findVisibleToUser(2L)).thenReturn(List.of(groupBooking));
        when(groupInvitationService.summariesForReservations(List.of(10L)))
                .thenReturn(java.util.Map.of(10L, new com.studysync.domain.dto.GroupInviteSummaryDto(null, true)));
        when(groupInvitationService.checkInSummariesFor(any(), eq(2L)))
                .thenReturn(java.util.Map.of(10L, new com.studysync.domain.dto.GroupCheckInSummaryDto(false, 0, 2)));

        try (MockedStatic<SecurityContextHolder> security = mockStatic(SecurityContextHolder.class)) {
            SecurityContext ctx = mock(SecurityContext.class);
            Authentication auth = mock(Authentication.class);
            when(ctx.getAuthentication()).thenReturn(auth);
            when(auth.getPrincipal()).thenReturn(invitee);
            security.when(SecurityContextHolder::getContext).thenReturn(ctx);

            List<ReservationDetailDto> result = reservationService.myReservations();

            assertEquals(1, result.size());
            assertEquals("10", result.get(0).id());
            assertEquals("group-2", result.get(0).workspaceId());
            assertTrue(result.get(0).invitesConfirmed());
        }
    }

    private static void setEntityId(Object entity, Long id) throws Exception {
        Field field = entity.getClass().getDeclaredField("id");
        field.setAccessible(true);
        field.set(entity, id);
    }
}
