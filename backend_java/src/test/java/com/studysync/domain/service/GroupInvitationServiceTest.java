package com.studysync.domain.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.studysync.domain.dto.GroupInviteSummaryDto;
import com.studysync.domain.entity.GroupReservationInvite;
import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.policy.GroupCheckInPolicy;
import com.studysync.domain.policy.GroupInvitationPolicy;
import com.studysync.domain.repository.GroupReservationInviteRepository;
import com.studysync.domain.repository.ReservationCheckInRepository;
import com.studysync.domain.repository.ReservationRecordRepository;
import com.studysync.domain.repository.UserAccountRepository;
import java.lang.reflect.Field;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;

@ExtendWith(MockitoExtension.class)
class GroupInvitationServiceTest {

    private static final ZoneId CAMPUS = ZoneId.of("Europe/Istanbul");

    @Mock
    private GroupReservationInviteRepository inviteRepository;

    @Mock
    private ReservationRecordRepository reservationRepository;

    @Mock
    private ReservationCheckInRepository checkInRepository;

    @Mock
    private GroupCheckInPolicy groupCheckInPolicy;

    @Mock
    private UserAccountRepository userAccountRepository;

    @Mock
    private NotificationService notificationService;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private GroupInvitationService service;
    private UserAccount organizer;
    private UserAccount invitee;
    private ReservationRecord reservation;
    private Instant now;

    @BeforeEach
    void setUp() throws Exception {
        now = Instant.parse("2026-05-28T10:00:00Z");
        service = new GroupInvitationService(
                inviteRepository,
                reservationRepository,
                checkInRepository,
                groupCheckInPolicy,
                userAccountRepository,
                notificationService,
                objectMapper,
                Clock.fixed(now, CAMPUS));

        organizer = new UserAccount();
        organizer.setName("Bob");
        organizer.setNickname("Bobby");
        setEntityId(organizer, 1L);

        invitee = new UserAccount();
        invitee.setName("Alice");
        invitee.setNickname("Alice");
        setEntityId(invitee, 2L);

        reservation = new ReservationRecord();
        reservation.setUser(organizer);
        reservation.setWorkspaceId("group-1");
        reservation.setDate("2026-05-28");
        reservation.setSlotId("slot-3");
        reservation.setSlotLabel("11.00-13.00");
        reservation.setStatus("ACTIVE");
        reservation.setParticipantsJson("[\"Alice\"]");
        setEntityId(reservation, 10L);
    }

    @Test
    void createInvitesFor_savesPendingInviteAndNotification() {
        when(userAccountRepository.findByNicknameIgnoreCase("Alice")).thenReturn(Optional.of(invitee));
        when(inviteRepository.save(any(GroupReservationInvite.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        service.createInvitesFor(reservation, List.of("Alice"));

        ArgumentCaptor<GroupReservationInvite> captor = ArgumentCaptor.forClass(GroupReservationInvite.class);
        verify(inviteRepository).save(captor.capture());
        GroupReservationInvite saved = captor.getValue();
        assertEquals(GroupInvitationPolicy.STATUS_PENDING, saved.getStatus());
        assertEquals(GroupInvitationPolicy.expiresAt(now), saved.getExpiresAt());
        verify(notificationService)
                .emitGroupInvitation(eq(invitee), any(), eq("Bob"), eq("group-1"), eq("11.00-13.00"), eq("2026-05-28"));
    }

    @Test
    void accept_marksAcceptedWhenPending() throws Exception {
        GroupReservationInvite invite = pendingInvite(5L);
        runAs(invitee, () -> {
            when(inviteRepository.findById(5L)).thenReturn(Optional.of(invite));
            when(inviteRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

            service.accept("5");

            assertEquals(GroupInvitationPolicy.STATUS_ACCEPTED, invite.getStatus());
        });
    }

    @Test
    void accept_afterExpiry_throws() throws Exception {
        GroupReservationInvite invite = pendingInvite(5L);
        invite.setExpiresAt(now.minusSeconds(1));
        runAs(invitee, () -> {
            when(inviteRepository.findById(5L)).thenReturn(Optional.of(invite));
            IllegalStateException ex =
                    assertThrows(IllegalStateException.class, () -> service.accept("5"));
            assertTrue(ex.getMessage().contains("no longer available"));
        });
    }

    @Test
    void decline_cancelsReservation() throws Exception {
        GroupReservationInvite invite = pendingInvite(5L);
        runAs(invitee, () -> {
            when(inviteRepository.findById(5L)).thenReturn(Optional.of(invite));
            when(inviteRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
            when(reservationRepository.findById(10L)).thenReturn(Optional.of(reservation));
            when(inviteRepository.findByReservation_Id(10L)).thenReturn(List.of(invite));

            service.decline("5");

            assertEquals(GroupInvitationPolicy.STATUS_DECLINED, invite.getStatus());
            assertEquals("CANCELLED", reservation.getStatus());
            verify(reservationRepository).save(reservation);
        });
    }

    @Test
    void summaryForReservation_allAccepted_returnsConfirmed() throws Exception {
        GroupReservationInvite a = pendingInvite(1L);
        a.setStatus(GroupInvitationPolicy.STATUS_ACCEPTED);
        GroupReservationInvite b = pendingInvite(2L);
        b.setStatus(GroupInvitationPolicy.STATUS_ACCEPTED);
        when(inviteRepository.findByReservation_Id(10L)).thenReturn(List.of(a, b));

        GroupInviteSummaryDto summary = service.summaryForReservation(10L);

        assertTrue(summary.invitesConfirmed());
        assertEquals(GroupInvitationPolicy.expiresAt(now).toString(), summary.expiresAt());
    }

    @Test
    void expireStaleInvites_cancelsReservation() throws Exception {
        when(inviteRepository.findReservationIdsWithExpiredPendingInvites(
                        GroupInvitationPolicy.STATUS_PENDING, now))
                .thenReturn(List.of(10L));
        GroupReservationInvite invite = pendingInvite(1L);
        when(reservationRepository.findById(10L)).thenReturn(Optional.of(reservation));
        when(inviteRepository.findByReservation_Id(10L)).thenReturn(List.of(invite));

        int count = service.expireStaleInvites(now);

        assertEquals(1, count);
        assertEquals("CANCELLED", reservation.getStatus());
        verify(reservationRepository).save(reservation);
    }

    @Test
    void hasUnconfirmedInvites_falseWhenAllAccepted() throws Exception {
        GroupReservationInvite a = pendingInvite(1L);
        a.setStatus(GroupInvitationPolicy.STATUS_ACCEPTED);
        when(inviteRepository.findByReservation_Id(10L)).thenReturn(List.of(a));

        assertFalse(service.hasUnconfirmedInvites(10L));
    }

    @Test
    void hasUnconfirmedInvites_trueWhenPending() throws Exception {
        when(inviteRepository.findByReservation_Id(10L)).thenReturn(List.of(pendingInvite(1L)));

        assertTrue(service.hasUnconfirmedInvites(10L));
    }

    private GroupReservationInvite pendingInvite(long id) throws Exception {
        GroupReservationInvite invite = new GroupReservationInvite();
        invite.setReservation(reservation);
        invite.setInvitee(invitee);
        invite.setStatus(GroupInvitationPolicy.STATUS_PENDING);
        invite.setCreatedAt(now);
        invite.setExpiresAt(GroupInvitationPolicy.expiresAt(now));
        setEntityId(invite, id);
        return invite;
    }

    private void runAs(UserAccount user, Runnable action) {
        try (MockedStatic<SecurityContextHolder> security = mockStatic(SecurityContextHolder.class)) {
            SecurityContext ctx = mock(SecurityContext.class);
            Authentication auth = mock(Authentication.class);
            when(ctx.getAuthentication()).thenReturn(auth);
            when(auth.getPrincipal()).thenReturn(user);
            security.when(SecurityContextHolder::getContext).thenReturn(ctx);
            action.run();
        }
    }

    private static void setEntityId(Object entity, Long id) throws Exception {
        Field field = entity.getClass().getDeclaredField("id");
        field.setAccessible(true);
        field.set(entity, id);
    }
}
