/* FILE PURPOSE: Spring Data repository; entity sorgulari/persist islemleri icin veri erisim katmani. */

package com.studysync.domain.repository;

import com.studysync.domain.entity.WeeklyScheduleBlockEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

/**
 * Haftalık meşgul blokları — Schedule ekranı {@code GET/PUT /schedule/weekly}.
 *
 * <p><b>Implementasyon:</b> PUT öncesi kullanıcıya ait satırları silip yeni seti yazmak yaygın pattern.
 */
public interface WeeklyScheduleBlockRepository extends JpaRepository<WeeklyScheduleBlockEntity, Long> {

    // Antigravity Modification: Renamed derived query to match the entity properties 'dayCode' and 'timeSlot'
    List<WeeklyScheduleBlockEntity> findByUser_IdOrderByDayCodeAscTimeSlotAsc(Long userId);

    @Modifying
    @Query("DELETE FROM WeeklyScheduleBlockEntity w WHERE w.user.id = :userId")
    void deleteByUser_Id(Long userId);
}
