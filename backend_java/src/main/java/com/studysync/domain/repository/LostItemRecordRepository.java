/* FILE PURPOSE: Spring Data repository; entity sorgulari/persist islemleri icin veri erisim katmani. */

package com.studysync.domain.repository;

import com.studysync.domain.entity.LostItemRecord;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * Kayıp eşya kayıtları — Profile “Lost items” listesi.
 *
 * <p>
 * <b>Sorgular:</b> kullanıcıya göre; isteğe bağlı status filtresi.
 */
public interface LostItemRecordRepository extends JpaRepository<LostItemRecord, Long> {

    // Antigravity Modification: Renamed derived query to match the entity property
    // 'reportedBy'
    List<LostItemRecord> findByReportedBy_IdOrderByReportedAtDesc(Long userId);

    List<LostItemRecord> findByStatusOrderByReportedAtDesc(String status);

    @Query(
            "SELECT r FROM LostItemRecord r LEFT JOIN FETCH r.reportedBy "
                    + "WHERE r.status IN :statuses ORDER BY r.reportedAt DESC")
    List<LostItemRecord> findByStatusInOrderByReportedAtDesc(@Param("statuses") Collection<String> statuses);

    @Query("SELECT r FROM LostItemRecord r LEFT JOIN FETCH r.reportedBy WHERE r.id = :id")
    java.util.Optional<LostItemRecord> findByIdWithReporter(@Param("id") Long id);
}
