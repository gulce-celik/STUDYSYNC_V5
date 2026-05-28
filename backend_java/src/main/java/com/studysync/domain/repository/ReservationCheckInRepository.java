package com.studysync.domain.repository;

import com.studysync.domain.entity.ReservationCheckIn;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReservationCheckInRepository extends JpaRepository<ReservationCheckIn, Long> {

    boolean existsByReservation_IdAndUser_Id(Long reservationId, Long userId);

    long countByReservation_Id(Long reservationId);

    List<ReservationCheckIn> findByReservation_Id(Long reservationId);

    List<ReservationCheckIn> findByReservation_IdIn(Collection<Long> reservationIds);
}
