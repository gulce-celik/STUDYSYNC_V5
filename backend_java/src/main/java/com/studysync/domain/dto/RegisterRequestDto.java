/* FILE PURPOSE: API veri tasima modeli (request/response); istemci sozlesmesiyle birebir alanlar. */

package com.studysync.domain.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;

/**
 * Çok adımlı mobil kayıt sihirbazının sunucu birleşik gövdesi (UI ile birebir alan seti).
 *
 * <p><b>Doğrulama:</b> e-posta {@code @std.yeditepe.edu.tr}; şifre politikası; {@code departmentId} katalogda var mı.
 *
 * <p><b>Persist:</b> {@link com.studysync.domain.entity.UserAccount} + seçilen dersler için ilişki tablosu (ileride)
 * veya profil JSON.
 */
public record RegisterRequestDto(
        @NotBlank @Email String email,
        @NotBlank String password,
        @NotBlank String name,
        String nickname,
        String departmentId,
        Integer year,
        List<String> selectedCourseCodes,
        @NotNull @AssertTrue(message = "KVKK notice must be accepted") Boolean kvkkAccepted) {}
