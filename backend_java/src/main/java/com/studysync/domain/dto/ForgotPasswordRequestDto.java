package com.studysync.domain.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record ForgotPasswordRequestDto(
    @NotBlank(message = "E-posta alanı boş olamaz")
    @Email(message = "Geçersiz e-posta formatı")
    String email
) {}
