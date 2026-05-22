/// Mirrors `mockData.ts` scoreHistory + default course codes for profile display.
library profile_mock_data;

class ProfileScoreEntry {
  const ProfileScoreEntry({
    required this.id,
    required this.date,
    required this.score,
    required this.description,
  });

  final String id;
  final String date;
  /// Same as [ReservationDetail.score] on the booking.
  final int score;
  final String description;
}

abstract final class ProfileMockData {
  static const nickname = 'ahmet_y';

  static const enrolledCourseCodes = ['CSE344', 'CSE331', 'CSE312', 'CSE211'];

  static const scoreHistory = <ProfileScoreEntry>[
    ProfileScoreEntry(id: 'sh-1', date: '2026-03-10', score: 5, description: '5 successful check-ins completed'),
    ProfileScoreEntry(id: 'sh-2', date: '2026-03-08', score: 3, description: 'Cancelled reservation 24h in advance'),
    ProfileScoreEntry(id: 'sh-3', date: '2026-03-05', score: -10, description: 'No-show for reservation'),
    ProfileScoreEntry(id: 'sh-4', date: '2026-03-01', score: 5, description: '5 successful check-ins completed'),
    ProfileScoreEntry(id: 'sh-5', date: '2026-02-28', score: 8, description: 'All group members checked in on time'),
  ];
}
