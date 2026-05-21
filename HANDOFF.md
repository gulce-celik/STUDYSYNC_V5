# Project Handoff & Issue Tracker

## 🏗️ Architecture & Technical Notes

- **Project:** StudySync — Student workspace management. Consists of a **Flutter** mobile app (`mobile_flutter/`) and a **Spring Boot 3.3 / Java 21** API (`backend_java/`).
- **API Contract:** Single source of truth is `docs/api-contract-v1.md`. All paths are prefixed with `/api/v1` and use Bearer tokens (`Authorization`) for mobile.
- **Mobile API Configuration:** Configured in `mobile_flutter/lib/core/config/app_config.dart`.
  - Android emulator: `http://10.0.2.2:8080/api/v1`
  - iOS/desktop: `localhost:8080/api/v1`
  - Physical device: `--dart-define=API_BASE=http://<PC_LAN_IP>:8080/api/v1`
- **Backend Setup:**
  - Uses `application.yml` with H2 in-memory database (`ddl-auto: update`), running on port 8080.
  - Security (`config/SecurityConfig.java`) is mostly open for `/api/**` during development, but requires JWT and restricted endpoints for production.

## 🐛 Bug Fixes & Current Issues

- [ ] **Password Change:** Password change process works, but the error screen continues to show in the background.
- [X] **Course Edit:** The course edit function is not working.
- [ ] **Check-in System:** Check-in can be done at any time. **Rule:** If check-in is not completed within the first 15 minutes, the reservation must be automatically canceled.
- [ ] **Email Verification/Delivery:** Emails containing verification/password codes are not being delivered.
- [ ] **Duplicate Email Registration:** The check for accounts with the same email is done too late. (Should be validated earlier / on the frontend).

## 🚀 New Features & Enhancements

- [ ] **Lost Item Found:** Add a reporting/marking feature for when a "Lost item" is found.
- [ ] **KVKK (GDPR/Privacy Policy) Approval:** Add a KVKK approval step to the registration or reservation process.
- [ ] **Forgot Password:** The "Forgot password" flow is currently missing and needs to be added.
- [ ] **Buddy / "Previous" Tab:** Add a reporting feature via the "Previous" tab in the Buddy system (Users should be able to write comments).
- [ ] **Admin Panel:** Implement an admin interface for managing reservations, users, and course data.

## ❓ Questions & Open Topics

- [ ] **Notification System:** In-app inbox added on mobile (demo + API-ready); push/FCM and server events still missing — see work log 2026-05-16/2026-05-17.

------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------

## Frontend work log (mobile_flutter only)

### 2026-05-21 (Live Deployment & Shared DB)

**Infrastructure & Backend (`backend_java/`)**
- **Production Database:** Transitioned from strictly local H2 to a live **Neon.tech** PostgreSQL database for team testing.
- **Spring Profiles:** Added `dev` (H2) and `prod` (PostgreSQL) profiles in `application.yml`. Added `@Profile("dev")` to `DevDataInitializer` so fake data is not injected into the live production database.
- **Dockerization:** Added multi-stage `Dockerfile` (JDK 21 build -> JRE runtime) and `.dockerignore` for Render.com deployment.
- **Live Deployment:** Successfully deployed the backend to Render.com free tier. Live API base URL: `https://studysync-56nq.onrender.com/api/v1`.

**Mobile (`mobile_flutter/`)**
- **Permanent Live Server (Team Shared DB):** Modified `app_config.dart` to always return the `_productionUrl` regardless of `kDebugMode`. This allows the 7-person team to share the central Neon database and see each other's actions during development.
- **Cold Start Timeout Fix:** Increased `connectTimeout` and `receiveTimeout` in `api_client.dart` from 12s to 60s. This is critical to prevent "Cannot reach backend" errors when Render's free tier spins down and takes ~50 seconds to wake up upon the first request.

------------------------------------------------------------------------------

### 2026-05-16 - 2026-05-17 — Summary

**Frontend (done, `mobile_flutter/` only)**  
- **Admin:** Staff login + shell (Overview / Students / Booking / Reports / Admins), navy `AdminUi`, English live/mock banner, JWT bridge for live map, student detail + warn/restrict (3 kinds, session), desk heatmap + tap-to-close, map layout sliders + mini preview, reports merge `BuddyInteractionLog`, Admins roster grant/revoke.  
- **Routing:** `app.dart` → `AdminShell` when `isAdminSession`; student `login_screen.dart` → “Staff admin portal”.  
- **Student:** Reserve map follows admin layout counts; map label / clip fixes.  
- **Notifications:** Home bell + inbox (`notifications_api` + controller); demo invite + reminder (no waitlist); mark read / mark all; refresh on login, clear on logout; admin warn sync by email; Home accept/reject removes invite from inbox.  
- **Fixes:** Admin restrict sheet dispose crash; Admins list sort on unmodifiable list.  
- **No Java changes** in this session.

**Backend (still needed)**  
- **Admin APIs:** staff auth, dashboard KPIs, student list, buddy reports, persist restrictions/warnings, floor-plan (desk/group counts), workspace closures.  
- **Notifications:** `GET /notifications` + mark-read + server events (invite, reminder, moderation).  
- **Existing gaps (unchanged):** forgot-password, lost-found PATCH found, profile/courses persist, `qrPayload` on bookings, email/OTP, 15-min no-show job.

*Session detail: see ### 2026-05-17 below.*

> Notes below this line are added per session. Older items above are unchanged for history.
> Backend (`backend_java/`) was not modified unless explicitly noted.

### 2026-05-16

- **Password change UI (Profile):** Refactored the change-password bottom sheet so validation and API errors render **inside the sheet** (inline text), not via `SnackBar` on the parent screen (which appeared behind the modal). Added loading state on Save, close button, and success `SnackBar` only after the sheet closes. File: `mobile_flutter/lib/features/profile/presentation/profile_screen.dart`. Uses existing `PUT /auth/password` — no backend changes.

- **QR check-in (My Bookings + Home):** Replaced demo “Mark as Checked-In” with `POST /checkin/verify` via shared `showReservationCheckInSheet` + `CheckInApi`. Inline errors/loading on sheet; refreshes bookings/dashboard after success. Client hints: reservation must be **today**, 15-minute window warning (server still owns final rules). Offline mock list disables check-in with a clear message. Tests: `mobile_flutter/test/check_in_window_test.dart`. **Backend not changed.** Note for E2E: `ReservationDetailDto` does not yet expose `qrPayload` on `GET /reservations/me` — users may need to paste QR manually until backend adds that field (ask backend owner before changing Java).

- **Course edit (Profile):** “Edit” under My Courses now opens `edit_enrolled_courses_sheet.dart` (multi-select, `GET /courses` with catalog fallback). Saves to `AuthSession.enrolledCourseCodes` for reservation/buddy filters this session. Removed wrong navigation to Weekly Schedule. Server persistence still needs a future profile API — no backend change.

- **Register duplicate email (UX):** On HTTP 409 at final step, wizard returns to step 1 with inline email error (not only toast). Step 1 adds “Already registered? Sign in”. Auto-login on 409+matching password kept. No new backend endpoint.

- **Forgot password (Login):** Full-screen `forgot_password_screen.dart` (Login gradient + card; back arrow). `AuthApi.requestPasswordReset` → `POST /auth/forgot-password` (404/501 → “not enabled yet”). Removed bottom sheet. Shared `auth_email_utils.dart`. **Backend:** route may still be missing.

- **KVKK consent (Register step 5):** Checkbox + privacy dialog required before “Complete Registration”. Front-only legal placeholder text. No backend field yet.

- **Study Buddy — Previous tab:** Find / Previous chips; report dialog with reason + optional comment → `BuddyInteractionLog` (session only until moderation API). Sample buddy rows when `GET /study-buddies/suggestions` empty/offline (`StudyBuddyMockData`, names Emre / Gülce / Efe).

- **Home — group invitations (UI sample):** When dashboard API succeeds, shows mock invitation card (Emre invited, Gülce/Efe preview) — no invitations API yet. Fake group invitations removed only in the sense of not mixing old static mock with API score; card is still front sample data.

- **Lost & Found (backend-connected):**
  - List: `GET /lost-found`; report: `POST /lost-found`.
  - **Found** button: session-only UI until `PATCH /lost-found/{id}/found`.
  - **Maps (Reserve + Lost & Found):** markers only from API (`LostFoundMapSync` refresh after report); removed hard-coded desk-8 / group-2 mock on reserve map.
  - **List:** no fake rows when API returns `[]` (only “Sample only — offline” if server unreachable).
  - **LostMapBadge:** larger yellow warning icon on maps + legend copy updated.

- **Demo login removed (2026-05-16 correction):** Deleted `DemoLoginPanel`, `demo_accounts`, `demo_live_data_service`. Login is normal email/password only.

- **Tests (mobile):** `check_in_window_test.dart`, `auth_email_utils_test.dart`, `auth_session_courses_test.dart`, `widget_test.dart`, `admin_email_utils_test.dart`.

- **Admin console (mobile — front only):** Separate staff flow from student app.
  - Login → **Staff admin portal** → `admin_login_screen.dart` (`@yeditepe.edu.tr` only, **not** `@std.`; email must be in `AdminAllowlist`).
  - Demo admins: `gulce@yeditepe.edu.tr`, `admin@yeditepe.edu.tr`, `emre@yeditepe.edu.tr` / `Admin123!`.
  - After admin login → `AdminShell` (Overview, Students, Campus, Reports) — student `BottomNavShell` unchanged.
  - **Overview:** KPI cards + low responsibility score list.
  - **Students:** searchable list → detail → warn / restrict (session `AdminModerationStore`).
  - **Campus → Booking (2026-05-17):** heatmap, closures, map layout sliders + preview; see **2026-05-17** log for live/mock split.
  - **Reports:** Study Buddy reports (seed + live `BuddyInteractionLog` from student app on same device).
  - **Admins tab (2026-05-17):** session roster grant/revoke.
  - **Backend not implemented** — needs `/admin/*` APIs + real auth (details in 2026-05-17 table).

### 2026-05-17 (admin polish, live/mock data, notifications, map preview)

> All items below are **mobile_flutter only** unless noted. `backend_java/` not modified.

#### Admin app (staff console)

| Change | Files | Backend today | Backend needed |
|--------|-------|---------------|----------------|
| Staff login (allowlist `@yeditepe.edu.tr`, demo passwords) | `lib/core/admin/admin_allowlist.dart`, `admin_roster_store.dart`, `lib/features/admin/presentation/admin_login_screen.dart` | No `/admin/auth/login` | `POST /admin/auth/login` (staff JWT, separate from student) |
| Admin session + optional API token (student **bridge** login for JWT when staff signs in) | `lib/core/auth/auth_controller.dart` (`establishAdminSession`), `lib/features/admin/data/admin_api.dart`, `admin_repository.dart`, `admin_data_controller.dart` | Student `POST /auth/login` only | Dedicated admin auth; stop relying on alice bridge in prod |
| Shell tabs: Overview, Students, **Booking** (was Campus), Reports, **Admins** | `admin_shell.dart`, `admin_dashboard_screen.dart`, `admin_students_screen.dart`, `admin_booking_screen.dart`, `admin_reports_screen.dart`, `admin_admins_screen.dart` | — | — |
| App routes admin vs student | `lib/app.dart` | — | — |
| Student login link to staff portal | `lib/features/auth/presentation/login_screen.dart` | — | — |
| Shared admin email normalize/validate | `lib/core/admin/admin_email_utils.dart` | — | — |
| Navy admin theme (cards, charts, KPIs) | `widgets/admin_ui.dart` | — | — |
| Probe `/admin/*` (404 → mock) + merge live workspaces | `admin_api.dart`, `admin_data_controller.dart` | Student JWT endpoints only | Real admin routes |
| Reports: seed + live buddy reports from device session | `admin_reports_screen.dart`, `admin_reports_repository.dart`, `core/demo/buddy_interaction_log.dart` | Session log only | `GET/POST /admin/buddy-reports` |
| Restriction picker sheet (buddy / bookings / weekly cap) | `widgets/admin_restrict_sheet.dart`, `widgets/admin_workspace_closure_sheet.dart` | — | — |
| Logout clears admin data (no duplicate shell push) | `admin_shell.dart`, `admin_data_controller.dart` (`clear`) | — | — |
| Live vs mock **banner** (English) + Refresh | `admin_repository.dart` (`sourceLabel`), `widgets/admin_data_source_banner.dart` | Partial: `GET /reservations/workspaces`, `GET /lost-found` work with JWT | `GET /admin/dashboard`, `GET /admin/students`, `GET /admin/buddy-reports`; banner should reflect real fields |
| **Green banner ≠ all live:** desk map + lost-found from server; student list, buddy reports, some KPIs still mock | `admin_data_controller.dart`, `admin_mock_data.dart` | As above | Admin list/report endpoints |
| Booking pulse donut readable on navy card | `widgets/admin_ui.dart` (`AdminDonutStat.onDarkBackground`), `admin_dashboard_screen.dart` | — | — |
| Student detail UI (hero, stats, moderation) | `admin_student_detail_screen.dart`, `widgets/admin_ui.dart`, `admin_restrict_sheet.dart`, `admin_restriction_chips.dart` | — | `POST` warn/restrict per user; persist restrictions |
| Moderation session store (warn, buddy block, no bookings, weekly cap) | `admin_moderation_store.dart`, `domain/admin_restriction.dart` | In-memory only | `PUT /admin/users/{id}/restrictions`, audit log |
| Desk heatmap + **close/reopen** workspace per day | `admin_booking_screen.dart`, `admin_workspace_closure_store.dart` | Session only | `PUT /admin/workspaces/{id}/closure` or floor-plan API |
| **Map layout** sliders (4–40 desks, 0–8 group rooms) → student Reserve map | `widgets/admin_map_layout_card.dart`, `lib/core/campus/campus_layout_store.dart`, `campus_layout_generator.dart` | Client-only layout | `PUT /admin/floor-plan` (counts + coordinates); sync to `GET /reservations/workspaces` |
| **Map layout preview** (mini grid, updates with sliders) | `widgets/admin_map_layout_preview.dart` | — | Same floor-plan API when server owns layout |
| Weekly bar chart, KPI cards | `admin_dashboard_screen.dart`, `widgets/admin_ui.dart` | Mock KPIs | `GET /admin/dashboard` |
| Grant/revoke admin (session roster) | `admin_admins_screen.dart`, `admin_roster_store.dart` | — | `GET/POST/DELETE /admin/staff` |
| Admins list crash fix (`List.from` before sort) | `admin_admins_screen.dart` | — | — |

#### Student app (same session)

| Change | Files | Backend today | Backend needed |
|--------|-------|---------------|----------------|
| Reserve map layout follows admin counts | `reservation_map_screen.dart`, `reservation_mock_data.dart`, `CampusLayoutStore` listener | Workspaces from API may ignore admin grid until merged | Floor-plan endpoint + workspace positions in API response |
| Map label fixes (group room text, clip) | `reservation_map_screen.dart` | — | — |
| Admin restrict sheet crash fix (`TextEditingController` dispose) | `admin_restrict_sheet.dart` → `_RestrictSheetBody` | — | — |

#### In-app notifications (not push)

| Change | Files | Backend today | Backend needed |
|--------|-------|---------------|----------------|
| Bell on Home + unread badge | `home_screen.dart`, `notifications/presentation/widgets/notification_bell_button.dart` | — | — |
| API client for inbox | `notifications/data/notifications_api.dart` | 404 → demo | `GET` + `PATCH` routes |
| Refresh inbox after student login | `auth_controller.dart` (`establishSession`) | — | — |
| Accept/reject group invite removes related notification | `home_screen.dart` (`removeByRelatedId`) | — | Real invitations API |
| Notifications screen (mark read, pull refresh) | `notifications/presentation/notifications_screen.dart` | No `GET /notifications` (404 → demo) | `GET /notifications`, `PATCH /notifications/{id}/read`, `PATCH /notifications/read-all` |
| Demo inbox: group invite + reservation reminder ( **no waitlist** ) | `notifications/data/notifications_controller.dart`, `domain/app_notification.dart` | — | Event types: invitation, reminder, moderation (SR-27 waitlist/extension later) |
| Admin warn/restrict → student inbox if email matches demo student row | `notifications_controller.dart` (`_mergeModerationForCurrentUser`), `admin_moderation_store.dart` | — | Server pushes notification rows on moderation actions |
| Clear inbox on logout | `auth_controller.dart` | — | — |
| Test | `test/notifications_test.dart` | — | — |

**Clarification:** Black bars at bottom = Flutter **SnackBar** (toast), not the notification inbox.

### Frontend status vs original checklist (top of file)

| Original item | Mobile status |
|---------------|---------------|
| Password change background error | **Done** (inline in sheet) |
| Course edit | **Partial** (session `AuthSession`; no profile PUT) |
| Check-in 15 min / auto-cancel | **Partial** (API verify + client window; cancel = backend) |
| Email delivery / OTP | **Not done** (register OTP still client demo) |
| Duplicate email early | **Partial** (409 → step 1; no `check-email` API) |
| Lost item found | **Partial** (Found UI; PATCH backend) |
| KVKK | **Partial** (register only) |
| Forgot password | **Done UI** (API may 404) |
| Buddy Previous + comments | **Partial** (session log) |
| Admin panel | **Partial** (full mobile admin UI + live desk map/lost-found; students/reports/KPIs mock) |
| Notifications | **Partial** (in-app inbox + bell; no push/FCM; no `GET /notifications` on server) |

> Checkboxes at the top are **historical**; use this table + work log for current state.

### Live demo runbook (present to audience)

1. Start Spring Boot on **8080** (optional seed: `alice.student@std.yeditepe.edu.tr` / `Password123!` for bookings).
2. Run Flutter on emulator (`10.0.2.2:8080/api/v1`).
3. **Register** or **Login** (no demo chips).
4. **Home** → sample group invite; **Study Buddy** → search (sample if API empty); **Lost & Found** → Report Item → see list + **Reserve** map markers.

### Backend dependencies (do not change Java without owner approval)

| Need | Why |
|------|-----|
| **Admin:** `POST /admin/auth/login`, `GET /admin/dashboard`, `GET /admin/students`, `GET/POST /admin/buddy-reports`, `PUT /admin/floor-plan`, workspace closures, user restrictions/warnings | Replace mock admin data + session-only moderation/layout |
| **Notifications:** `GET /notifications`, mark-read, server event emitters (invite, reminder, moderation; waitlist later per SR-28) | Replace demo inbox; enable real unread counts |
| `qrPayload` on `GET /reservations/me` | QR check-in without manual paste |
| `POST /auth/forgot-password` | Forgot-password screen (handles 404/501 today) |
| `PATCH /lost-found/{id}/found` | Persist “Found”; hide map marker |
| `GET /lost-found` filter / `expiresAt` | Optional: active-only list, 24h policy |
| Set `reportedBy` on `POST /lost-found` | JWT user on report |
| `StudyBuddyService.getSuggestions` | Real buddy matches instead of sample fallback |
| Profile PUT for `enrolledCourseCodes` | Persist course edit from profile |
| `GET /auth/check-email` | Early duplicate email on register |
| Email delivery + refresh token store + 15-min no-show job | Production parity |

### Lost & Found — backend today vs missing

| Have (Java) | Missing |
|-------------|---------|
| `GET /lost-found`, `POST /lost-found` | `PATCH` mark FOUND |
| Entity `status`, `category`, `reportedBy` field | `reportedBy` not set on POST |
| H2 persistence in dev | 24h expiry job, `expiresAt` in DTO |
