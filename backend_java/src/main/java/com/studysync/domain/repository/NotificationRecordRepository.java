package com.studysync.domain.repository;

import com.studysync.domain.entity.NotificationRecord;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface NotificationRecordRepository extends JpaRepository<NotificationRecord, Long> {

    List<NotificationRecord> findByUser_IdOrderByCreatedAtDesc(Long userId);

    @Modifying
    @Query("UPDATE NotificationRecord n SET n.read = true WHERE n.user.id = :userId AND n.read = false")
    int markAllReadForUser(@Param("userId") Long userId);
}
