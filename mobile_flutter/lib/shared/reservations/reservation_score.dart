import '../../features/reservation/domain/reservation_models.dart';

/// Responsibility score delta for terminal reservations (aligns with backend policy).
abstract final class ReservationScore {
  ReservationScore._();

  static String normalizeStatus(String status) {
    final s = status.toUpperCase().trim();
    if (s == 'CHECKED_IN' || s == 'CHECKEDIN') return 'COMPLETED';
    return s;
  }

  static bool isTerminalStatus(String status) {
    switch (normalizeStatus(status)) {
      case 'COMPLETED':
      case 'CANCELLED':
      case 'NO_SHOW':
        return true;
      default:
        return false;
    }
  }

  static int? parseDelta(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  /// History / terminal UI — persisted API [ReservationDetail.score] with legacy terminal inference.
  static bool shouldShowHistoryBadge(ReservationDetail r) {
    if (!isTerminalStatus(r.status)) return false;
    final delta = _effectiveDelta(r);
    return delta != 0 || normalizeStatus(r.status) == 'CANCELLED';
  }

  static int _effectiveDelta(ReservationDetail r) {
    if (r.score != 0) return r.score;
    return switch (normalizeStatus(r.status)) {
      'COMPLETED' => 5,
      'NO_SHOW' => -10,
      _ => 0,
    };
  }

  static String descriptionFor(ReservationDetail r, int delta) {
    final slot = r.slotLabel.isNotEmpty ? r.slotLabel : r.slotId;
    switch (normalizeStatus(r.status)) {
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
