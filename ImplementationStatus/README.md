# Implementation Status

Living log of shipped features — what was built, where it lives, how to verify.

**Related:** [cancellation scoring policy](../docs/decision-cancellation-scoring.md) · [api-contract-v1](../docs/api-contract-v1.md) · [HANDOFF](../HANDOFF.md)

| Feature | Status | Updated |
|---------|--------|---------|
| Reservation `score` | Done | 2026-05-22 |
| Same-day slot booking | Done | 2026-05-22 |
| No-show auto-cancel (past dates) | Done | 2026-05-22 |
| Lost & Found (backend) | Partial — known bugs | 2026-05-23 |

---

## 1. Reservation `score`

Per-reservation responsibility delta (`0` at create; updated on check-in / cancel / no-show). Shown in **My Bookings → History** and **Profile → Score history**.

| Event | `score` |
|-------|---------|
| Create | `0` |
| Check-in | `+5` |
| Cancel ≥24h before slot | `+3` |
| Cancel 1h–24h | `0` |
| Cancel &lt;1h | `-5` |
| No-show | `-10` |

**Backend:** `ReservationRecord.score` (`score_change` column), `ReservationScoringPolicy`, `CancellationScoringPolicy`, `CheckInService`, `AutoCancelReservationJob`, `ReservationMapper.resolveScore` on `GET /reservations/me`.

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

**Backend:** `ReservationRecordRepository.findByDateLessThanEqualAndStatusIn`, `AutoCancelReservationJob` (`SlotStartTimeResolver`, `QrCheckInPolicy.GRACE_AFTER_START_MINUTES`), `ResponsibilityScoreService.applyDelta` with `ReservationScoringPolicy.NO_SHOW_SCORE` (`-10`).

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
| [x] | No-show job after grace window | `AutoCancelReservationJob` — includes past-date fix |

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
| [ ] | Buddy report persistence | `GET/POST /admin/buddy-reports` (mobile logs to session today) |
| [ ] | Group invitations API | Home invite card is still sample data |

### Notifications

| | Task | Notes |
|---|------|--------|
| [ ] | `GET /notifications` | Replace demo inbox (mobile 404 → mock) |
| [ ] | `PATCH /notifications/{id}/read` + read-all | Unread counts |
| [ ] | Server event emitters | Invite, reminder, moderation (push/FCM later per handoff) |

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
