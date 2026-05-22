/* FILE PURPOSE: Uygulama konfigurasyonu (CORS, security, zaman vb.) ve runtime davranisi ayarlari. */

package com.studysync.config;

import java.time.Clock;
import java.time.ZoneId;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Campus slot times use {@link #CAMPUS_ZONE} (Yeditepe / Istanbul), not UTC on cloud hosts. */
@Configuration
public class TimeConfig {

    public static final ZoneId CAMPUS_ZONE = ZoneId.of("Europe/Istanbul");

    @Bean
    public Clock clock() {
        return Clock.system(CAMPUS_ZONE);
    }
}
