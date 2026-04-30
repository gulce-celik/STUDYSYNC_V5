/* FILE PURPOSE: Is kurallari ve use-case akislari; controller ve repository arasinda orkestrasyon. */

package com.studysync.domain.service;

import com.studysync.domain.dto.LoginRequestDto;
import com.studysync.domain.dto.LoginResponseDto;
import com.studysync.domain.dto.RegisterRequestDto;
import com.studysync.domain.dto.UserSummaryDto;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.exception.EmailAlreadyExistsException;
import com.studysync.domain.exception.InvalidCredentialsException;
import com.studysync.domain.exception.InvalidDomainException;
import com.studysync.domain.repository.UserAccountRepository;
import com.studysync.security.JwtTokenProvider;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Kimlik doğrulama ve kayıt — login JWT, refresh akışı, e-posta tekilliği.
 *
 * <p>
 * <b>login:</b> {@link UserAccountRepository#findByEmailIgnoreCase(String)} +
 * {@link PasswordEncoder#matches};
 * başarıda {@link com.studysync.security.JwtTokenProvider} ile tokenlar
 * (şimdilik stub string).
 *
 * <p>
 * <b>register:</b> alan doğrulama, şifre hash, {@link UserAccount} insert;
 * isteğe bağlı ders seçimleri.
 */
@Service
public class AuthService {

    private final UserAccountRepository userAccountRepository;
    private final ReferenceCatalogService referenceCatalogService;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    public AuthService(
            UserAccountRepository userAccountRepository,
            ReferenceCatalogService referenceCatalogService,
            PasswordEncoder passwordEncoder,
            JwtTokenProvider jwtTokenProvider) {
        this.userAccountRepository = userAccountRepository;
        this.referenceCatalogService = referenceCatalogService;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    public LoginResponseDto login(LoginRequestDto request) {
        UserAccount userAccount = userAccountRepository.findByEmailIgnoreCase(request.email())
                .orElseThrow(InvalidCredentialsException::new);

        if (!passwordEncoder.matches(request.password(), userAccount.getPasswordHash())) {
            throw new InvalidCredentialsException();
        }

        // Antigravity Modification: Wired up secure JJWT cryptographic signing logic
        // instead of generating stub token strings.
        String accessToken = jwtTokenProvider.createAccessTokenForUserId(userAccount.getId());
        String refreshToken = jwtTokenProvider.createRefreshTokenValue();

        final String deptName = referenceCatalogService
                .resolveDepartmentName(userAccount.getDepartmentId())
                .orElse(userAccount.getDepartmentId());

        final UserSummaryDto summary = new UserSummaryDto(
                String.valueOf(userAccount.getId()),
                userAccount.getName(),
                userAccount.getNickname(),
                userAccount.getEmail(),
                deptName,
                userAccount.getYear(),
                userAccount.getResponsibilityScore(),
                userAccount.getEnrolledCourses());

        return new LoginResponseDto(accessToken, refreshToken, summary);
    }

    @Transactional
    public LoginResponseDto register(RegisterRequestDto request) {
        /*
         * TODO:
         * - existsByEmail → 409
         * - email domain @std.yeditepe.edu.tr
         * - passwordEncoder.encode
         * - new UserAccount → save
         * - JWT + refresh persist
         */
        if (userAccountRepository.existsByEmailIgnoreCase(request.email())) {
            throw new EmailAlreadyExistsException(request.email());
        }

        // Antigravity Modification: Hardcoded University domain rule rejection policy
        // mapping.
        if (!request.email().trim().toLowerCase().endsWith("@std.yeditepe.edu.tr")) {
            throw new InvalidDomainException("@std.yeditepe.edu.tr");
        }

        final UserAccount u = new UserAccount();
        u.setEmail(request.email().trim().toLowerCase());
        u.setPasswordHash(passwordEncoder.encode(request.password()));
        u.setName(request.name());
        u.setNickname(request.nickname());
        u.setDepartmentId(request.departmentId());
        u.setYear(request.year());
        u.setResponsibilityScore(75);
        if (request.selectedCourseCodes() != null) {
            u.setEnrolledCourses(new java.util.ArrayList<>(request.selectedCourseCodes()));
        }
        userAccountRepository.save(u);
        final String deptName = referenceCatalogService
                .resolveDepartmentName(u.getDepartmentId())
                .orElse(u.getDepartmentId());
        final UserSummaryDto summary = new UserSummaryDto(
                String.valueOf(u.getId()),
                u.getName(),
                u.getNickname(),
                u.getEmail(),
                deptName,
                u.getYear(),
                u.getResponsibilityScore(),
                u.getEnrolledCourses());

        String accessToken = jwtTokenProvider.createAccessTokenForUserId(u.getId());
        String refreshToken = jwtTokenProvider.createRefreshTokenValue();

        return new LoginResponseDto(accessToken, refreshToken, summary);
    }

    /** Refresh token doğrula, rotation, yeni access üret. */
    public LoginResponseDto refresh(String refreshToken) {
        throw new UnsupportedOperationException("TODO: RefreshTokenRepository + JwtTokenProvider rotation");
    }

    public UserSummaryDto getCurrentUser(UserAccount currentUser) {
        final String deptName = referenceCatalogService
                .resolveDepartmentName(currentUser.getDepartmentId())
                .orElse(currentUser.getDepartmentId());

        return new UserSummaryDto(
                String.valueOf(currentUser.getId()),
                currentUser.getName(),
                currentUser.getNickname(),
                currentUser.getEmail(),
                deptName,
                currentUser.getYear(),
                currentUser.getResponsibilityScore(),
                currentUser.getEnrolledCourses());
    }
}
