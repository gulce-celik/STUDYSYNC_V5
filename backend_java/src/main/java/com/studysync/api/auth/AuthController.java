/* FILE PURPOSE: HTTP endpoint katmani; request/response sozlesmesini servis katmanina baglar. */

package com.studysync.api.auth;

import com.studysync.domain.dto.LoginRequestDto;
import com.studysync.domain.dto.LoginResponseDto;
import com.studysync.domain.service.AuthService;
import com.studysync.domain.dto.UserSummaryDto;
import com.studysync.domain.entity.UserAccount;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.ResponseEntity;
import com.studysync.domain.dto.ChangePasswordRequestDto;
import com.studysync.domain.dto.UpdateCoursesRequestDto;

/**
 * HTTP: POST /api/v1/auth/login
 *
 * <p>Mantık: {@link com.studysync.domain.service.AuthService#login(LoginRequestDto)} — JWT ve DB doğrulaması orada tamamlanacak.
 */
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/login")
    public LoginResponseDto login(@Valid @RequestBody LoginRequestDto request) {
        return authService.login(request);
    }

    @GetMapping("/me")
    public UserSummaryDto getMe(@AuthenticationPrincipal UserAccount currentUser) {
        return authService.getCurrentUser(currentUser);
    }

    @PutMapping("/password")
    public ResponseEntity<Void> changePassword(
            @AuthenticationPrincipal UserAccount currentUser,
            @Valid @RequestBody ChangePasswordRequestDto request) {
        authService.changePassword(currentUser, request);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/me/courses")
    public ResponseEntity<Void> updateCourses(
            @AuthenticationPrincipal UserAccount currentUser,
            @Valid @RequestBody UpdateCoursesRequestDto request) {
        authService.updateEnrolledCourses(currentUser, request);
        return ResponseEntity.ok().build();
    }
}
