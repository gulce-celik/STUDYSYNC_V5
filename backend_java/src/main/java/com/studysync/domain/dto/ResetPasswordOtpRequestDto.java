package com.studysync.domain.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ResetPasswordOtpRequestDto(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 6, max = 6) String otpCode,
    @NotBlank @Size(min = 6) String newPassword
) {}
