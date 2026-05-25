# STUDYSYNC-IMPLEMENTATION

StudySync is a student study area reservation and campus companion project with:
- Flutter mobile app (`mobile_flutter`)
- Spring Boot REST API (`backend_java`)
- React/Vite reference bundle (`src`, optional)

**Repository:** [github.com/gulce-celik/STUDYSYNC-IMPLEMENTATION](https://github.com/gulce-celik/STUDYSYNC-IMPLEMENTATION)  
**Figma reference:** [Student Study Area Manager](https://www.figma.com/design/KOzCzIz7zAv46CVtT8ibLx/Student-Study-Area-Manager)

---

## Repository Layout

| Path | Purpose |
|------|---------|
| `mobile_flutter/` | Main mobile client (Flutter) |
| `backend_java/` | Spring Boot API (`/api/v1`) |
| `docs/` | API contract + handoff/decision documents |
| `src/` | Legacy/reference React UI (optional) |

---

## Clone

```bash
git clone https://github.com/gulce-celik/STUDYSYNC-IMPLEMENTATION.git
cd STUDYSYNC-IMPLEMENTATION
```

SSH alternative:

```bash
git clone git@github.com:gulce-celik/STUDYSYNC-IMPLEMENTATION.git
```

---

## Prerequisites

- Flutter stable + Dart SDK
- JDK 21
- Maven (or use wrapper scripts in `backend_java`)
- Android Studio (SDK, platform tools, emulator)
- Optional: Node.js (only for `src/` reference web bundle)

Recommended quick checks:

```bash
flutter doctor
java -version
mvn -version
```

---

## Stable Run Guide (Backend + Mobile)  
This section is optimized to avoid emulator freezes/black screen issues during demo use.

### 1) Start backend first

From repository root:

```bash
cd backend_java
mvn spring-boot:run
```

If Maven is not in PATH:

```bash
cd backend_java
./mvnw spring-boot:run
```

Windows PowerShell:

```powershell
cd backend_java
.\mvnw.cmd spring-boot:run
```

Expected:
- Backend runs on `http://localhost:8080`
- API base prefix is `/api/v1`
- H2 in-memory DB is used for development

### 2) Start Android emulator in a stable way

Use Android Studio Device Manager and wait until:
- home screen is fully visible
- device is responsive (not black/frozen)

If emulator becomes unstable, close it and restart it before running Flutter.

### 3) Run Flutter app after emulator is ready

In a second terminal:

```bash
cd mobile_flutter
flutter clean
flutter pub get
flutter devices
flutter run -d emulator-5554
```

Notes:
- Replace `emulator-5554` with your actual device ID from `flutter devices`.
- Android emulator should use `http://10.0.2.2:8080/api/v1` to reach host backend.

---

## Troubleshooting (Freeze / Black Screen / No Render)

### A) Emulator opens but screen stays black
1. Fully close emulator.
2. Kill old adb/emulator processes if needed.
3. Reopen emulator from Device Manager and wait until unlocked home screen appears.
4. Run app again with `flutter run -d <device-id>`.

### B) Flutter build succeeds but UI lags heavily
1. Make sure only one `flutter run` session is active.
2. Stop previous session (`q`) before rerunning.
3. Use a fresh install cycle:

```bash
cd mobile_flutter
flutter clean
flutter pub get
flutter run -d <device-id>
```

### C) App cannot reach backend
Check:
- backend is running on port `8080`
- emulator URL is `10.0.2.2` (not `localhost`) for Android emulator
- no firewall blocks local 8080

For physical devices:

```bash
flutter run --dart-define=API_BASE=http://<YOUR_LAN_IP>:8080/api/v1
```

### D) Stuck after many hot reloads
Use full restart:
- press `R` in Flutter terminal, or
- stop (`q`) and rerun `flutter run`

### E) Study Buddy report — `Could not submit report (HTTP 404)`

The mobile app calls:

`POST {API_BASE}/study-buddies/reports`  
(default: `https://studysync-56nq.onrender.com/api/v1/study-buddies/reports`)

**404 means the live backend does not include that route yet** (not a bad reason/comment). Redeploy the Render backend from latest `main` (needs commit with `POST /study-buddies/reports`), wait until Live, then full-restart the Flutter app.

**Verify deploy:**

```bash
curl -s https://studysync-56nq.onrender.com/api/v1/health
```

Look for `"features"` containing `"study-buddy-reports"`. If missing, redeploy.

**Verify report route (with student JWT):**

```bash
curl -i -X POST "https://studysync-56nq.onrender.com/api/v1/study-buddies/reports" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"reportedUserId\":\"2\",\"reason\":\"test\"}"
```

- **404** → redeploy backend  
- **200** + `"success":false`** → route exists; fix `reportedUserId` (must be numeric `user_accounts.id`, not mock `user-2`)  
- **200** + `"success":true`** → OK; check Neon table `buddy_reports`

**Neon:** create `buddy_reports` if missing (Hibernate `ddl-auto: update` on prod startup, or run SQL from `ImplementationStatus/README.md` §5).

Debug builds log `[StudyBuddy] POST /study-buddies/reports` in the console on submit.

---

## API Base URL Rules

Configured in `mobile_flutter/lib/core/config/app_config.dart`.

- Android emulator: `http://10.0.2.2:8080/api/v1`
- iOS simulator / desktop: usually `http://localhost:8080/api/v1`
- Physical Android: use LAN IP of development machine

---

## Optional: Run Reference Web UI

From repository root:

```bash
npm install
npm run dev
```

This is optional and mainly for visual/reference comparison.

---

## API Contract

Single source of truth for endpoint request/response shapes:
- `docs/api-contract-v1.md`

---

## Implementation Status Report (English)

### Frontend (Flutter) - Current Status

**Implemented**
- Core authentication flow (login/register/onboarding screens)
- Session establishment with backend token/user payload integration
- Home dashboard wiring (dynamic greeting and backend-backed metrics)
- Reservation flow integration (reservation create + error handling paths)
- Schedule screen enhancements (including exam entries)
- Tab state persistence using `IndexedStack` (prevents schedule loss on tab switch)
- Profile improvements (dynamic user info + Figma-aligned sections)
- Global dark mode infrastructure via theme mode controller
- AI suggestion flow scaffolded across Home and Reserve screens
- Localization cleanup for key auth messages in English

**Partially implemented / demo-oriented**
- Some AI suggestion logic is local/controller-driven (not fully backend-personalized ML)
- Some screens still use fallback/mock behavior when backend data is unavailable
- UI parity is high on main flows, but minor typography/spacing refinements may continue

**Known frontend gaps**
- Full end-to-end test coverage is not complete
- Persistent user preferences/theme beyond runtime session can be improved
- Final visual polish pass across all edge states is still recommended

### Backend (Spring Boot) - Current Status

**Implemented**
- Layered structure for API/domain/repository/service/policy
- JWT-based auth flow (token generation + request authentication filter)
- Security configuration with public vs protected endpoint boundaries
- Registration/login services with validation and persistence
- Reservation service core logic + dashboard aggregation
- Reference endpoints and core DTO/mapping structure
- H2 dev setup for local development

**Partially implemented / pending**
- Email verification is currently demo/mocked and not production-grade
- Nickname generation/uniqueness policy is not finalized as backend-owned logic
- Some domain rules are scaffolded and ready for deeper business hardening

**Known backend gaps**
- Production-hardening tasks (mail provider integration, stronger observability, retries)
- More exhaustive integration tests
- Migration from in-memory dev data strategy to persistent production DB setup

### Overall Project Readiness

- **Demo readiness:** strong for core user journeys
- **Collaboration readiness:** repository now includes implementation files and project docs
- **Production readiness:** requires completion of deferred backend items and broader test hardening

---

## Notes for Collaborators

- Generated folders (`build/`, `.dart_tool/`, `target/`, `.gradle/`) are gitignored or machine-specific.
- Clone/pull from GitHub for shared team state; do not rely on private local working folders.
