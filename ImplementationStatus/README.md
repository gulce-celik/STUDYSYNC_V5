# Implementation Status

Living log of shipped features — what was built, where it lives, how to verify.

**Related:** [cancellation scoring policy](../docs/decision-cancellation-scoring.md) · [api-contract-v1](../docs/api-contract-v1.md)

| Feature | Status | Updated |
|---------|--------|---------|
| Reservation `score` | Done | 2026-05-22 |
| Same-day slot booking | Done | 2026-05-22 |

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

## Changelog

| Date | Change |
|------|--------|
| 2026-05-22 | Reservation `score` — entity, API, History/Profile UI |
| 2026-05-22 | History fix — `resolveScore` + `effectiveScore` |
| 2026-05-22 | Same-day guard — backend validation + Reserve UI |
