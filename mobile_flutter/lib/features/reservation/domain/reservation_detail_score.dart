import 'reservation_models.dart';
import '../../../shared/reservations/reservation_score.dart';

/// Score delta on a reservation for History / Profile (uses API [ReservationDetail.scoreChange] + policy fallback).
extension ReservationDetailScore on ReservationDetail {
  int? get scoreEffect => ReservationScore.resolve(this);

  bool get hasScoreEffect => scoreEffect != null;

  String get scoreEffectLabel {
    final delta = scoreEffect;
    if (delta == null) return '';
    return ReservationScore.formatDelta(delta);
  }

  String get scoreEffectDescription {
    final delta = scoreEffect;
    if (delta == null) return '';
    return ReservationScore.descriptionFor(this, delta);
  }
}
