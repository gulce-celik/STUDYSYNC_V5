/* FILE PURPOSE: Reservation-level score deltas (check-in, no-show) aligned with product policy. */

package com.studysync.domain.policy;

import org.springframework.stereotype.Component;

/**
 * Score stored on each {@link com.studysync.domain.entity.ReservationRecord} — {@code 0} when created.
 *
 * <p>Cancellation windows use {@link CancellationScoringPolicy}. Check-in reward is separate from
 * {@code docs/decision-cancellation-scoring.md} but matches {@code docs/api-contract-v1.md}.
 */
@Component
public class ReservationScoringPolicy {

    public static final int INITIAL_SCORE = 0;
    public static final int CHECK_IN_SCORE = 5;
    public static final int NO_SHOW_SCORE = -10;

    public int initialScore() {
        return INITIAL_SCORE;
    }

    public int checkInScore() {
        return CHECK_IN_SCORE;
    }

    public int noShowScore() {
        return NO_SHOW_SCORE;
    }
}
