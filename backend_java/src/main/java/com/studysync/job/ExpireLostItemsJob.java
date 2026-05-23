package com.studysync.job;

import com.studysync.domain.service.LostFoundService;
import java.time.Clock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Hides lost-item reports after {@link com.studysync.domain.policy.LostFoundPolicy#REPORT_TTL_HOURS} hours. */
@Component
public class ExpireLostItemsJob {

    private static final Logger logger = LoggerFactory.getLogger(ExpireLostItemsJob.class);

    private final LostFoundService lostFoundService;
    private final Clock clock;

    public ExpireLostItemsJob(LostFoundService lostFoundService, Clock clock) {
        this.lostFoundService = lostFoundService;
        this.clock = clock;
    }

    @Scheduled(cron = "0 * * * * *")
    @Transactional
    public void expireStaleReports() {
        int count = lostFoundService.expireStaleReports(clock.instant());
        if (count > 0) {
            logger.info("Expired {} lost-item report(s)", count);
        }
    }
}
