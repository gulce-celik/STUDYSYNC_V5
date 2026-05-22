import 'package:flutter_test/flutter_test.dart';
import 'package:studysync_mobile/features/reservation/domain/reservation_models.dart';
import 'package:studysync_mobile/shared/reservations/reservation_score.dart';

void main() {
  test('resolve uses API scoreChange when present', () {
    const r = ReservationDetail(
      id: '1',
      workspaceId: 'desk-5',
      date: '2026-05-22',
      slotId: 'slot-3',
      slotLabel: '11.00-13.00',
      status: 'NO_SHOW',
      courseCode: 'CSE344',
      participants: [],
      scoreChange: -10,
    );
    expect(ReservationScore.resolve(r), -10);
  });

  test('resolve falls back for completed without scoreChange', () {
    const r = ReservationDetail(
      id: '1',
      workspaceId: 'desk-5',
      date: '2026-05-22',
      slotId: 'slot-3',
      slotLabel: '11.00-13.00',
      status: 'COMPLETED',
      courseCode: 'CSE344',
      participants: [],
    );
    expect(ReservationScore.resolve(r), 5);
  });
}
