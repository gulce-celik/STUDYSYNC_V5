/* FILE PURPOSE: Is kurallari ve use-case akislari; controller ve repository arasinda orkestrasyon. */

package com.studysync.domain.service;

import com.studysync.domain.dto.LoginRequestDto;
import com.studysync.domain.dto.LoginResponseDto;
import com.studysync.domain.dto.RegisterRequestDto;
import com.studysync.domain.dto.UpdateCoursesRequestDto;
import com.studysync.domain.dto.UserSummaryDto;
import com.studysync.domain.dto.ChangePasswordRequestDto;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.exception.EmailAlreadyExistsException;
import com.studysync.domain.exception.InvalidCredentialsException;
import com.studysync.domain.exception.InvalidDomainException;
import com.studysync.domain.repository.UserAccountRepository;
import com.studysync.security.JwtTokenProvider;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import com.studysync.domain.entity.PendingRegistration;
import com.studysync.domain.repository.PendingRegistrationRepository;
import com.studysync.domain.dto.ActionResultDto;
import com.studysync.domain.dto.VerifyOtpRequestDto;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

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
    private final PendingRegistrationRepository pendingRegistrationRepository;
    private final EmailService emailService;
    private final SecureRandom secureRandom = new SecureRandom();

    public AuthService(
            UserAccountRepository userAccountRepository,
            ReferenceCatalogService referenceCatalogService,
            PasswordEncoder passwordEncoder,
            JwtTokenProvider jwtTokenProvider,
            PendingRegistrationRepository pendingRegistrationRepository,
            EmailService emailService) {
        this.userAccountRepository = userAccountRepository;
        this.referenceCatalogService = referenceCatalogService;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
        this.pendingRegistrationRepository = pendingRegistrationRepository;
        this.emailService = emailService;
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
                userAccount.getEnrolledCourses(),
                userAccount.isKvkkAccepted());

        return new LoginResponseDto(accessToken, refreshToken, summary);
    }

    @Transactional
    public ActionResultDto register(RegisterRequestDto request) {
        if (userAccountRepository.existsByEmailIgnoreCase(request.email())) {
            throw new EmailAlreadyExistsException(request.email());
        }

        // Antigravity Modification: Hardcoded University domain rule rejection policy mapping.
        if (!request.email().trim().toLowerCase().endsWith("@std.yeditepe.edu.tr")) {
            throw new InvalidDomainException("@std.yeditepe.edu.tr");
        }

        String email = request.email().trim().toLowerCase();
        
        Optional<PendingRegistration> existingPendingOpt = pendingRegistrationRepository.findByEmailIgnoreCase(email);
        PendingRegistration pending;
        if (existingPendingOpt.isPresent()) {
            pending = existingPendingOpt.get();
            // Rate limit check: wait at least 60 seconds before sending another OTP
            if (pending.getCreatedAt().plusSeconds(60).isAfter(LocalDateTime.now())) {
                throw new RuntimeException("Lütfen yeni kod istemeden önce 60 saniye bekleyin."); // 429 logic handled by exception handler ideally
            }
        } else {
            pending = new PendingRegistration();
        }

        pending.setEmail(email);
        pending.setPasswordHash(passwordEncoder.encode(request.password()));
        pending.setName(request.name());
        pending.setNickname(request.nickname());
        pending.setDepartmentId(request.departmentId());
        pending.setYear(request.year());
        pending.setKvkkAccepted(request.kvkkAccepted());
        if (request.selectedCourseCodes() != null) {
            pending.setEnrolledCourses(new java.util.ArrayList<>(request.selectedCourseCodes()));
        }

        // Generate 6-digit OTP
        String otp = String.format("%06d", secureRandom.nextInt(1000000));
        pending.setOtpCode(otp);
        pending.setCreatedAt(LocalDateTime.now());
        pending.setExpiresAt(LocalDateTime.now().plusMinutes(5));
        pending.setAttempts(0);

        pending.setVerified(false);

        pendingRegistrationRepository.save(pending);
        emailService.sendOtpEmail(email, otp);

        return new ActionResultDto(true, "Doğrulama kodu e-posta adresinize gönderildi.", null, null);
    }

    @Transactional
    public ActionResultDto verifyOtp(VerifyOtpRequestDto request) {
        String email = request.email().trim().toLowerCase();
        PendingRegistration pending = pendingRegistrationRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new RuntimeException("Bekleyen kayıt bulunamadı."));

        if (pending.getAttempts() >= 3) {
            pending.setExpiresAt(LocalDateTime.now()); // Expire immediately
            pendingRegistrationRepository.save(pending);
            throw new RuntimeException("Çok fazla hatalı deneme yaptınız. Lütfen yeni kod isteyin.");
        }

        if (pending.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("Doğrulama kodunun süresi dolmuş. Lütfen yeni kod isteyin.");
        }

        if (!pending.getOtpCode().equals(request.otpCode())) {
            pending.setAttempts(pending.getAttempts() + 1);
            pendingRegistrationRepository.save(pending);
            throw new RuntimeException("Geçersiz doğrulama kodu.");
        }

        pending.setVerified(true);
        pendingRegistrationRepository.save(pending);
        
        return new ActionResultDto(true, "E-posta doğrulandı.", null, null);
    }

    @Transactional
    public LoginResponseDto registerComplete(RegisterRequestDto request) {
        String email = request.email().trim().toLowerCase();
        PendingRegistration pending = pendingRegistrationRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new RuntimeException("Bekleyen kayıt bulunamadı."));

        if (!pending.isVerified()) {
            throw new RuntimeException("Lütfen önce e-posta adresinizi doğrulayın.");
        }

        // OTP Validated! Move to UserAccount
        UserAccount u = new UserAccount();
        u.setEmail(pending.getEmail());
        u.setPasswordHash(pending.getPasswordHash());
        u.setName(pending.getName());
        u.setNickname(request.nickname());
        u.setDepartmentId(request.departmentId());
        u.setYear(request.year());
        u.setResponsibilityScore(75);
        u.setKvkkAccepted(request.kvkkAccepted());
        if (request.selectedCourseCodes() != null) {
            u.setEnrolledCourses(new java.util.ArrayList<>(request.selectedCourseCodes()));
        }
        
        userAccountRepository.save(u);
        pendingRegistrationRepository.delete(pending);

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
                u.getEnrolledCourses(),
                u.isKvkkAccepted());

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
                currentUser.getEnrolledCourses(),
                currentUser.isKvkkAccepted());
    }

    @Transactional
    public void changePassword(UserAccount currentUser, ChangePasswordRequestDto request) {
        if (!passwordEncoder.matches(request.currentPassword(), currentUser.getPasswordHash())) {
            throw new InvalidCredentialsException(); // Can reuse or create new exception
        }
        currentUser.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        userAccountRepository.save(currentUser);
    }

    @Transactional
    public void updateEnrolledCourses(UserAccount currentUser, UpdateCoursesRequestDto request) {
        // @AuthenticationPrincipal ile gelen nesne detached olabilir;
        // veritabanından managed entity yükleyerek Hibernate takibini garanti ediyoruz.
        UserAccount managed = userAccountRepository.findById(currentUser.getId())
                .orElseThrow(() -> new RuntimeException("User not found: " + currentUser.getId()));
        
        List<String> incoming = request.courses() != null ? request.courses() : List.of();
        managed.getEnrolledCourses().clear();
        managed.getEnrolledCourses().addAll(incoming);
        
        userAccountRepository.saveAndFlush(managed);
    }
}
