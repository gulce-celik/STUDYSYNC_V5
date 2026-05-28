package com.studysync.domain.policy;

import com.studysync.domain.entity.GroupReservationInvite;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Set;

/** 15-minute unanimous accept window for group reservation invites. */
public final class GroupInvitationPolicy {

    public static final int INVITE_TTL_MINUTES = 15;

    public static final String STATUS_PENDING = "PENDING";
    public static final String STATUS_ACCEPTED = "ACCEPTED";
    public static final String STATUS_DECLINED = "DECLINED";
    public static final String STATUS_EXPIRED = "EXPIRED";

    private static final Set<String> TERMINAL_INVITE_STATUSES =
            Set.of(STATUS_ACCEPTED, STATUS_DECLINED, STATUS_EXPIRED);

    private GroupInvitationPolicy() {}

    public static Instant expiresAt(Instant createdAt) {
        return createdAt.plus(INVITE_TTL_MINUTES, ChronoUnit.MINUTES);
    }

    public static boolean isPending(GroupReservationInvite invite, Instant now) {
        return invite != null
                && STATUS_PENDING.equals(invite.getStatus())
                && invite.getExpiresAt() != null
                && invite.getExpiresAt().isAfter(now);
    }

    public static boolean isExpired(GroupReservationInvite invite, Instant now) {
        return invite != null
                && STATUS_PENDING.equals(invite.getStatus())
                && invite.getExpiresAt() != null
                && !invite.getExpiresAt().isAfter(now);
    }

    public static boolean allAccepted(List<GroupReservationInvite> invites) {
        if (invites == null || invites.isEmpty()) {
            return false;
        }
        return invites.stream().allMatch(i -> STATUS_ACCEPTED.equals(i.getStatus()));
    }

    public static boolean hasPending(List<GroupReservationInvite> invites, Instant now) {
        if (invites == null || invites.isEmpty()) {
            return false;
        }
        return invites.stream().anyMatch(i -> isPending(i, now));
    }

    public static boolean invitesConfirmed(List<GroupReservationInvite> invites) {
        return invites != null && !invites.isEmpty() && allAccepted(invites);
    }

    public static String expiresAtIso(List<GroupReservationInvite> invites) {
        if (invites == null || invites.isEmpty()) {
            return null;
        }
        Instant expires = invites.get(0).getExpiresAt();
        return expires != null ? expires.toString() : null;
    }

    public static boolean isTerminalStatus(String status) {
        return status != null && TERMINAL_INVITE_STATUSES.contains(status);
    }
}
