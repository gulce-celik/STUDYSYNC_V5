/* FILE PURPOSE: API veri tasima modeli (request/response); istemci sozlesmesiyle birebir alanlar. */

package com.studysync.domain.dto;

import jakarta.validation.constraints.NotNull;
import java.util.List;

/**
 * PUT /api/v1/auth/me/courses — kullanıcının kayıtlı ders listesini günceller.
 */
public record UpdateCoursesRequestDto(
        @NotNull(message = "courses alanı null olamaz; boş liste gönderilebilir.")
        List<String> courses) {}
