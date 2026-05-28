package com.studysync.domain.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.studysync.domain.dto.GroupInvitationDto;
import com.studysync.domain.dto.GroupInviteSummaryDto;
import com.studysync.domain.entity.GroupReservationInvite;
import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.exception.AccessDeniedException;
import com.studysync.domain.exception.ResourceNotFoundException;
import com.studysync.domain.policy.GroupInvitationPolicy;
import com.studysync.domain.repository.GroupReservationInviteRepository;
import com.studysync.domain.repository.ReservationRecordRepository;
import com.studysync.domain.repository.UserAccountRepository;
import com.studysync.security.SecurityUtils;
import java.time.Clock;
import java.time.Instant;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GroupInvitationService {

    private final GroupReservationInviteRepository inviteRepository;
    private final ReservationRecordRepository reservationRepository;
    private final UserAccountRepository userAccountRepository;
    private final NotificationService notificationService;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    public GroupInvitationService(
            GroupReservationInviteRepository inviteRepository,
            ReservationRecordRepository reservationRepository,
            UserAccountRepository userAccountRepository,
            NotificationService notificationService,
            ObjectMapper objectMapper,
            Clock clock) {
        this.inviteRepository = inviteRepository;
        this.reservationRepository = reservationRepository;
        this.userAccountRepository = userAccountRepository;
        this.notificationService = notificationService;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    @Transactional
    public void createInvitesFor(ReservationRecord reservation, List<String> nicknames) {
        if (nicknames == null || nicknames.isEmpty()) {
            return;
        }
        Instant createdAt = clock.instant();
        Instant expiresAt = GroupInvitationPolicy.expiresAt(createdAt);
        UserAccount organizer = reservation.getUser();
        String organizerName = displayName(organizer);

        for (String raw : nicknames) {
            if (raw == null || raw.isBlank()) {
                continue;
            }
            String nickname = raw.trim();
            UserAccount invitee = userAccountRepository
                    .findByNicknameIgnoreCase(nickname)
                    .orElseThrow(() -> new IllegalStateException("Participant not found: " + nickname));

            GroupReservationInvite invite = new GroupReservationInvite();
            invite.setReservation(reservation);
            invite.setInvitee(invitee);
            invite.setStatus(GroupInvitationPolicy.STATUS_PENDING);
            invite.setCreatedAt(createdAt);
            invite.setExpiresAt(expiresAt);
            GroupReservationInvite saved = inviteRepository.save(invite);

            notificationService.emitGroupInvitation(
                    invitee,
                    String.valueOf(saved.getId()),
                    organizerName,
                    reservation.getWorkspaceId(),
                    reservation.getSlotLabel() != null ? reservation.getSlotLabel() : reservation.getSlotId(),
                    reservation.getDate());
        }
    }

    @Transactional(readOnly = true)
    public List<GroupInvitationDto> listPending() {
        UserAccount current = SecurityUtils.requireCurrentUser();
        Instant now = clock.instant();
        return inviteRepository.findByInvitee_IdAndStatus(current.getId(), GroupInvitationPolicy.STATUS_PENDING).stream()
                .filter(i -> GroupInvitationPolicy.isPending(i, now))
                .filter(i -> "ACTIVE".equals(i.getReservation().getStatus()))
                .map(this::toInvitationDto)
                .toList();
    }

    @Transactional
    public void accept(String inviteId) {
        GroupReservationInvite invite = loadInviteForCurrentUser(inviteId);
        Instant now = clock.instant();
        if (!GroupInvitationPolicy.isPending(invite, now)) {
            throw new IllegalStateException("This invitation is no longer available.");
        }
        ReservationRecord reservation = invite.getReservation();
        if (!"ACTIVE".equals(reservation.getStatus())) {
            throw new IllegalStateException("This reservation is no longer active.");
        }
        invite.setStatus(GroupInvitationPolicy.STATUS_ACCEPTED);
        inviteRepository.save(invite);
    }

    @Transactional
    public void decline(String inviteId) {
        GroupReservationInvite invite = loadInviteForCurrentUser(inviteId);
        Instant now = clock.instant();
        if (!GroupInvitationPolicy.isPending(invite, now)
                && !GroupInvitationPolicy.STATUS_PENDING.equals(invite.getStatus())) {
            throw new IllegalStateException("This invitation is no longer available.");
        }
        invite.setStatus(GroupInvitationPolicy.STATUS_DECLINED);
        inviteRepository.save(invite);
        cancelReservationForInviteFailure(invite.getReservation().getId());
    }

    @Transactional
    public int expireStaleInvites(Instant now) {
        List<Long> reservationIds = inviteRepository.findReservationIdsWithExpiredPendingInvites(
                GroupInvitationPolicy.STATUS_PENDING, now);
        int cancelled = 0;
        for (Long reservationId : reservationIds) {
            if (cancelReservationForInviteFailure(reservationId)) {
                cancelled++;
            }
        }
        return cancelled;
    }

    @Transactional(readOnly = true)
    public GroupInviteSummaryDto summaryForReservation(Long reservationId) {
        List<GroupReservationInvite> invites = inviteRepository.findByReservation_Id(reservationId);
        if (invites.isEmpty()) {
            return GroupInviteSummaryDto.none();
        }
        return new GroupInviteSummaryDto(
                GroupInvitationPolicy.expiresAtIso(invites),
                GroupInvitationPolicy.invitesConfirmed(invites));
    }

    @Transactional(readOnly = true)
    public Map<Long, GroupInviteSummaryDto> summariesForReservations(List<Long> reservationIds) {
        if (reservationIds == null || reservationIds.isEmpty()) {
            return Map.of();
        }
        List<GroupReservationInvite> all =
                inviteRepository.findByReservation_IdIn(reservationIds);
        Map<Long, List<GroupReservationInvite>> byReservation =
                all.stream().collect(Collectors.groupingBy(i -> i.getReservation().getId()));
        Map<Long, GroupInviteSummaryDto> result = new HashMap<>();
        for (Long id : reservationIds) {
            List<GroupReservationInvite> invites = byReservation.getOrDefault(id, List.of());
            if (invites.isEmpty()) {
                result.put(id, GroupInviteSummaryDto.none());
            } else {
                result.put(
                        id,
                        new GroupInviteSummaryDto(
                                GroupInvitationPolicy.expiresAtIso(invites),
                                GroupInvitationPolicy.invitesConfirmed(invites)));
            }
        }
        return result;
    }

    @Transactional(readOnly = true)
    public boolean hasUnconfirmedInvites(Long reservationId) {
        List<GroupReservationInvite> invites = inviteRepository.findByReservation_Id(reservationId);
        if (invites.isEmpty()) {
            return false;
        }
        return !GroupInvitationPolicy.invitesConfirmed(invites);
    }

    private boolean cancelReservationForInviteFailure(Long reservationId) {
        ReservationRecord reservation = reservationRepository
                .findById(reservationId)
                .orElse(null);
        if (reservation == null || !"ACTIVE".equals(reservation.getStatus())) {
            return false;
        }
        reservation.setStatus("CANCELLED");
        reservation.setScore(0);
        reservationRepository.save(reservation);

        List<GroupReservationInvite> invites = inviteRepository.findByReservation_Id(reservationId);
        for (GroupReservationInvite invite : invites) {
            if (GroupInvitationPolicy.STATUS_PENDING.equals(invite.getStatus())) {
                invite.setStatus(GroupInvitationPolicy.STATUS_EXPIRED);
            }
        }
        inviteRepository.saveAll(invites);
        return true;
    }

    private GroupReservationInvite loadInviteForCurrentUser(String inviteId) {
        UserAccount current = SecurityUtils.requireCurrentUser();
        GroupReservationInvite invite = inviteRepository
                .findById(Long.parseLong(inviteId))
                .orElseThrow(() -> new ResourceNotFoundException("Group invitation", inviteId));
        if (!invite.getInvitee().getId().equals(current.getId())) {
            throw new AccessDeniedException("You can only respond to your own invitations.");
        }
        return invite;
    }

    private GroupInvitationDto toInvitationDto(GroupReservationInvite invite) {
        ReservationRecord reservation = invite.getReservation();
        UserAccount organizer = reservation.getUser();
        List<String> preview = parseParticipants(reservation.getParticipantsJson());
        if (preview.isEmpty()) {
            preview = List.of();
        }
        return new GroupInvitationDto(
                String.valueOf(invite.getId()),
                String.valueOf(reservation.getId()),
                displayName(organizer),
                reservation.getWorkspaceId(),
                reservation.getDate(),
                reservation.getSlotLabel() != null ? reservation.getSlotLabel() : reservation.getSlotId(),
                invite.getExpiresAt() != null ? invite.getExpiresAt().toString() : null,
                preview);
    }

    private List<String> parseParticipants(String json) {
        if (json == null || json.isBlank()) {
            return Collections.emptyList();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<List<String>>() {});
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }

    private static String displayName(UserAccount user) {
        if (user.getName() != null && !user.getName().isBlank()) {
            return user.getName();
        }
        if (user.getNickname() != null && !user.getNickname().isBlank()) {
            return user.getNickname();
        }
        return "Organizer";
    }
}
