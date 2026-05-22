package com.studysync.job;

import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.policy.SlotStartTimeResolver;
import com.studysync.domain.repository.ReservationRecordRepository;
import com.studysync.domain.service.ResponsibilityScoreService;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Component
public class AutoCancelReservationJob {

    private static final Logger logger = LoggerFactory.getLogger(AutoCancelReservationJob.class);

    private final ReservationRecordRepository reservationRepository;
    private final ResponsibilityScoreService responsibilityScoreService;
    private final Clock clock;

    public AutoCancelReservationJob(ReservationRecordRepository reservationRepository,
                                    ResponsibilityScoreService responsibilityScoreService,
                                    Clock clock) {
        this.reservationRepository = reservationRepository;
        this.responsibilityScoreService = responsibilityScoreService;
        this.clock = clock;
    }

    @Scheduled(cron = "0 * * * * *")
    public void cancelNoShows() {
        String today = LocalDate.now(clock).toString();
        List<ReservationRecord> activeReservations = reservationRepository.findByDateAndStatusIn(today, List.of("ACTIVE", "PENDING"));

        LocalTime now = LocalTime.now(clock);

        for (ReservationRecord record : activeReservations) {
            LocalTime startTime = SlotStartTimeResolver.resolve(record);
            if (startTime == null) {
                continue;
            }

            try {
                if (now.isAfter(startTime.plusMinutes(15))) {
                    logger.info("Reservation {} is a no-show. Cancelling automatically.", record.getId());

                    // Transition to NO_SHOW status
                    record.setStatus("NO_SHOW");
                    reservationRepository.saveAndFlush(record);

                    // Apply -5 penalty score
                    responsibilityScoreService.applyDelta(record.getUser().getId(), -5);
                }
            } catch (Exception e) {
                logger.error("Failed to parse or process reservation no-show for ID {}: {}", record.getId(), e.getMessage());
            }
        }
    }
}
