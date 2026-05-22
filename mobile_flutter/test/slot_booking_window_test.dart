import 'package:flutter_test/flutter_test.dart';
import 'package:studysync_mobile/shared/check_in/check_in_window.dart';

void main() {
  test('past same-day slot is not bookable', () {
    final now = DateTime.now();
    final iso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    expect(
      CheckInWindow.isSlotBookableForDate(
        dateIso: iso,
        slotId: 'slot-1',
        slotLabel: '06:00 - 09:00 (Morning)',
      ),
      DateTime.now().hour < 6,
    );
  });

  test('future date allows any slot', () {
    final future = DateTime.now().add(const Duration(days: 3));
    final iso =
        '${future.year}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}';

    expect(
      CheckInWindow.isSlotBookableForDate(
        dateIso: iso,
        slotId: 'slot-1',
        slotLabel: '06:00 - 09:00 (Morning)',
      ),
      isTrue,
    );
  });
}
