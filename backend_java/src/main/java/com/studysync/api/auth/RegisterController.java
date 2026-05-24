/* FILE PURPOSE: HTTP endpoint katmani; request/response sozlesmesini servis katmanina baglar. */

package com.studysync.api.auth;

import com.studysync.domain.dto.ActionResultDto;
import com.studysync.domain.dto.VerifyOtpRequestDto;
import com.studysync.domain.dto.LoginResponseDto;
import com.studysync.domain.dto.RegisterRequestDto;
import com.studysync.domain.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * {@code POST /api/v1/auth/register} — çok adımlı mobil kayıt sihirbazının sunucu ucu.
 *
 * <p>Mantık: {@link com.studysync.domain.service.AuthService#register(RegisterRequestDto)}.
 */
@RestController
@RequestMapping("/api/v1/auth")
public class RegisterController {

    private final AuthService authService;

    public RegisterController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register-init")
    public ActionResultDto registerInit(@Valid @RequestBody RegisterRequestDto body) {
        return authService.register(body);
    }

    @PostMapping("/verify-otp")
    public ActionResultDto verifyOtp(@Valid @RequestBody VerifyOtpRequestDto body) {
        return authService.verifyOtp(body);
    }

    @PostMapping("/register-complete")
    public LoginResponseDto registerComplete(@Valid @RequestBody RegisterRequestDto body) {
        return authService.registerComplete(body);
    }
}
