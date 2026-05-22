/* FILE PURPOSE: Is kurallari ve use-case akislari; controller ve repository arasinda orkestrasyon. */

package com.studysync.domain.service;

import com.studysync.domain.dto.HomeDashboardResponseDto;
import com.studysync.domain.dto.QuickStatsDto;
import com.studysync.domain.dto.ReservationSummaryDto;
import com.studysync.domain.dto.ScoreHistoryEntryDto;
import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.mapper.ReservationMapper;
import com.studysync.domain.repository.ReservationRecordRepository;
import java.util.ArrayList;
import java.util.List;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

/**
 * Ana ekran verisi — skor, yaklaşan rezervasyonlar, özet istatistik.
 */
@Service
public class DashboardService {

    private final ReservationRecordRepository reservationRepository;

    public DashboardService(ReservationRecordRepository reservationRepository) {
        this.reservationRepository = reservationRepository;
    }

    public HomeDashboardResponseDto homeForCurrentUser() {
        Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (!(principal instanceof UserAccount)) {
            throw new IllegalStateException("Authentication missing or invalid");
        }
        UserAccount currentUser = (UserAccount) principal;

        List<ReservationRecord> records =
                reservationRepository.findByUser_IdOrderByDateDescSlotIdAsc(currentUser.getId());

        List<ReservationSummaryDto> upcoming = records.stream()
                .filter(r -> "ACTIVE".equals(r.getStatus()) || "PENDING".equals(r.getStatus()))
                .map(ReservationMapper::toSummary)
                .toList();

        List<ScoreHistoryEntryDto> scoreHistory = buildScoreHistory(records);

        int activeCount = upcoming.size();
        int score = currentUser.getResponsibilityScore() != null ? currentUser.getResponsibilityScore() : 100;

        return new HomeDashboardResponseDto(score, upcoming, new QuickStatsDto(activeCount, 0), scoreHistory);
    }

    private static List<ScoreHistoryEntryDto> buildScoreHistory(List<ReservationRecord> records) {
        List<ScoreHistoryEntryDto> out = new ArrayList<>();
        for (ReservationRecord r : records) {
            if (!ReservationMapper.isTerminalStatus(r.getStatus())) {
                continue;
            }
            int delta = ReservationMapper.resolveScore(r);
            out.add(new ScoreHistoryEntryDto(
                    String.valueOf(r.getId()),
                    r.getDate(),
                    delta,
                    ReservationMapper.scoreHistoryDescription(r, delta),
                    r.getStatus()));
        }
        return out;
    }
}
