import 'reservation_models.dart';
import '../../../shared/reservations/reservation_score.dart';

/// Score on a reservation — [ReservationDetail.score] from API (backend source of truth).
extension ReservationDetailScore on ReservationDetail {
  bool get isTerminalReservation => ReservationScore.isTerminalStatus(status);

  /// Persisted [score], with terminal-status inference when API/DB still has {@code 0} on legacy rows.
  int get effectiveScore {
    if (score != 0) return score;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 5;
      case 'NO_SHOW':
        return -10;
      default:
        return 0;
    }
  }

  /// My Bookings → History: show persisted/effective score for terminal rows.
  bool get showsHistoryScoreBadge =>
      isTerminalReservation &&
      (effectiveScore != 0 || status.toUpperCase() == 'CANCELLED');

  String get historyScoreLabel => ReservationScore.formatDelta(effectiveScore);

  String get scoreEffectDescription =>
      ReservationScore.descriptionFor(this, effectiveScore);
}
