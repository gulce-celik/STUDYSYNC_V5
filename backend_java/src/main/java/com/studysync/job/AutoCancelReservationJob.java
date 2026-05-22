package com.studysync.job;

import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.repository.ReservationRecordRepository;
import com.studysync.domain.service.ResponsibilityScoreService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Component
public class AutoCancelReservationJob {

    private static final Logger logger = LoggerFactory.getLogger(AutoCancelReservationJob.class);

    private final ReservationRecordRepository reservationRepository;
    private final ResponsibilityScoreService responsibilityScoreService;

    public AutoCancelReservationJob(ReservationRecordRepository reservationRepository,
                                    ResponsibilityScoreService responsibilityScoreService) {
        this.reservationRepository = reservationRepository;
        this.responsibilityScoreService = responsibilityScoreService;
    }

    @Scheduled(cron = "0 * * * * *")
    public void cancelNoShows() {
        String today = LocalDate.now().toString();
        List<ReservationRecord> activeReservations = reservationRepository.findByDateAndStatusIn(today, List.of("ACTIVE", "PENDING"));

        LocalTime now = LocalTime.now();

        for (ReservationRecord record : activeReservations) {
            String slotLabel = record.getSlotLabel();
            if (slotLabel == null || slotLabel.length() < 5) {
                continue;
            }

            try {
                // Parse the start time from the slot label (e.g. "06.00-09.00" -> "06:00")
                String startTimeStr = slotLabel.substring(0, 5).replace(".", ":");
                LocalTime startTime = LocalTime.parse(startTimeStr);

                // If 15 minutes have passed since the start of the reservation slot
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
