import '../../features/reservation/domain/reservation_models.dart';

/// Check-in window: from 15 minutes before slot start until 15 minutes after slot start.
class CheckInWindow {
  CheckInWindow._();

  static const int earlyOpenMinutes = 15;
  static const int graceAfterStartMinutes = 15;

  static const _slotStartHour = <String, int>{
    'slot-1': 6,
    'slot-2': 9,
    'slot-3': 11,
    'slot-4': 13,
    'slot-5': 15,
    'slot-6': 17,
    'slot-7': 20,
    'slot-8': 23,
  };

  static DateTime? reservationDay(String dateIso) {
    final parts = dateIso.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Parses leading time from labels like `09.00-11.00` or `09:00 - 11:00`.
  static ({int hour, int minute})? startTimeFromLabel(String slotLabel) {
    final match = RegExp(r'(\d{1,2})[.:](\d{2})').firstMatch(slotLabel.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    return (hour: hour, minute: minute);
  }

  static DateTime? slotStartLocal(ReservationDetail r) {
    final day = reservationDay(r.date);
    if (day == null) return null;

    final hour = _slotStartHour[r.slotId];
    if (hour != null) {
      return DateTime(day.year, day.month, day.day, hour);
    }

    final fromLabel = startTimeFromLabel(r.slotLabel);
    if (fromLabel != null) {
      return DateTime(day.year, day.month, day.day, fromLabel.hour, fromLabel.minute);
    }
    return null;
  }

  static DateTime? windowOpensAt(ReservationDetail r) {
    final start = slotStartLocal(r);
    if (start == null) return null;
    return start.subtract(const Duration(minutes: earlyOpenMinutes));
  }

  static DateTime? windowClosesAt(ReservationDetail r) {
    final start = slotStartLocal(r);
    if (start == null) return null;
    return start.add(const Duration(minutes: graceAfterStartMinutes));
  }

  /// True when today is the reservation day (matches backend date rule).
  static bool isReservationToday(ReservationDetail r) {
    final day = reservationDay(r.date);
    if (day == null) return false;
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  static bool isBeforeCheckInWindow(ReservationDetail r) {
    if (!isReservationToday(r)) return false;
    final opens = windowOpensAt(r);
    if (opens == null) return false;
    return DateTime.now().isBefore(opens);
  }

  /// After slot start + [graceAfterStartMinutes].
  static bool isPastGraceWindow(ReservationDetail r) {
    final closes = windowClosesAt(r);
    if (closes == null) return false;
    return DateTime.now().isAfter(closes);
  }

  /// Opens 15 min before start; closes 15 min after start (reservation day only).
  static bool canCheckInNow(ReservationDetail r) {
    if (!isReservationToday(r)) return false;
    final opens = windowOpensAt(r);
    final closes = windowClosesAt(r);
    if (opens == null || closes == null) return false;
    final now = DateTime.now();
    return !now.isBefore(opens) && !now.isAfter(closes);
  }

  static bool canCheckInNowForSlot({
    required String date,
    required String slotId,
    required String slotLabel,
  }) {
    return canCheckInNow(
      ReservationDetail(
        id: '',
        workspaceId: '',
        date: date,
        slotId: slotId,
        slotLabel: slotLabel,
        status: 'ACTIVE',
        courseCode: '',
        participants: const [],
      ),
    );
  }

  /// Short hint for disabled check-in buttons.
  static String? availabilityHint(ReservationDetail r) {
    if (!isReservationToday(r)) {
      return 'Check-in opens on ${r.date}';
    }
    if (isBeforeCheckInWindow(r)) {
      final opens = windowOpensAt(r);
      if (opens != null) {
        return 'Opens at ${_formatClock(opens)} (15 min before slot)';
      }
      return 'Not open yet';
    }
    if (isPastGraceWindow(r)) {
      return 'Check-in window closed';
    }
    return null;
  }

  static String? availabilityHintForSlot({
    required String date,
    required String slotId,
    required String slotLabel,
  }) {
    return availabilityHint(
      ReservationDetail(
        id: '',
        workspaceId: '',
        date: date,
        slotId: slotId,
        slotLabel: slotLabel,
        status: 'ACTIVE',
        courseCode: '',
        participants: const [],
      ),
    );
  }

  static String _formatClock(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
