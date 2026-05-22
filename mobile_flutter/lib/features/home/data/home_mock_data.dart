/// `src/app/data/mockData.ts` — Home / upcoming / davetler.
class HomeMockData {
  HomeMockData._();

  /// Demo baseline when API/dashboard is absent — mid-range trust, rights reduced via quotas only.
  static const responsibilityScore = 75;

  static const List<HomeUpcomingReservation> upcomingReservations = [
    HomeUpcomingReservation(
      id: 'res-1',
      workspaceId: 'desk-5',
      date: '2026-03-10',
      timeSlot: '10:00 - 12:00',
      slotId: 'slot-2',
      type: ReservationKind.individual,
    ),
    HomeUpcomingReservation(
      id: 'res-2',
      workspaceId: 'desk-12',
      date: '2026-03-11',
      timeSlot: '14:00 - 16:00',
      slotId: 'slot-4',
      type: ReservationKind.individual,
    ),
  ];

  static List<HomeGroupInvitation> initialInvitations() => [
        const HomeGroupInvitation(
          id: 'inv-1',
          inviterName: 'Emre',
          workspaceId: 'group-3',
          date: '2026-03-14',
          slot: '16:00 - 18:00',
          createdAt: '2026-03-12T14:00:00',
          expiresAt: '2026-03-12T14:10:00',
          memberPreview: 'Gülce, Efe',
        ),
      ];
}

enum ReservationKind { individual, group }

class HomeUpcomingReservation {
  const HomeUpcomingReservation({
    required this.id,
    required this.workspaceId,
    required this.date,
    required this.timeSlot,
    this.slotId = '',
    required this.type,
  });

  final String id;
  final String workspaceId;
  final String date;
  final String timeSlot;
  final String slotId;
  final ReservationKind type;
}

class HomeGroupInvitation {
  const HomeGroupInvitation({
    required this.id,
    required this.inviterName,
    required this.workspaceId,
    required this.date,
    required this.slot,
    required this.createdAt,
    required this.expiresAt,
    this.memberPreview = '',
  });

  final String id;
  final String inviterName;
  final String workspaceId;
  final String memberPreview;
  final String date;
  final String slot;
  final String createdAt;
  final String expiresAt;

  /// Dakika cinsinden (demo: createdAt / expiresAt farkı).
  int get expiresInMinutes {
    final c = DateTime.tryParse(createdAt);
    final e = DateTime.tryParse(expiresAt);
    if (c == null || e == null) return 10;
    return e.difference(c).inMinutes.abs().clamp(1, 999);
  }
}
