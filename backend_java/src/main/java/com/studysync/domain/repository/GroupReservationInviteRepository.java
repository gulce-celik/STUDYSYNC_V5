package com.studysync.domain.repository;

import com.studysync.domain.entity.GroupReservationInvite;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface GroupReservationInviteRepository extends JpaRepository<GroupReservationInvite, Long> {

    List<GroupReservationInvite> findByInvitee_IdAndStatus(Long inviteeUserId, String status);

    List<GroupReservationInvite> findByReservation_Id(Long reservationId);

    List<GroupReservationInvite> findByReservation_IdIn(Collection<Long> reservationIds);

    boolean existsByReservation_IdAndStatus(Long reservationId, String status);

    @Query(
            """
            SELECT DISTINCT i.reservation.id FROM GroupReservationInvite i
            WHERE i.status = :pendingStatus AND i.expiresAt < :now
            """)
    List<Long> findReservationIdsWithExpiredPendingInvites(
            @Param("pendingStatus") String pendingStatus, @Param("now") Instant now);
}
