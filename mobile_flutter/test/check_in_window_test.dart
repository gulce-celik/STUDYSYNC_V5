import 'package:flutter_test/flutter_test.dart';
import 'package:studysync_mobile/features/reservation/domain/reservation_models.dart';
import 'package:studysync_mobile/shared/check_in/check_in_window.dart';

ReservationDetail _reservation({
  required String date,
  required String slotId,
  required String slotLabel,
}) {
  return ReservationDetail(
    id: '1',
    workspaceId: 'desk-1',
    date: date,
    slotId: slotId,
    slotLabel: slotLabel,
    status: 'ACTIVE',
    courseCode: 'CSE344',
    participants: const [],
  );
}

void main() {
  test('isReservationToday matches calendar day', () {
    final today = DateTime.now();
    final iso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final r = _reservation(date: iso, slotId: 'slot-2', slotLabel: '09.00-11.00');
    expect(CheckInWindow.isReservationToday(r), isTrue);
  });

  test('slotStartLocal maps slot-2 to 09:00', () {
    final r = _reservation(date: '2026-05-16', slotId: 'slot-2', slotLabel: '09.00-11.00');
    final start = CheckInWindow.slotStartLocal(r);
    expect(start, isNotNull);
    expect(start!.hour, 9);
    expect(start.minute, 0);
  });

  test('windowOpensAt is 15 minutes before slot start', () {
    final today = DateTime.now();
    final iso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final r = _reservation(date: iso, slotId: 'slot-2', slotLabel: '09.00-11.00');
    final opens = CheckInWindow.windowOpensAt(r);
    final start = CheckInWindow.slotStartLocal(r);
    expect(opens, isNotNull);
    expect(start, isNotNull);
    expect(start!.difference(opens!).inMinutes, 15);
  });

  test('canCheckInNow is false before window opens', () {
    final today = DateTime.now();
    final iso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    // slot-1 starts at 06:00 — if test runs after 06:15 same day, pick a far-future slot today
    final r = _reservation(date: iso, slotId: 'slot-8', slotLabel: '23.00-02.00');
    final now = DateTime.now();
    final opens = CheckInWindow.windowOpensAt(r);
    if (opens != null && now.isBefore(opens)) {
      expect(CheckInWindow.canCheckInNow(r), isFalse);
      expect(CheckInWindow.isBeforeCheckInWindow(r), isTrue);
    }
  });
}
