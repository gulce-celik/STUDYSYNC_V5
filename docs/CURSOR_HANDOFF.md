# Cursor / agent handoff (kısa)

**Proje:** StudySync — öğrenci çalışma alanı yönetimi. **Flutter** mobil (`mobile_flutter/`) + **Spring Boot 3.3 / Java 21** API (`backend_java/`).

**Tek sözleşme:** `docs/api-contract-v1.md` — tüm path’ler `/api/v1` önekli; mobil Bearer token (`Authorization`).

**Mobil API adresi:** `mobile_flutter/lib/core/config/app_config.dart`
- Android emülatör: `http://10.0.2.2:8080/api/v1`
- iOS/desktop: `localhost:8080/api/v1`
- Fiziksel cihaz: `--dart-define=API_BASE=http://<PC_LAN_IP>:8080/api/v1`

**Backend:** `application.yml` — H2 in-memory, `ddl-auto: update`, port 8080.
- `config/SecurityConfig.java` — geliştirmede `/api/**` genelde açık; üretimde JWT + kısıtlı uçlar.
- **Login:** hâlâ stub token; gerçek JWT → `security/JwtTokenProvider.java` + `JwtAuthenticationFilter` + `AuthService.login`.
- **Register:** `POST /auth/register` kullanıcıyı DB’ye yazıyor (BCrypt); `AuthService`.
- **Refresh:** `POST /auth/refresh` → şimdilik 501 / TODO.
- İş mantığı: `domain/service/*`, kurallar: `domain/policy/*`, JPA: `domain/entity` + `repository`, JSON: `domain/dto`, map: `domain/mapper`.

**Sonraki mantıklı adımlar:** JWT + Security sıkılaştırma; `ReservationService` / `ScheduleService` tam persist ve UI sözleşmesiyle eşleme; PostgreSQL profili.

**Durum özeti (insan):** `IMPLEMENTATION_STATUS.md` — güncel tutulabilir.
