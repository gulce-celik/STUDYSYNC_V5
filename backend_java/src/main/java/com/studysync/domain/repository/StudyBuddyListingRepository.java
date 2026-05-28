package com.studysync.domain.repository;

import com.studysync.domain.entity.StudyBuddyListingEntity;
import java.time.Instant;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StudyBuddyListingRepository extends JpaRepository<StudyBuddyListingEntity, Long> {
    long countByUser_IdAndCreatedAtAfter(Long userId, Instant since);
    long countByUser_IdAndCreatedAtAfterAndStatusNot(Long userId, Instant since, String status);
    long countByUser_IdAndStatus(Long userId, String status);
    
    java.util.List<StudyBuddyListingEntity> findByUser_IdAndStatus(Long userId, String status);
    java.util.List<StudyBuddyListingEntity> findByUser_IdOrderByCreatedAtDesc(Long userId);

    @org.springframework.data.jpa.repository.Query("SELECT DISTINCT l.user FROM StudyBuddyListingEntity l WHERE l.status = 'ACTIVE' AND l.createdAt > :since AND l.user.id <> :currentUserId")
    java.util.List<com.studysync.domain.entity.UserAccount> findActiveCandidatesSince(
            @org.springframework.data.repository.query.Param("since") Instant since,
            @org.springframework.data.repository.query.Param("currentUserId") Long currentUserId
    );
}
