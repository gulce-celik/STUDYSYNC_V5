import '../../features/reservation/domain/reservation_models.dart';

/// Responsibility score delta for terminal reservations (aligns with backend policy).
abstract final class ReservationScore {
  ReservationScore._();

  static bool isTerminalStatus(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'CANCELLED':
      case 'NO_SHOW':
        return true;
      default:
        return false;
    }
  }

  /// API `scoreChange` when present; otherwise same fallbacks as Java `ReservationMapper`.
  static int? resolve(ReservationDetail r) {
    if (r.scoreChange != null) return r.scoreChange;
    switch (r.status.toUpperCase()) {
      case 'COMPLETED':
        return 5;
      case 'NO_SHOW':
        return -10;
      default:
        return null;
    }
  }

  static String descriptionFor(ReservationDetail r, int delta) {
    final slot = r.slotLabel.isNotEmpty ? r.slotLabel : r.slotId;
    switch (r.status.toUpperCase()) {
      case 'COMPLETED':
        return 'Check-in completed · ${r.workspaceId} · $slot';
      case 'NO_SHOW':
        return 'No-show · ${r.courseCode} · $slot';
      case 'CANCELLED':
        if (delta >= 3) return 'Early cancellation · ${r.courseCode}';
        if (delta <= -5) return 'Late cancellation · ${r.courseCode}';
        return 'Cancellation · ${r.courseCode} · $slot';
      default:
        return '${r.status} · ${r.courseCode}';
    }
  }

  static String formatDelta(int delta) {
    if (delta > 0) return '+$delta';
    return '$delta';
  }
}
