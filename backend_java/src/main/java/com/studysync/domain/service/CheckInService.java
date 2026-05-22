/* FILE PURPOSE: Is kurallari ve use-case akislari; controller ve repository arasinda orkestrasyon. */

package com.studysync.domain.service;

import com.studysync.domain.dto.CheckInResultDto;
import com.studysync.domain.dto.CheckInVerifyRequestDto;
import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.policy.QrCheckInPolicy;
import com.studysync.domain.repository.ReservationRecordRepository;
import org.springframework.stereotype.Service;

/**
 * QR check-in doğrulama — {@link com.studysync.domain.policy.QrCheckInPolicy} + rezervasyon durumu güncelleme.
 *
 * <p><b>Başarı:</b> rezervasyon {@code COMPLETED} veya operasyonel status; {@link ResponsibilityScoreService} pozitif delta.
 *
 * <p><b>Başarısız:</b> anlamlı mesaj; loglama.
 */
@Service
public class CheckInService {

    private final ReservationRecordRepository reservationRepository;
    private final QrCheckInPolicy qrCheckInPolicy;
    private final ResponsibilityScoreService responsibilityScoreService;

    public CheckInService(
            ReservationRecordRepository reservationRepository,
            QrCheckInPolicy qrCheckInPolicy,
            ResponsibilityScoreService responsibilityScoreService) {
        this.reservationRepository = reservationRepository;
        this.qrCheckInPolicy = qrCheckInPolicy;
        this.responsibilityScoreService = responsibilityScoreService;
    }

    @org.springframework.transaction.annotation.Transactional
    public CheckInResultDto verify(CheckInVerifyRequestDto request) {
        // Antigravity Modification: Implemented true QR Check-in business logic, state transitions, and reward allocations
        long resId;
        try {
            resId = Long.parseLong(request.reservationId());
        } catch (NumberFormatException e) {
            return new CheckInResultDto(false, "Invalid reservation ID format");
        }

        ReservationRecord reservation = reservationRepository.findById(resId).orElse(null);
        
        if (reservation == null) {
            return new CheckInResultDto(false, "Reservation not found");
        }

        if (!"ACTIVE".equals(reservation.getStatus()) && !"PENDING".equals(reservation.getStatus())) {
            return new CheckInResultDto(false, "Reservation is not active or pending.");
        }

        if (!qrCheckInPolicy.isWithinCheckInWindow(reservation)) {
            return new CheckInResultDto(false,
                    "Check-in is only available from 15 minutes before until 15 minutes after your slot start time.");
        }

        if (!qrCheckInPolicy.payloadMatchesReservation(reservation, request.qrPayload())) {
            return new CheckInResultDto(false, "Invalid QR code for this desk.");
        }

        reservation.setStatus("COMPLETED");
        reservationRepository.saveAndFlush(reservation);

        responsibilityScoreService.applyDelta(reservation.getUser().getId(), 5);

        // Antigravity Modification: Enforce history limit (max 10 completed/cancelled elements)
        Long userId = reservation.getUser().getId();
        java.util.List<String> historyStatuses = java.util.List.of("COMPLETED", "CANCELLED");
        long historyCount = reservationRepository.countByUser_IdAndStatusIn(userId, historyStatuses);
        
        if (historyCount > 10) {
            long itemsToDelete = historyCount - 10;
            // Find oldest history items by ID (First In First Out), but EXCLUDE the one we just completed
            java.util.List<ReservationRecord> oldestItems = reservationRepository
                .findByUser_IdAndStatusInOrderByIdAsc(userId, historyStatuses)
                .stream()
                .filter(r -> !r.getId().equals(reservation.getId()))
                .collect(java.util.stream.Collectors.toList());
            
            for (int i = 0; i < Math.min(itemsToDelete, oldestItems.size()); i++) {
                reservationRepository.delete(oldestItems.get(i));
            }
        }

        return new CheckInResultDto(true, "Check-in successful! +5 responsibility score added.");
    }
}
