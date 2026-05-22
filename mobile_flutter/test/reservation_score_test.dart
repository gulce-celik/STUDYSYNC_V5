import 'package:flutter_test/flutter_test.dart';
import 'package:studysync_mobile/features/reservation/domain/reservation_models.dart';
import 'package:studysync_mobile/features/reservation/domain/reservation_detail_score.dart';
import 'package:studysync_mobile/shared/reservations/reservation_score.dart';

void main() {
  test('active reservation score is 0 and no history badge', () {
    const r = ReservationDetail(
      id: '1',
      workspaceId: 'desk-5',
      date: '2026-05-22',
      slotId: 'slot-3',
      slotLabel: '11.00-13.00',
      status: 'ACTIVE',
      courseCode: 'CSE344',
      participants: [],
      score: 0,
    );
    expect(r.score, 0);
    expect(ReservationScore.shouldShowHistoryBadge(r), isFalse);
    expect(r.showsHistoryScoreBadge, isFalse);
  });

  test('history uses API score for no-show', () {
    const r = ReservationDetail(
      id: '1',
      workspaceId: 'desk-5',
      date: '2026-05-22',
      slotId: 'slot-3',
      slotLabel: '11.00-13.00',
      status: 'NO_SHOW',
      courseCode: 'CSE344',
      participants: [],
      score: -10,
    );
    expect(r.score, -10);
    expect(r.showsHistoryScoreBadge, isTrue);
    expect(r.historyScoreLabel, '-10');
  });

  test('completed shows persisted score only', () {
    const r = ReservationDetail(
      id: '1',
      workspaceId: 'desk-5',
      date: '2026-05-22',
      slotId: 'slot-3',
      slotLabel: '11.00-13.00',
      status: 'COMPLETED',
      courseCode: 'CSE344',
      participants: [],
      score: 5,
    );
    expect(r.showsHistoryScoreBadge, isTrue);
    expect(r.score, 5);
    expect(r.showsHistoryScoreBadge, isTrue);
  });

  test('cancelled mid-window shows zero badge from score', () {
    const r = ReservationDetail(
      id: '1',
      workspaceId: 'desk-5',
      date: '2026-05-22',
      slotId: 'slot-3',
      slotLabel: '11.00-13.00',
      status: 'CANCELLED',
      courseCode: 'CSE344',
      participants: [],
      score: 0,
    );
    expect(r.score, 0);
    expect(r.showsHistoryScoreBadge, isTrue);
    expect(ReservationScore.shouldShowHistoryBadge(r), isTrue);
  });
}
