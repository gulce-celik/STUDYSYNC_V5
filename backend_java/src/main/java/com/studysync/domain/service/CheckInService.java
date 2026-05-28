/* FILE PURPOSE: Is kurallari ve use-case akislari; controller ve repository arasinda orkestrasyon. */

package com.studysync.domain.service;

import com.studysync.domain.dto.CheckInResultDto;
import com.studysync.domain.dto.CheckInVerifyRequestDto;
import com.studysync.domain.entity.ReservationCheckIn;
import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.exception.AccessDeniedException;
import com.studysync.domain.policy.GroupCheckInPolicy;
import com.studysync.domain.policy.QrCheckInPolicy;
import com.studysync.domain.policy.ReservationScoringPolicy;
import com.studysync.domain.repository.ReservationCheckInRepository;
import com.studysync.domain.repository.ReservationRecordRepository;
import com.studysync.security.SecurityUtils;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * QR check-in — per-user for group bookings; reservation completes when all required members check in.
 */
@Service
public class CheckInService {

    private final ReservationRecordRepository reservationRepository;
    private final ReservationCheckInRepository checkInRepository;
    private final QrCheckInPolicy qrCheckInPolicy;
    private final ResponsibilityScoreService responsibilityScoreService;
    private final ReservationScoringPolicy reservationScoringPolicy;
    private final GroupInvitationService groupInvitationService;
    private final GroupCheckInPolicy groupCheckInPolicy;
    private final Clock clock;

    public CheckInService(
            ReservationRecordRepository reservationRepository,
            ReservationCheckInRepository checkInRepository,
            QrCheckInPolicy qrCheckInPolicy,
            ResponsibilityScoreService responsibilityScoreService,
            ReservationScoringPolicy reservationScoringPolicy,
            GroupInvitationService groupInvitationService,
            GroupCheckInPolicy groupCheckInPolicy,
            Clock clock) {
        this.reservationRepository = reservationRepository;
        this.checkInRepository = checkInRepository;
        this.qrCheckInPolicy = qrCheckInPolicy;
        this.responsibilityScoreService = responsibilityScoreService;
        this.reservationScoringPolicy = reservationScoringPolicy;
        this.groupInvitationService = groupInvitationService;
        this.groupCheckInPolicy = groupCheckInPolicy;
        this.clock = clock;
    }

    @Transactional
    public CheckInResultDto verify(CheckInVerifyRequestDto request) {
        UserAccount currentUser = SecurityUtils.requireCurrentUser();

        long resId;
        try {
            resId = Long.parseLong(request.reservationId());
        } catch (NumberFormatException e) {
            return CheckInResultDto.failure("Invalid reservation ID format");
        }

        ReservationRecord reservation = reservationRepository.findById(resId).orElse(null);
        if (reservation == null) {
            return CheckInResultDto.failure("Reservation not found");
        }

        if (!groupCheckInPolicy.isParticipant(reservation, currentUser.getId())) {
            throw new AccessDeniedException("You are not a participant on this reservation.");
        }

        if (!"ACTIVE".equals(reservation.getStatus()) && !"PENDING".equals(reservation.getStatus())) {
            return CheckInResultDto.failure("Reservation is not active or pending.");
        }

        if (groupInvitationService.hasUnconfirmedInvites(reservation.getId())) {
            return CheckInResultDto.failure("Waiting for group members to accept the invitation.");
        }

        String windowReason = qrCheckInPolicy.checkInRejectionReason(reservation);
        if (windowReason != null) {
            return CheckInResultDto.failure(windowReason);
        }

        String qrReason = qrCheckInPolicy.qrMismatchReason(reservation, request.qrPayload());
        if (qrReason != null) {
            return CheckInResultDto.failure(qrReason);
        }

        boolean isGroup = groupCheckInPolicy.isGroupReservation(reservation.getId());
        Set<Long> required = groupCheckInPolicy.requiredParticipantUserIds(reservation);
        int requiredCount = isGroup ? required.size() : 1;

        if (checkInRepository.existsByReservation_IdAndUser_Id(reservation.getId(), currentUser.getId())) {
            int done = groupCheckInPolicy.checkedInCount(reservation.getId());
            boolean allIn = groupCheckInPolicy.allCheckedIn(reservation.getId(), required);
            return new CheckInResultDto(
                    true,
                    "You already checked in.",
                    allIn || "COMPLETED".equals(reservation.getStatus()),
                    done,
                    requiredCount);
        }

        final int scoreDelta = reservationScoringPolicy.checkInScore();
        ReservationCheckIn checkIn = new ReservationCheckIn();
        checkIn.setReservation(reservation);
        checkIn.setUser(currentUser);
        checkIn.setCheckedInAt(Instant.now(clock));
        checkInRepository.saveAndFlush(checkIn);

        responsibilityScoreService.applyDelta(currentUser.getId(), scoreDelta);

        int done = groupCheckInPolicy.checkedInCount(reservation.getId());
        boolean allCheckedIn = groupCheckInPolicy.allCheckedIn(reservation.getId(), required);

        if (allCheckedIn) {
            reservation.setStatus("COMPLETED");
            reservation.setScore(scoreDelta);
            reservationRepository.saveAndFlush(reservation);
            trimOrganizerHistory(reservation);
            return new CheckInResultDto(
                    true,
                    "Check-in successful! All members checked in. +5 responsibility score added.",
                    true,
                    done,
                    requiredCount);
        }

        if (isGroup) {
            return new CheckInResultDto(
                    true,
                    "Check-in recorded (" + done + " of " + requiredCount + "). Waiting for other members. +5 responsibility score added.",
                    false,
                    done,
                    requiredCount);
        }

        reservation.setStatus("COMPLETED");
        reservation.setScore(scoreDelta);
        reservationRepository.saveAndFlush(reservation);
        trimOrganizerHistory(reservation);
        return new CheckInResultDto(
                true,
                "Check-in successful! +5 responsibility score added.",
                true,
                1,
                1);
    }

    private void trimOrganizerHistory(ReservationRecord reservation) {
        Long userId = reservation.getUser().getId();
        List<String> historyStatuses = List.of("COMPLETED", "CANCELLED");
        long historyCount = reservationRepository.countByUser_IdAndStatusIn(userId, historyStatuses);

        if (historyCount > 10) {
            long itemsToDelete = historyCount - 10;
            List<ReservationRecord> oldestItems = reservationRepository
                    .findByUser_IdAndStatusInOrderByIdAsc(userId, historyStatuses)
                    .stream()
                    .filter(r -> !r.getId().equals(reservation.getId()))
                    .toList();

            for (int i = 0; i < Math.min(itemsToDelete, oldestItems.size()); i++) {
                reservationRepository.delete(oldestItems.get(i));
            }
        }
    }
}
