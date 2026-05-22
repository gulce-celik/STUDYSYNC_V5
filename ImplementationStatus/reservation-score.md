# Reservation `score` — Implementation Status

**Status:** Done  
**Date:** 2026-05-22  
**Policy:** [docs/decision-cancellation-scoring.md](../docs/decision-cancellation-scoring.md)

---

## Goal

Add a **`score`** field on each reservation: **`0` at create**, updated on **check-in**, **cancel**, or **no-show** per cancellation/scoring policy. Show that value in **My Bookings → History** and **Profile → Score history** (no client-side guesswork).

---

## What was implemented

### Backend (source of truth)

| Item | Done | Notes |
|------|------|-------|
| `ReservationRecord.score` (`int`, default `0`, DB column `score_change`) | Yes | |
| `ReservationDetailDto.score` in API | Yes | Replaces nullable `scoreChange` on detail DTO |
| `ReservationScoringPolicy` (+5 check-in, -10 no-show, 0 initial) | Yes | New class |
| `CancellationScoringPolicy` (+3 / 0 / -5 windows) | Yes | Existing; wired to `score` |
| Create → `setScore(0)` | Yes | |
| Check-in → `setScore(5)`, `COMPLETED` | Yes | `CheckInService` |
| Cancel → `setScore` from policy | Yes | |
| Cancel without body → campus `Clock` + `SlotStartTimeResolver` | Yes | Audit fix |
| No-show job → `setScore(-10)`, `NO_SHOW` | Yes | `AutoCancelReservationJob` |
| User responsibility via `ResponsibilityScoreService` | Yes | On non-zero deltas |
| `mvn compile` | Pass | |

### Mobile (Flutter)

| Item | Done | Notes |
|------|------|-------|
| `ReservationDetail.score` from API | Yes | Fallback parse: `scoreChange`, `score_change` |
| **My Bookings → History** badge uses `r.score` | Yes | Only on History tab; `showsHistoryScoreBadge` |
| **Profile → Score history** uses `r.score` | Yes | `ProfileScoreEntry.score`; same badge rules |
| Removed client fallbacks (+5 / -10 when `score == 0`) | Yes | Trust backend `score` |
| `reservation_score_test.dart` | Pass | 4 tests |

### Documentation

| File | Purpose |
|------|---------|
| [docs/implementation-report-reservation-score.md](../docs/implementation-report-reservation-score.md) | Full report + audit |
| [docs/api-contract-v1.md](../docs/api-contract-v1.md) | `ReservationDetail.score` documented |
| `ImplementationStatus/` (this folder) | Status index |

---

## Score values (reference)

| Event | `score` |
|-------|---------|
| Create | `0` |
| Check-in success | `+5` |
| Cancel ≥ 24h before slot | `+3` |
| Cancel 1h–24h before slot | `0` |
| Cancel &lt; 1h before slot | `-5` |
| No-show (15 min after slot start) | `-10` |

---

## Key files

**Backend**

- `backend_java/.../entity/ReservationRecord.java`
- `backend_java/.../dto/ReservationDetailDto.java`
- `backend_java/.../policy/ReservationScoringPolicy.java`
- `backend_java/.../policy/CancellationScoringPolicy.java`
- `backend_java/.../service/ReservationService.java`
- `backend_java/.../service/CheckInService.java`
- `backend_java/.../job/AutoCancelReservationJob.java`
- `backend_java/.../mapper/ReservationMapper.java`

**Flutter**

- `mobile_flutter/lib/features/reservation/domain/reservation_models.dart`
- `mobile_flutter/lib/features/reservation/domain/reservation_detail_score.dart`
- `mobile_flutter/lib/shared/reservations/reservation_score.dart`
- `mobile_flutter/lib/features/reservations/presentation/my_bookings_screen.dart`
- `mobile_flutter/lib/features/profile/presentation/profile_screen.dart`
- `mobile_flutter/lib/features/profile/data/profile_mock_data.dart`
- `mobile_flutter/test/reservation_score_test.dart`

---

## UI behavior

- **Active bookings:** `score` is `0`; no score badge.
- **History (bookings + profile):** Show badge when terminal and (`score != 0` **or** `CANCELLED` with `score == 0`).
- **Colors:** green `> 0`, red `< 0`, grey `0` on cancel.

---

## Not done / out of scope

- Points refund (`pointsRefunded`) enforcement on a wallet
- React `src/` `Reservation` mock type — no `score` field
- Java unit tests for `CancellationScoringPolicy`
- Home dashboard `ScoreHistoryEntryDto` still named `scoreChange` (same numeric meaning)

---

## How to verify

1. Start backend + mobile (see [README.md](../README.md)).
2. Create reservation → `GET /reservations/me` → `"score": 0`.
3. Check-in → `score: 5`, status `COMPLETED`.
4. Cancel with app (sends times) → `+3`, `0`, or `-5` per timing.
5. **My Bookings → History** and **Profile → Score history** show the same `score` values.

```bash
cd backend_java && mvn compile -DskipTests
cd mobile_flutter && flutter test test/reservation_score_test.dart
```

---

## Changelog (this feature)

| Date | Change |
|------|--------|
| 2026-05-22 | Initial `score` on entity, DTO, services, job |
| 2026-05-22 | Backend cancel: auto `cancelledAt` / `slotStartAt` when body empty |
| 2026-05-22 | My Bookings History: display `r.score` only |
| 2026-05-22 | Profile score history: `ProfileScoreEntry.score` from `r.score` |
