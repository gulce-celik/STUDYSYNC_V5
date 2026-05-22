package com.studysync.job;

import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.policy.QrCheckInPolicy;
import com.studysync.domain.policy.ReservationScoringPolicy;
import com.studysync.domain.policy.SlotStartTimeResolver;
import com.studysync.domain.repository.ReservationRecordRepository;
import com.studysync.domain.service.ResponsibilityScoreService;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Marks unchecked reservations as {@code NO_SHOW} when the QR check-in window closes
 * ({@link QrCheckInPolicy#GRACE_AFTER_START_MINUTES} after slot start) and applies the
 * responsibility score penalty ({@link ReservationScoringPolicy#NO_SHOW_SCORE}).
 */
@Component
public class AutoCancelReservationJob {

    private static final Logger logger = LoggerFactory.getLogger(AutoCancelReservationJob.class);

    private final ReservationRecordRepository reservationRepository;
    private final ResponsibilityScoreService responsibilityScoreService;
    private final ReservationScoringPolicy reservationScoringPolicy;
    private final Clock clock;

    public AutoCancelReservationJob(
            ReservationRecordRepository reservationRepository,
            ResponsibilityScoreService responsibilityScoreService,
            ReservationScoringPolicy reservationScoringPolicy,
            Clock clock) {
        this.reservationRepository = reservationRepository;
        this.responsibilityScoreService = responsibilityScoreService;
        this.reservationScoringPolicy = reservationScoringPolicy;
        this.clock = clock;
    }

    /** Runs every minute; uses campus clock ({@link com.studysync.config.TimeConfig#CAMPUS_ZONE}). */
    @Scheduled(cron = "0 * * * * *")
    @Transactional
    public void cancelNoShows() {
        String today = LocalDate.now(clock).toString();
        List<ReservationRecord> activeReservations = reservationRepository.findByDateAndStatusIn(
                today, List.of("ACTIVE", "PENDING"));

        LocalTime now = LocalTime.now(clock);

        for (ReservationRecord record : activeReservations) {
            processRecordIfNoShow(record, now);
        }
    }

    void processRecordIfNoShow(ReservationRecord record, LocalTime now) {
        LocalTime startTime = SlotStartTimeResolver.resolve(record);
        if (startTime == null) {
            logger.warn("Skipping reservation {} — cannot resolve slot start time", record.getId());
            return;
        }

        LocalTime deadline = startTime.plusMinutes(QrCheckInPolicy.GRACE_AFTER_START_MINUTES);
        if (!now.isAfter(deadline)) {
            return;
        }

        String status = record.getStatus();
        if (!"ACTIVE".equals(status) && !"PENDING".equals(status)) {
            return;
        }

        final int noShowScore = reservationScoringPolicy.noShowScore();
        record.setStatus("NO_SHOW");
        record.setScore(noShowScore);
        reservationRepository.saveAndFlush(record);

        Long userId = record.getUser().getId();
        responsibilityScoreService.applyDelta(userId, noShowScore);

        logger.info(
                "Reservation {} marked NO_SHOW (slot start {}, deadline {}). User {} score {}.",
                record.getId(),
                startTime,
                deadline,
                userId,
                noShowScore);
    }
}
