package com.studysync.domain.policy;

import com.studysync.domain.entity.GroupReservationInvite;
import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.repository.GroupReservationInviteRepository;
import com.studysync.domain.repository.ReservationCheckInRepository;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Component;

/** Resolves who must check in for group reservations and whether all have. */
@Component
public class GroupCheckInPolicy {

    private final GroupReservationInviteRepository inviteRepository;
    private final ReservationCheckInRepository checkInRepository;

    public GroupCheckInPolicy(
            GroupReservationInviteRepository inviteRepository,
            ReservationCheckInRepository checkInRepository) {
        this.inviteRepository = inviteRepository;
        this.checkInRepository = checkInRepository;
    }

    public boolean isGroupReservation(Long reservationId) {
        return !inviteRepository.findByReservation_Id(reservationId).isEmpty();
    }

    public Set<Long> requiredParticipantUserIds(ReservationRecord reservation) {
        Set<Long> required = new HashSet<>();
        required.add(reservation.getUser().getId());
        List<GroupReservationInvite> invites = inviteRepository.findByReservation_Id(reservation.getId());
        for (GroupReservationInvite invite : invites) {
            if (GroupInvitationPolicy.STATUS_ACCEPTED.equals(invite.getStatus())) {
                required.add(invite.getInvitee().getId());
            }
        }
        return required;
    }

    public boolean isParticipant(ReservationRecord reservation, Long userId) {
        return requiredParticipantUserIds(reservation).contains(userId);
    }

    public boolean allCheckedIn(Long reservationId, Set<Long> requiredUserIds) {
        if (requiredUserIds.isEmpty()) {
            return true;
        }
        long checkedIn = checkInRepository.countByReservation_Id(reservationId);
        return checkedIn >= requiredUserIds.size();
    }

    public int checkedInCount(Long reservationId) {
        return (int) checkInRepository.countByReservation_Id(reservationId);
    }
}
