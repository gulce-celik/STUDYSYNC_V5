/* FILE PURPOSE: Spring Data repository; entity sorgulari/persist islemleri icin veri erisim katmani. */

package com.studysync.domain.repository;

import com.studysync.domain.entity.BuddyReportRecord;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Study Buddy kullanıcı raporları — admin listesi ve tekil yükleme. */
public interface BuddyReportRecordRepository extends JpaRepository<BuddyReportRecord, Long> {

    List<BuddyReportRecord> findByStatusOrderByCreatedAtDesc(String status);

    @Query(
            "SELECT r FROM BuddyReportRecord r "
                    + "LEFT JOIN FETCH r.reportedUser "
                    + "LEFT JOIN FETCH r.reportedBy "
                    + "WHERE r.id = :id")
    Optional<BuddyReportRecord> findByIdWithUsers(@Param("id") Long id);

    @Query(
            "SELECT r FROM BuddyReportRecord r "
                    + "LEFT JOIN FETCH r.reportedUser "
                    + "LEFT JOIN FETCH r.reportedBy "
                    + "WHERE r.status = :status ORDER BY r.createdAt DESC")
    List<BuddyReportRecord> findByStatusWithUsersOrderByCreatedAtDesc(@Param("status") String status);
}
