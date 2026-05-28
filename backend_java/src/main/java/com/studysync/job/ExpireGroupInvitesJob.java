package com.studysync.job;

import com.studysync.domain.service.GroupInvitationService;
import java.time.Clock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Cancels group reservations when invitees do not all accept within 15 minutes. */
@Component
public class ExpireGroupInvitesJob {

    private static final Logger logger = LoggerFactory.getLogger(ExpireGroupInvitesJob.class);

    private final GroupInvitationService groupInvitationService;
    private final Clock clock;

    public ExpireGroupInvitesJob(GroupInvitationService groupInvitationService, Clock clock) {
        this.groupInvitationService = groupInvitationService;
        this.clock = clock;
    }

    @Scheduled(cron = "0 * * * * *")
    @Transactional
    public void expireStaleInvites() {
        int count = groupInvitationService.expireStaleInvites(clock.instant());
        if (count > 0) {
            logger.info("Cancelled {} group reservation(s) due to expired invites", count);
        }
    }
}
