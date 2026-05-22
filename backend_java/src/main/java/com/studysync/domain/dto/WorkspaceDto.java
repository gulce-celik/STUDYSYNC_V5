/* FILE PURPOSE: API veri tasima modeli (request/response); istemci sozlesmesiyle birebir alanlar. */

package com.studysync.domain.dto;

/**
 * Haritadaki çalışma birimi — GET /reservations/workspaces.
 *
 * <p>{@code type}: "individual" | "group"; {@code status}: available | occupied vb.; {@code x},{@code y} SVG/Flutter
 * ile aynı koordinat uzayında tutulmalı (mockData ile hizalı).
 */
public record WorkspaceDto(
        String id,
        String type,
        Integer capacity,
        String status,
        Integer x,
        Integer y,
        String qrCode
) {
}
