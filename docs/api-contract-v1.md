# StudySync API Contract v1 (Skeleton)

This document keeps Flutter and Java implementations aligned from day one.
All endpoints are prefixed with `/api/v1`.

**Flutter client base URL** (see `mobile_flutter/lib/core/config/app_config.dart`):
default is `http://localhost:8080/api/v1` on iOS simulator / desktop; on **Android emulator** use `http://10.0.2.2:8080/api/v1` (already the default there). Override anytime with `--dart-define=API_BASE=https://host:port/api/v1`. Successful `POST /auth/login` stores `accessToken`; subsequent requests send `Authorization: Bearer …`.

## Authentication

- `POST /auth/login`
  - request:
    - `email` (string)
    - `password` (string)
  - response:
    - `accessToken` (string)
    - `refreshToken` (string)
    - `user` (UserSummary)

## Reference data (catalog)

- `GET /reference/departments`
  - response: `DepartmentOption[]` where each item has `id` (string), `name` (string)
  - Şimdilik sabit iskelet; ileride veritabanı / admin panel ile beslenir.

## Home / Dashboard

- `GET /dashboard/home`
  - response:
    - `responsibilityScore` (int)
    - `upcomingReservations` (ReservationSummary[])
    - `quickStats` (QuickStats)
    - `scoreHistory` (ScoreHistoryEntry[]) — terminal reservations with `scoreChange` for Profile UI
- `ScoreHistoryEntry`: `id`, `date`, `scoreChange`, `description`, `status`

## Reservation

- `GET /reservations/workspaces?date=YYYY-MM-DD&slotId=slot-2&type=individual|group`
  - response: `Workspace[]`

- `POST /reservations`
  - request:
    - `date` (string)
    - `slotId` (string)
    - `workspaceId` (string)
    - `courseCode` (string)
    - `reservationType` (`INDIVIDUAL`|`GROUP`)
    - `allowStudyBuddy` (boolean)
    - `participantNicknames` (string[])
  - response: `ReservationDetail`

- `GET /reservations/me`
  - response: `ReservationDetail[]`

- `POST /reservations/{reservationId}/cancel`
  - request (optional for scoring evaluation):
    - `cancelledAt` (ISO datetime)
    - `slotStartAt` (ISO datetime)
  - response: `ActionResult`

## QR Check-in

- `POST /checkin/verify`
  - request:
    - `reservationId` (string)
    - `qrPayload` (string)
  - response:
    - `success` (boolean)
    - `message` (string)
  - policy: allowed only on the reservation date, from **15 minutes before** slot start until **15 minutes after** slot start; QR must match the desk `qrCode`.

## Study Buddy

- `GET /study-buddies/suggestions?courseCode=CSE344&slotId=slot-2`
  - response: `StudyBuddySuggestion[]`

- `POST /study-buddies/reports`
  - request:
    - `reportedUserId` (string, numeric user id)
    - `reason` (string, required)
    - `comment` (string, optional)
  - response: `{ success, message, report?: BuddyReport }` — reporter set server-side from JWT

## Admin — Study Buddy reports

- `GET /admin/buddy-reports`
  - response: `BuddyReport[]` (status `OPEN` only)

## Course Rating

- `GET /courses`
  - response: `Course[]`

- `POST /courses/{courseCode}/rating`
  - request:
    - `rating` (int: 1..5)
  - response: `ActionResult`

## Lost & Found

- `GET /lost-found`
  - response: `LostItem[]` (active `REPORTED` only, within 24h)

- `POST /lost-found`
  - request:
    - `workspaceId` (string)
    - `description` (string)
  - response: `{ success, message, item?: LostItem }` — `reportedBy` set server-side from JWT

- `PATCH /lost-found/{id}/found`
  - response: `ActionResult`

- `LostItem`:
  - `id`, `workspaceId`, `description`, `reportedAt`, `expiresAt` (ISO-8601), `category`, `status`, `reportedByUserId`

## Weekly schedule (busy hours)

Used by the mobile weekly grid so study-time suggestions can avoid marked slots.

- `GET /schedule/weekly`
  - response:
    - `blocks` (`WeeklyScheduleBlock[]`)

- `PUT /schedule/weekly`
  - request:
    - `blocks` (`WeeklyScheduleBlock[]`)
  - response: `ActionResult`

- `WeeklyScheduleBlock`:
  - `day` (`Mon`|`Tue`|`Wed`|`Thu`|`Fri`)
  - `timeSlot` (string, e.g. `09-10`)
  - `type` (`lesson`|`club`|`busy`|null)
  - `label` (string, optional — course code or activity name)

## Shared Object Skeletons

- `UserSummary`: `id`, `name`, `nickname`, `email`, `department`, `year`
- `ReservationSummary`: `id`, `workspaceId`, `date`, `slotLabel`, `status`
- `Workspace`: `id`, `type`, `capacity`, `status`, `x`, `y`, `qrCode` (`desk-N` → desk number `N`, e.g. `desk-12` → `12`; `group-N` → `GN`)
- `ReservationDetail`: `id`, `workspaceId`, `date`, `slotId`, `slotLabel`, `status`, `courseCode`, `participants`, `qrPayload`, `score` (`0` at creation; COMPLETED `+5`, NO_SHOW `−10`, CANCELLED per cancel policy)
- `StudyBuddySuggestion`: `userId`, `name`, `matchScore`, `commonCourses`, `commonTopics`
- `BuddyReport`: `id`, `reportedUserId`, `reportedName`, `reporterLabel`, `reason`, `comment`, `createdAt` (ISO-8601), `status` (`OPEN`|`DISMISSED`|`RESOLVED`)
- `Course`: `code`, `name`, `difficultyRating`, `ratingCount`
- `LostItem`: `id`, `workspaceId`, `description`, `reportedAt`
- `WeeklyScheduleBlock`: `day`, `timeSlot`, `type`, `label` (see Weekly schedule section)
- `ActionResult`: `success`, `message`, `scoreChange`, `pointsRefunded`

## Cancellation Scoring (Accepted Policy)

- Cancel >= 24h before slot: `scoreChange = +3`, `pointsRefunded = true`
- Cancel < 1h before slot: `scoreChange = -5`, `pointsRefunded = false`
- Cancel between 1h and 24h: `scoreChange = 0`, `pointsRefunded = null` (policy can be finalized later)
- No-show after QR deadline: `scoreChange = -10`, `pointsRefunded = false` (enforced by check-in flow)
