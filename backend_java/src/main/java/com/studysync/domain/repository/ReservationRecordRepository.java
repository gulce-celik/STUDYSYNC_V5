/* FILE PURPOSE: Spring Data repository; entity sorgulari/persist islemleri icin veri erisim katmani. */

package com.studysync.domain.repository;

import com.studysync.domain.entity.ReservationRecord;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Çalışma alanı rezervasyonları — Bookings, Home “today’s reservation”,
 * Dashboard.
 *
 * <p>
 * <b>Sorgular:</b> kullanıcıya göre tarih sıralı; çakışma kontrolü için alan +
 * tarih + slot aralığı.
 */
public interface ReservationRecordRepository extends JpaRepository<ReservationRecord, Long> {
    // Antigravity Modification: Added helper queries for overlaps, quotas, and
    // dashboard history mapping.
    List<ReservationRecord> findByUser_IdOrderByDateDescSlotIdAsc(Long userId);

    boolean existsByWorkspaceIdAndDateAndSlotIdAndStatusIn(String workspaceId, String date, String slotId,
            Collection<String> statuses);

    int countByUser_IdAndDateAndStatusIn(Long userId, String date, Collection<String> statuses);

    long countByUser_IdAndStatusIn(Long userId, Collection<String> statuses);

    List<ReservationRecord> findByUser_IdAndStatusInOrderByIdAsc(Long userId, Collection<String> statuses);

    List<ReservationRecord> findByDateAndStatusIn(String date, Collection<String> statuses);
}
