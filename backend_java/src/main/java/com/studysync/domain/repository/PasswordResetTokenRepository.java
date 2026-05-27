package com.studysync.domain.repository;

import com.studysync.domain.entity.PasswordResetToken;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, Long> {
    Optional<PasswordResetToken> findByToken(String token);
    Optional<PasswordResetToken> findByEmailIgnoreCase(String email);
    void deleteByEmailIgnoreCase(String email);
}
