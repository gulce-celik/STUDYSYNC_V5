/* FILE PURPOSE: Is kurallari ve use-case akislari; controller ve repository arasinda orkestrasyon. */

package com.studysync.domain.service;

import com.studysync.domain.campus.WorkspaceQrRegistry;
import com.studysync.domain.dto.ActionResultDto;
import com.studysync.domain.dto.CreateReservationRequestDto;
import com.studysync.domain.dto.ReservationDetailDto;
import com.studysync.domain.dto.WorkspaceDto;
import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.mapper.ReservationMapper;
import com.studysync.domain.policy.CancellationScoringPolicy;
import com.studysync.domain.repository.ReservationRecordRepository;
import com.studysync.domain.repository.UserAccountRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.studysync.domain.dto.CancelReservationRequestDto;
import com.studysync.domain.exception.AccessDeniedException;
import com.studysync.domain.exception.ResourceNotFoundException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

/**
 * Rezervasyon alan iş kuralları — şimdilik boş/taş iskelet; gerçek mantığı siz
 * yazacaksınız.
 *
 * <p>
 * <b>getWorkspaces(date, slotId, type)</b>
 *
 * <ul>
 * <li>Veritabanından veya harita servisinden o tarih + slot + tip
 * (bireysel/grup) için masa/oda listesi.
 * <li>Doluluk: o slotta başka rezervasyon var mı, anlık sensör/operatör
 * güncellemesi varsa birleştirin.
 * <li>Analiz dokümanındaki Mon/Fri penceresi, anlık masa kuralları burada veya
 * üst katmanda uygulanmalı.
 * </ul>
 *
 * <p>
 * <b>createReservation(...)</b> — Controller’dan parse edilen gövde ile:
 *
 * <ul>
 * <li>Çakışma kontrolü, günlük kota, kullanıcı sorumluluk puanı eşiği.
 * <li>Persist: {@code Reservation} entity; yanıt {@code ReservationDetailDto}
 * ile aynı alanlar.
 * </ul>
 *
 * <p>
 * <b>myReservations()</b> — JWT’den userId okuyup sadece o kullanıcının
 * kayıtlarını döndürün.
 *
 * <p>
 * <b>cancelReservation</b> — {@code docs/decision-cancellation-scoring.md} ve
 * {@code api-contract-v1.md}:
 * iptal zamanına göre {@code scoreChange}, {@code pointsRefunded} hesaplayın.
 */
@Service
public class ReservationService {

    private final CancellationScoringPolicy cancellationScoringPolicy;
    private final ReservationRecordRepository reservationRepository;
    private final ResponsibilityScoreService responsibilityScoreService;
    private final ObjectMapper objectMapper;
    private final WorkspaceQrRegistry workspaceQrRegistry;

    public ReservationService(CancellationScoringPolicy cancellationScoringPolicy,
            ReservationRecordRepository reservationRepository,
            ResponsibilityScoreService responsibilityScoreService,
            ObjectMapper objectMapper,
            WorkspaceQrRegistry workspaceQrRegistry) {
        this.cancellationScoringPolicy = cancellationScoringPolicy;
        this.reservationRepository = reservationRepository;
        this.responsibilityScoreService = responsibilityScoreService;
        this.objectMapper = objectMapper;
        this.workspaceQrRegistry = workspaceQrRegistry;
    }

    private List<WorkspaceDto> generateWorkspaces() {
        List<WorkspaceDto> list = new java.util.ArrayList<>();
        for (int i = 0; i < 24; i++) {
            String id = "desk-" + (i + 1);
            list.add(new WorkspaceDto(
                    id, "individual", 1, "available", 12 + (i % 8) * 40, 35 + (i / 8) * 65,
                    workspaceQrRegistry.qrFor(id)));
        }
        list.add(workspaceDto("group-1", "group", 4, 12, 265));
        list.add(workspaceDto("group-2", "group", 4, 89, 265));
        list.add(workspaceDto("group-3", "group", 6, 166, 265));
        list.add(workspaceDto("group-4", "group", 4, 243, 265));
        return list;
    }

    private WorkspaceDto workspaceDto(String id, String type, int capacity, int x, int y) {
        return new WorkspaceDto(id, type, capacity, "available", x, y, workspaceQrRegistry.qrFor(id));
    }

    public List<WorkspaceDto> getWorkspaces(String date, String slotId, String type) {
        List<WorkspaceDto> all = generateWorkspaces();
        return all.stream().map(ws -> {
            boolean occupied = reservationRepository.existsByWorkspaceIdAndDateAndSlotIdAndStatusIn(
                    ws.id(), date, slotId, List.of("ACTIVE", "PENDING", "COMPLETED"));
            return new WorkspaceDto(
                    ws.id(), ws.type(), ws.capacity(), occupied ? "occupied" : "available", ws.x(), ws.y(), ws.qrCode());
        }).collect(Collectors.toList());
    }

    public ReservationDetailDto createReservation(CreateReservationRequestDto request) {
        // Validation: Overlap check
        boolean hasOverlap = reservationRepository.existsByWorkspaceIdAndDateAndSlotIdAndStatusIn(
                request.workspaceId(), request.date(), request.slotId(), List.of("ACTIVE", "PENDING"));
        if (hasOverlap) {
            throw new IllegalStateException("This slot is already booked for the selected workspace.");
        }

        // Antigravity Modification: Replaced dummy user hardcoding with real Phase 3
        // Security Context user extraction!
        Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (!(principal instanceof UserAccount)) {
            throw new IllegalStateException("Authentication is missing. Please log in first.");
        }
        UserAccount user = (UserAccount) principal;
        Long defaultUserId = user.getId();

        // 2. Validation: Advance Booking Window (Mon/Fri Rule)
        java.time.LocalDate today = java.time.LocalDate.now();
        java.time.LocalDate targetDate = java.time.LocalDate.parse(request.date());

        if (targetDate.isAfter(today)) {
            java.time.DayOfWeek todayDay = today.getDayOfWeek();
            boolean isMonday = todayDay == java.time.DayOfWeek.MONDAY;
            boolean isFriday = todayDay == java.time.DayOfWeek.FRIDAY;

            if (!isMonday && !isFriday) {
                throw new IllegalStateException("Advance booking is only allowed on Mondays and Fridays.");
            }
        }

        // 3. Validation: Quota validation (Dynamic limit based on score)
        int dailyLimit = user.getResponsibilityScore() < 75 ? 2 : 3;
        int dailyReservations = reservationRepository.countByUser_IdAndDateAndStatusIn(
                defaultUserId, request.date(), List.of("ACTIVE", "PENDING", "COMPLETED"));

        if (dailyReservations >= dailyLimit) {
            throw new IllegalStateException("Daily limit reached. With your score of " +
                    user.getResponsibilityScore() + ", you can make " + dailyLimit + " reservations per day.");
        }

        // Map and Save
        ReservationRecord record = new ReservationRecord();
        record.setUser(user);
        record.setWorkspaceId(request.workspaceId());
        record.setDate(request.date());
        record.setSlotId(request.slotId());

        // Antigravity Modification: Use actual time ranges for labels as requested by
        // user.
        String label = switch (request.slotId()) {
            case "slot-1" -> "06.00-09.00";
            case "slot-2" -> "09.00-11.00";
            case "slot-3" -> "11.00-13.00";
            case "slot-4" -> "13.00-15.00";
            case "slot-5" -> "15.00-17.00";
            case "slot-6" -> "17.00-20.00";
            case "slot-7" -> "20.00-23.00";
            case "slot-8" -> "23.00-02.00";
            default -> request.slotId().replace("-", " ").toUpperCase();
        };
        record.setSlotLabel(label);
        record.setStatus("ACTIVE"); // Auto active for now
        record.setCourseCode(request.courseCode());
        record.setQrPayload(workspaceQrRegistry.qrFor(request.workspaceId()));

        try {
            if (request.participantNicknames() != null && !request.participantNicknames().isEmpty()) {
                record.setParticipantsJson(objectMapper.writeValueAsString(request.participantNicknames()));
            } else {
                record.setParticipantsJson("[]");
            }
        } catch (JsonProcessingException e) {
            record.setParticipantsJson("[]");
        }

        ReservationRecord saved = reservationRepository.save(record);
        return ReservationMapper.toDetail(saved, objectMapper, workspaceQrRegistry.qrFor(saved.getWorkspaceId()));
    }

    public List<ReservationDetailDto> myReservations() {
        // Antigravity Modification: Implemented user-specific logic to fetch
        // reservation history from Database.
        Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (!(principal instanceof UserAccount)) {
            return List.of();
        }
        UserAccount currentUser = (UserAccount) principal;
        List<ReservationRecord> records = reservationRepository
                .findByUser_IdOrderByDateDescSlotIdAsc(currentUser.getId());
        return records.stream()
                .map(r -> ReservationMapper.toDetail(r, objectMapper, workspaceQrRegistry.qrFor(r.getWorkspaceId())))
                .collect(Collectors.toList());
    }

    public ActionResultDto cancelReservation(String reservationId) {
        return cancelReservation(reservationId, null, null);
    }

    public ActionResultDto cancelReservation(String reservationId, LocalDateTime cancelledAt,
            LocalDateTime slotStartAt) {
        // Antigravity Modification: Implemented full secure cancellation flow with
        // ownership check and status persistence.
        final ReservationRecord record = reservationRepository.findById(Long.valueOf(reservationId))
                .orElseThrow(() -> new ResourceNotFoundException("Reservation", reservationId));

        // Ownership validation
        Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (!(principal instanceof UserAccount currentUser) || !record.getUser().getId().equals(currentUser.getId())) {
            throw new AccessDeniedException("You can only cancel your own reservations.");
        }

        if ("CANCELLED".equals(record.getStatus())) {
            return new ActionResultDto(false, "Reservation is already cancelled.", 0, null);
        }

        // Apply policy
        ActionResultDto result = cancellationScoringPolicy.evaluate(reservationId, cancelledAt, slotStartAt);

        // Update state
        record.setStatus("CANCELLED");
        reservationRepository.saveAndFlush(record);

        // Antigravity Modification: Enforce history limit (max 10 completed/cancelled
        // elements)
        Long userId = record.getUser().getId();
        java.util.List<String> historyStatuses = java.util.List.of("COMPLETED", "CANCELLED");
        long historyCount = reservationRepository.countByUser_IdAndStatusIn(userId, historyStatuses);

        if (historyCount > 10) {
            long itemsToDelete = historyCount - 10;
            // Find oldest history items by ID (First In First Out), but EXCLUDE the one we
            // just cancelled
            java.util.List<ReservationRecord> oldestItems = reservationRepository
                    .findByUser_IdAndStatusInOrderByIdAsc(userId, historyStatuses)
                    .stream()
                    .filter(r -> !r.getId().equals(record.getId()))
                    .collect(java.util.stream.Collectors.toList());

            for (int i = 0; i < Math.min(itemsToDelete, oldestItems.size()); i++) {
                reservationRepository.delete(oldestItems.get(i));
            }
        }

        // Apply scoring if applicable
        if (result.scoreChange() != null && result.scoreChange() != 0) {
            responsibilityScoreService.applyDelta(currentUser.getId(), result.scoreChange());
        }

        return result;
    }
}
