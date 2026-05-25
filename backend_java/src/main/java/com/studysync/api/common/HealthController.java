/* FILE PURPOSE: HTTP endpoint katmani; request/response sozlesmesini servis katmanina baglar. */

package com.studysync.api.common;

import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * GET /api/v1/health — yük dengeleyici / Docker healthcheck için.
 *
 * <p>İleride: veritabanı ping, disk, bağımlı servisler (ör. Redis) durumu ekleyin.
 */
@RestController
@RequestMapping("/api/v1")
public class HealthController {

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of(
                "success", true,
                "service", "studysync-backend",
                "status", "UP",
                "apiVersion", "2026-05-25",
                "features",
                List.of(
                        "study-buddy-reports",
                        "lost-found",
                        "reservations",
                        "check-in"));
    }
}
