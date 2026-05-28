# Implementation Status

Living log of shipped features — what was built, where it lives, how to verify.

**Related:** [cancellation scoring policy](../docs/decision-cancellation-scoring.md) · [api-contract-v1](../docs/api-contract-v1.md) · [HANDOFF](../HANDOFF.md)

| Feature | Status | Updated |
|---------|--------|---------|
| Reservation `score` | Done | 2026-05-22 |
| Same-day slot booking | Done | 2026-05-22 |
| No-show auto-cancel (past dates) | Done | 2026-05-22 |
| Lost & Found (backend) | Partial — known bugs | 2026-05-23 |
| Study Buddy reports (backend + mobile POST) | Done — needs Render redeploy if 404 | 2026-05-25 |
| Group invitations (15 min, ACTIVE while pending) | Done | 2026-05-29 |
| Group per-user QR check-in (SR-09) | Done | 2026-05-29 |
| Notifications inbox (backend) | Done | 2026-05-29 |
| Nickname lookup + invitee bookings | Done | 2026-05-29 |

---

## 1. Reservation `score`

Per-reservation responsibility delta (`0` at create; updated on check-in / cancel / no-show). Shown in **My Bookings → History** and **Profile → Score history**.

| Event | `score` |
|-------|---------|
| Create | `0` |
| Check-in (individual) | `+5` (organizer, one scan) |
| Check-in (group) | `+5` per member on first scan; reservation `score` field `+5` when all complete |
| Group no-show | `-10` for **every** required member (organizer + accepted invitees) |
| Cancel ≥24h before slot | `+3` |
| Cancel 1h–24h | `0` |
| Cancel &lt;1h | `-5` |
| No-show | `-10` |

**Backend:** `ReservationRecord.score` (`score_change` column), `ReservationScoringPolicy`, `CancellationScoringPolicy`, `CheckInService`, `ReservationCheckIn`, `AutoCancelReservationJob`, `ReservationMapper.resolveScore` on `GET /reservations/me`.

**Group note:** responsibility score deltas are applied per user via `ResponsibilityScoreService.applyDelta`; the reservation row `score` is still a single summary for History (organizer-centric).

**Flutter:** `ReservationDetail.score`, `effectiveScore` (legacy `0` → infer +5 / -10), `my_bookings_screen`, `profile_screen`.

**Verify:** create → `score: 0`; check-in → `5`; History shows delta (not “no score change”).

```bash
cd backend_java && mvn compile -DskipTests
cd mobile_flutter && flutter test test/reservation_score_test.dart
```

**Out of scope:** wallet `pointsRefunded`, React mock `score`, Java policy unit tests.

---

## 2. Same-day slot booking

Block **today** bookings for slots that already started (campus time `Europe/Istanbul`).

| Case | OK? |
|------|-----|
| Past date | No |
| Future date | Yes (Mon/Fri rules still apply) |
| Today, slot start &gt; now | Yes |
| Today, slot start ≤ now | No |

**Message:** `This time slot has already started. Choose a later slot today or another day.`

**Backend:** `SlotStartTimeResolver.isBookableOnDate`, `ReservationService.createReservation` + `Clock`.

**Flutter:** `CheckInWindow.isSlotBookableForDate`, Reserve dropdown filter, confirm guard, date picker ≥ today.

**Verify:** Reserve → today → past slots hidden; `POST /reservations` with past slot → `400`.

```bash
cd mobile_flutter && flutter test test/slot_booking_window_test.dart
```

**Out of scope:** workspace list filtering, `slot-8` overnight edge cases.

---

## 3. No-show auto-cancel (past dates)

Scheduled job marks unchecked `ACTIVE` / `PENDING` reservations as `NO_SHOW` after the QR grace window closes (slot start + 15 min, campus time).

**Bug fixed:** job only queried **today** and compared `LocalTime`, so missed reservations from earlier days stayed `ACTIVE` forever.

| Before | After |
|--------|-------|
| `findByDateAndStatusIn(today, …)` | `findByDateLessThanEqualAndStatusIn(today, …)` |
| `now` vs slot start time only | `now` vs `LocalDateTime` (date + slot start + 15 min) |

**Backend:** `ReservationRecordRepository.findByDateLessThanEqualAndStatusIn`, `AutoCancelReservationJob` (`SlotStartTimeResolver`, `QrCheckInPolicy.GRACE_AFTER_START_MINUTES`, `GroupCheckInPolicy`), `ResponsibilityScoreService.applyDelta` with `ReservationScoringPolicy.NO_SHOW_SCORE` (`-10`).

**Group:** if not all required members checked in by deadline → `NO_SHOW` and `-10` applied to organizer + every accepted invitee (including members who already checked in).

**Verify:** unit tests cover past-date stale reservations, today before/after deadline, exact deadline boundary, invalid date skip.

```bash
cd backend_java && mvn test -Dtest=AutoCancelReservationJobTest
```

**Out of scope:** `@DataJpaTest` repository query test, manual cron smoke on prod DB.

---

## 4. Lost & Found (backend)

Active reports only on `GET /lost-found`; 24h visibility; `reportedBy` from JWT on POST; scheduled expiry.

| Case | Behavior (intended) |
|------|-------------------|
| `POST` | `reportedBy` = JWT user, `status` = `REPORTED`, DTO includes `reportedByUserId` |
| `GET` | `REPORTED` / `LOST` and `reportedAt + 24h > now`; DTO includes `expiresAt` |
| `PATCH /{id}/found` | Any logged-in user; `FOUND` (rejects expired / already found) |
| After 24h | `ExpireLostItemsJob` deletes stale rows (hidden from GET + map) |

**Backend:** `LostFoundPolicy`, `LostFoundService`, `LostItemMapper`, `LostItemRecordRepository.findByIdWithReporter`, `ExpireLostItemsJob`; reporter resolved with `UserAccountRepository.findById` (not lazy reference).

**Flutter:** `LostFoundApi` → Render `AppConfig.baseUrl` by default; **Found** needs numeric server `id`; POST checks `success`; list reloads after **Found**; debug logs `[LostFound]` in debug builds.

```bash
cd backend_java && mvn test -Dtest=LostFoundServiceTest
```

**Out of scope:** admin L&F moderation UI, photo upload, category picker.

### Known bugs (open)

Reported on device against production (`https://studysync-56nq.onrender.com/api/v1`) — **still failing after** commits `10d86b5`, `0085a82` until Render redeploy + app rebuild are confirmed.

| Bug | Symptom | Likely cause | How to verify |
|-----|---------|--------------|---------------|
| **Found → “not found”** | Tap **Found**; snackbar shows *not found* or `Item not found (id=…) — pull to refresh` | PATCH `id` not in DB (stale list), or **production** still on old build without `findByIdWithReporter` / PATCH route | After report, note list `id`; `PATCH /lost-found/{id}/found` with JWT; check `lost_items.id` in Neon |
| **`reportedByUserId` missing** | New report does not persist / return reporter account id | `reported_by_user_id` null in DB (old schema, failed FK, or deploy lag); JWT user id ≠ row in `user_accounts` | `SELECT id, reported_by_user_id, status FROM lost_items ORDER BY id DESC LIMIT 5`; POST body should include `reportedByUserId` |
| **App vs local backend** | Fixes on `main` don’t change app behavior | Mobile defaults to **Render**, not `localhost` | `flutter run --dart-define=API_BASE=http://10.0.2.2:8080/api/v1` (emulator) or PC LAN IP on physical device |
| **Stale list** | Row visible but Found fails | 24h expiry job removed row; UI not refreshed | Pull to refresh before **Found** |

**Debug checklist**

1. Log out → log in (fresh JWT).
2. Render dashboard → **Manual Deploy** on backend service → wait until Live.
3. `flutter run` (full restart, not hot reload only).
4. Report item → read snackbar / debug console: `[LostFound] POST /lost-found item → id=… reporter=…`.
5. Tap **Found** → if fail, copy full snackbar text and compare `id` to DB.

**Code fixes attempted (on `main`, needs deploy):** reporter `findById`, reload after POST, `findByIdWithReporter` for PATCH, delete-after-24h job, any-user **Found**.

---

## 5. Study Buddy reports (backend)

Persisted student-on-student reports (`buddy_reports` table). Reporter comes from JWT; request body only has `reportedUserId`, `reason`, optional `comment`.

| Endpoint | Role |
|----------|------|
| `POST /study-buddies/reports` | Student submit → `{ success, message, report? }` |
| `GET /admin/buddy-reports` | Admin list — `OPEN` only, newest first |

**Backend:** `BuddyReportRecord`, `BuddyReportService`, `BuddyReportMapper`, `BuddyReportPolicy` (`OPEN` / `DISMISSED` / `RESOLVED`), `StudyBuddyController` + `AdminBuddyReportsController`. Self-report rejected; `reportedUserId` must be numeric user id.

**Flutter:** `StudyBuddyApi.submitReport` → `POST /study-buddies/reports`; **Previous** tab still mirrors successful submits in `BuddyInteractionLog`. Admin list still mock + session until `fetchAdminBuddyReports` parsing lands.

**404 on submit:** production Render not redeployed after backend route shipped — see [README §E](../README.md).

```bash
cd backend_java && mvnw test -Dtest=BuddyReportServiceTest
```

**Out of scope:** dismiss/resolve API, admin role guard, real suggestions matcher, Flutter UI changes.

---

## 6. Group reservation invitations (15 min)

Unanimous accept window for GROUP bookings. Reservation stays **`ACTIVE`** while invites are pending; **`invitesConfirmed`** is computed from invite rows (no new columns on `reservations`).

| Rule | Behavior |
|------|----------|
| Create GROUP | One `ReservationRecord` (organizer `user_id`); one `GroupReservationInvite` per nickname |
| Window | `expiresAt` = `createdAt + 15 minutes` (`GroupInvitationPolicy.INVITE_TTL_MINUTES`) |
| All accept | `invitesConfirmed: true` on `ReservationDetail` |
| Decline or timeout | Reservation → `CANCELLED`, `score = 0`, no responsibility delta |
| Check-in (invite phase) | Blocked until all invites accepted |

| Endpoint | Role |
|----------|------|
| `POST /reservations` (GROUP) | Creates booking + pending invites + `GROUP_INVITATION` notifications |
| `GET /group-invitations/pending` | Invitee home card list |
| `POST /group-invitations/{id}/accept` | Invitee accepts |
| `POST /group-invitations/{id}/decline` | Cancels whole reservation |

**Backend:** `GroupReservationInvite` entity, `GroupInvitationService`, `GroupInvitationController`, `GroupInvitationPolicy`, `ExpireGroupInvitesJob` (every minute); `ReservationDetailDto.expiresAt` / `invitesConfirmed` via `ReservationMapper` + `GroupInviteSummaryDto`; hook in `ReservationService.createReservation`.

**Flutter:** `GroupInvitationsApi`, home screen live accept/decline (replaces mock when API up); `ReservationDetail.awaitingGroupConfirmation`; My Bookings banner; map toast after GROUP create; check-in guard in `CheckInWindow`.

**Dev seed:** Bob’s `group-2` booking includes a pending invite for Alice (`DevDataInitializer`).

```bash
cd backend_java && mvnw test -Dtest=GroupInvitationServiceTest,ReservationServiceTest
```

**Verify:** Bobby creates GROUP with `Alice` + `Chuck` → Alice accepts → Chuck accepts → organizer `GET /reservations/me` shows `invitesConfirmed: true`; decline or wait 15+ min → `CANCELLED`.

**Out of scope:** invitee can cancel; duplicate reservation rows per participant; React web client.

---

## 7. Group per-user QR check-in (SR-09)

After invites are confirmed, **every required member** must scan the workspace QR within the check-in window. One shared `ReservationRecord`; per-user rows in `reservation_check_ins`.

| Rule | Behavior |
|------|----------|
| Who must check in | Organizer + each invitee with `ACCEPTED` status |
| Who can call verify | Logged-in participant only (`AccessDeniedException` otherwise) |
| Per-user scan | Idempotent — second scan: success + “You already checked in.” |
| Partial progress | Reservation stays `ACTIVE`; `groupCheckInDone` / `groupCheckInRequired` on `ReservationDetail` |
| Each first scan | `+5` responsibility score for that user |
| All checked in | Reservation → `COMPLETED` (no extra score on completion) |
| Missed deadline | `NO_SHOW`; `-10` for **all** required members |

| API field | Meaning |
|-----------|---------|
| `ReservationDetail.checkedIn` | Current user has a check-in row |
| `ReservationDetail.groupCheckInDone` | Count of check-ins so far (0 for individual) |
| `ReservationDetail.groupCheckInRequired` | Required headcount (0 for individual) |
| `CheckInResult.completed` | `true` when reservation is fully `COMPLETED` |
| `CheckInResult.checkedInCount` / `requiredCount` | Progress in verify response |

| Endpoint | Role |
|----------|------|
| `POST /checkin/verify` | Record current user’s QR check-in; group stays `ACTIVE` until all in |

**Backend:** `ReservationCheckIn` entity, `ReservationCheckInRepository`, `GroupCheckInPolicy`, `CheckInService` (auth + per-user `+5`), `GroupInvitationService.checkInSummariesFor`, `ReservationDetailDto` extensions, `AutoCancelReservationJob` group branch.

**Flutter:** `ReservationDetail.groupCheckInDone` / `groupCheckInRequired`, `awaitingGroupCheckIns`; `CheckInWindow` disables QR when user already checked in but booking still `ACTIVE`; My Bookings group progress banner; check-in sheet shows partial success without closing until `completed: true`.

```bash
cd backend_java && mvnw test -Dtest=CheckInServiceTest,AutoCancelReservationJobTest
```

**Verify**

1. Organizer creates GROUP; all invitees accept within 15 min.
2. Organizer `POST /checkin/verify` → `success: true`, `completed: false`, message like `1 of 3`; reservation still `ACTIVE`.
3. Each invitee verifies from their account → final member gets `completed: true`, status `COMPLETED`.
4. Alternate: only 2 of 3 check in before slot start + 15 min → job marks `NO_SHOW`; all three users get `-10` on responsibility score.

**Out of scope:** separate reservation row per participant; React web client.

---

## 8. Notifications inbox (backend)

In-app notification rows for group invites (and future event types).

| Endpoint | Role |
|----------|------|
| `GET /notifications` | Current user’s inbox, newest first |
| `PATCH /notifications/{id}/read` | Mark one read |
| `PATCH /notifications/read-all` | Mark all read |

**Backend:** `NotificationRecord`, `NotificationService`, `NotificationController`; `emitGroupInvitation` on invite create (`type` = `GROUP_INVITATION`, `relatedId` = invite id).

**Flutter:** `NotificationsApi` already calls these routes; inbox uses live API when available (404/501 → demo seed).

```bash
cd backend_java && mvnw test
```

**Out of scope:** FCM/push, reservation reminders, moderation events from server.

---

## 9. Nickname lookup & invitee bookings

Group **Add member** validates nicknames before submit; accepted invitees see the shared booking in My Bookings and dashboard upcoming.

| Case | Behavior |
|------|----------|
| `GET /users/by-nickname/{nickname}` | `400` if empty/not found; `UserSummary` if found (case-insensitive) |
| Reserve map **Add** | Flutter calls lookup API; invalid nicknames not added to list |
| `GET /reservations/me` | Organizer **or** invitee with **ACCEPTED** invite (`findVisibleToUser`) |
| Before accept | Invitee sees invite on Home only, not My Bookings |
| Dashboard upcoming | Same visibility rule as My Bookings |

**Backend:** `UserService`, `UserController`; `UserAccountRepository.findByNicknameIgnoreCase`; `ReservationRecordRepository.findVisibleToUser`; used in `ReservationService.myReservations` and `DashboardService.homeForCurrentUser`.

**Flutter:** `users_api.dart`; async `_addNickname()` on `reservation_map_screen` with loading state on **Add**.

```bash
cd backend_java && mvnw test -Dtest=UserServiceTest,ReservationVisibilityTest
```

**Verify:** Add `Nobody` on map → error; add `Alice` → success; Alice accepts invite → `GET /reservations/me` as Alice includes `group-*` booking.

**Out of scope:** invitee cancel.

---

## Backend TODO

Tracked from [HANDOFF.md](../HANDOFF.md) (2026-05-22). Mobile-only work is omitted. Shipped backend work is in sections 1–3 above, not repeated here.

### Auth & account

| | Task | Notes |
|---|------|--------|
| [ ] | `POST /auth/forgot-password` | Mobile screen exists; handles 404/501 today |
| [ ] | `GET /auth/check-email` | Early duplicate-email check on register (409 is too late) |
| [ ] | Email / OTP delivery | Verification and password-reset codes not reaching inboxes |
| [ ] | Refresh token store | Production auth parity (beyond stateless JWT) |
| [x] | KVKK consent field | Persist approval on register / reservation (mobile checkbox is front-only) |
| [ ] | `PUT /auth/me/courses` wiring | Endpoint may exist — ensure profile course edit persists from mobile |

### Reservations & check-in

| | Task | Notes |
|---|------|--------|
| [x] | Desk `qrPayload` on bookings | `WorkspaceQrRegistry`, `GET /reservations/me` |
| [x] | QR check-in window (15 min) | `QrCheckInPolicy`, `POST /checkin/verify`, Istanbul TZ |
| [x] | Group per-user check-in (SR-09) | `ReservationCheckIn`, all members must scan; `-10` all on group no-show — see **§7** |
| [x] | No-show job after grace window | `AutoCancelReservationJob` — includes past-date fix + group incomplete branch |

### Lost & Found

| | Task | Notes |
|---|------|--------|
| [x] | Wire mobile **Found** to `PATCH /lost-found/{id}/found` | `LostFoundApi.markAsFound` + screen handler |
| [x] | Set `reportedBy` on `POST /lost-found` | `@AuthenticationPrincipal` + `findById` reporter (see **§4 known bugs**) |
| [x] | `GET /lost-found` filters + `expiresAt` in DTO | Active open statuses within 24h |
| [x] | Expiry cleanup job | `ExpireLostItemsJob` deletes stale rows |
| [ ] | **Found works end-to-end on prod** | Snackbar *not found* — see **§4 Known bugs** |
| [ ] | **`reportedByUserId` on prod DB** | Reporter id null / not returned — see **§4 Known bugs** |
| [ ] | Confirm Render deploy | `main` pushed; service must redeploy before mobile retest |

### Study Buddy

| | Task | Notes |
|---|------|--------|
| [ ] | Real `StudyBuddyService.getSuggestions` | Replace empty API + mobile sample fallback |
| [x] | Buddy report persistence | `POST /study-buddies/reports`, `GET /admin/buddy-reports`; mobile POST wired |
| [ ] | Buddy report on prod (Render) | Redeploy backend; `GET /health` → `study-buddy-reports` in `features` |
| [x] | Group invitations API | `GroupInvitationController`, mobile `GroupInvitationsApi`, home accept/decline — see **§6** |
| [x] | `GET /users/by-nickname/{nickname}` | `UserController` + map **Add** validation — see **§9** |
| [x] | Invitee bookings after accept | `findVisibleToUser` on `/reservations/me` + dashboard — see **§9** |
| [x] | Group per-user check-in | `CheckInService` + `ReservationCheckIn` — see **§7** |

### Notifications

| | Task | Notes |
|---|------|--------|
| [x] | `GET /notifications` | `NotificationController` — mobile uses live inbox when route exists — see **§8** |
| [x] | `PATCH /notifications/{id}/read` + read-all | Wired — see **§8** |
| [x] | Server event: group invite | `NotificationService.emitGroupInvitation` on invite create |
| [ ] | Server event emitters (other) | Reminder, moderation (push/FCM later per handoff) |

### Admin (`/admin/*`)

| | Task | Notes |
|---|------|--------|
| [ ] | `POST /admin/auth/login` | Staff JWT separate from student |
| [ ] | `GET /admin/dashboard` | KPIs (mobile Overview still mock) |
| [ ] | `GET /admin/students` + detail | Replace mock student list |
| [ ] | `PUT /admin/users/{id}/restrictions` + warn | Persist buddy block / booking cap / warnings |
| [ ] | `PUT /admin/workspaces/{id}/closure` | Desk close/reopen per day |
| [ ] | `PUT /admin/floor-plan` | Desk/group counts + layout sync to `GET /reservations/workspaces` |
| [ ] | `GET/POST/DELETE /admin/staff` | Admin roster grant/revoke |

### Suggested order (backend)

1. **Auth gaps** — forgot-password, check-email, email delivery  
2. **Lost & Found** — PATCH wiring, `reportedBy`, expiry  
3. **Notifications** — inbox API + events  
4. **Study Buddy** — suggestions + reports API  
5. **Admin suite** — auth → dashboard/students → moderation → floor-plan  

```bash
# Smoke after auth/reservation changes
cd backend_java && mvn test
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-05-22 | Reservation `score` — entity, API, History/Profile UI |
| 2026-05-22 | History fix — `resolveScore` + `effectiveScore` |
| 2026-05-22 | Same-day guard — backend validation + Reserve UI |
| 2026-05-22 | No-show job — `date ≤ today` query + `LocalDateTime` deadline; `AutoCancelReservationJobTest` |
| 2026-05-22 | Backend TODO section — from HANDOFF (auth, admin, notifications, L&F, buddy) |
| 2026-05-23 | Lost & Found — `reportedBy`, active GET + `expiresAt`, `ExpireLostItemsJob`, mobile `expiresAt` |
| 2026-05-23 | Lost & Found — §4 **Known bugs**: Found *not found*, `reportedByUserId` missing, Render/deploy checklist |
| 2026-05-24 | KVKK consent persistence — backend entity/DTO validation + Flutter API and session persistence |
| 2026-05-25 | Study Buddy reports — `buddy_reports` entity, POST submit + admin GET OPEN list; `BuddyReportServiceTest` |
| 2026-05-29 | Group invitations — 15 min accept, `ACTIVE` while pending, `ExpireGroupInvitesJob`, notifications, Flutter home + bookings UX |
| 2026-05-29 | Nickname lookup — `GET /users/by-nickname`, map Add validation, `findVisibleToUser` for accepted invitees |
| 2026-05-29 | Group per-user check-in — `ReservationCheckIn`, all members QR verify, `+5` each / `-10` all on group no-show; Flutter progress UX; `CheckInServiceTest` |

