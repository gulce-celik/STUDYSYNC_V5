import 'reservation_models.dart';
import '../../../shared/reservations/reservation_score.dart';

/// Score on a reservation — [ReservationDetail.score] from API (backend source of truth).
extension ReservationDetailScore on ReservationDetail {
  bool get isTerminalReservation => ReservationScore.isTerminalStatus(status);

  /// My Bookings → History: show persisted [score] for terminal rows.
  bool get showsHistoryScoreBadge =>
      isTerminalReservation &&
      (score != 0 || status.toUpperCase() == 'CANCELLED');

  String get historyScoreLabel => ReservationScore.formatDelta(score);

  String get scoreEffectDescription =>
      ReservationScore.descriptionFor(this, score);
}
