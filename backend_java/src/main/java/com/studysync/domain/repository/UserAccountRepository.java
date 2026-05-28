/* FILE PURPOSE: Spring Data repository; entity sorgulari/persist islemleri icin veri erisim katmani. */

package com.studysync.domain.repository;

import com.studysync.domain.entity.UserAccount;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Kullanıcı hesapları — login, register, profil, JWT subject çözümü.
 *
 * <p><b>Kullanım:</b> {@code findByEmailIgnoreCase} ile giriş; {@code existsByEmailIgnoreCase} ile kayıt çakışması.
 */
public interface UserAccountRepository extends JpaRepository<UserAccount, Long> {

    Optional<UserAccount> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    Optional<UserAccount> findByNickname(String nickname);

    Optional<UserAccount> findByNicknameIgnoreCase(String nickname);

    java.util.List<UserAccount> findByIdNot(Long id);
}
