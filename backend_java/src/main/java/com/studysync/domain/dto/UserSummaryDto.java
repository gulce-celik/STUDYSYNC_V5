/* FILE PURPOSE: API veri tasima modeli (request/response); istemci sozlesmesiyle birebir alanlar. */

package com.studysync.domain.dto;

/**
 * Oturum yanıtındaki kullanıcı özeti — Flutter {@code UserSummary} ile aynı alan adları.
 *
 * <p>{@code department}: görünen isim (ör. "Computer Engineering"); {@code UserAccount#departmentId} katalogdan çözülür.
 */
import java.util.List;

public record UserSummaryDto(
        String id,
        String name,
        String nickname,
        String email,
        String department,
        Integer year,
        Integer responsibilityScore,
        List<String> enrolledCourses) {}
