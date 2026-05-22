/* FILE PURPOSE: Spring Boot uygulama giris noktasi; bean tarama ve uygulama baslatma. */

package com.studysync;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Spring Boot giriş noktası.
 *
 * <p>İleride: {@code @EnableScheduling} (süresi dolan kayıp eşya, hatırlatıcılar),
 * {@code @EnableMethodSecurity} veya Spring Security yapılandırması.
 */
@SpringBootApplication
@EnableScheduling
public class StudySyncApplication {
    public static void main(String[] args) {
        SpringApplication.run(StudySyncApplication.class, args);
    }
}
