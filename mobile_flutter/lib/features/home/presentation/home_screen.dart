import 'package:flutter/material.dart';

import '../../../core/planner/ai_study_controller.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/trust/responsibility_ledger.dart';
import '../../../core/network/dashboard_api.dart';
import '../../../shared/navigation/app_tab_controller.dart';
import '../../courses/presentation/course_rating_screen.dart';
import '../../lost_found/presentation/lost_found_screen.dart';
import '../../reservations/presentation/my_bookings_screen.dart';
import '../data/home_mock_data.dart';

/// Figma / React `Home.tsx` — hero, sorumluluk rozeti, study tip, gradient quick actions, upcoming, davetler.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<HomeGroupInvitation> _invitations;
  final Set<String> _demoCheckedInIds = <String>{};
  int? _apiTotalReservations;
  int? _apiActiveToday;
  List<HomeUpcomingReservation>? _apiUpcomingReservations;

  void _onLedgerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _invitations = HomeMockData.initialInvitations();
    ResponsibilityLedger.instance.setHomeContext(mockOnly: HomeMockData.responsibilityScore);
    ResponsibilityLedger.instance.addListener(_onLedgerChanged);
    _loadDashboard();
  }

  @override
  void dispose() {
    ResponsibilityLedger.instance.removeListener(_onLedgerChanged);
    super.dispose();
  }

  /// GET /dashboard/home — PDF’deki sorumluluk puanı; hata olursa mock kalır.
  Future<void> _loadDashboard() async {
    try {
      final d = await DashboardApi().getHome();
      final quickStats = d['quickStats'];
      final upcomingRaw = d['upcomingReservations'];
      final apiScoreRaw = d['responsibilityScore'];
      if (!mounted) return;
      setState(() {
        final apiScore = apiScoreRaw is num ? apiScoreRaw.toInt() : HomeMockData.responsibilityScore;
        ResponsibilityLedger.instance.setHomeContext(mockOnly: apiScore);
        if (quickStats is Map<String, dynamic>) {
          final total = quickStats['totalReservations'];
          final active = quickStats['activeToday'];
          _apiTotalReservations = total is num ? total.toInt() : _apiTotalReservations;
          _apiActiveToday = active is num ? active.toInt() : _apiActiveToday;
        }
        if (upcomingRaw is List) {
          _apiUpcomingReservations = upcomingRaw.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final ws = m['workspaceId']?.toString() ?? '';
            final isGroup = ws.toLowerCase().startsWith('group');
            return HomeUpcomingReservation(
              id: m['id']?.toString() ?? '',
              workspaceId: ws,
              date: m['date']?.toString() ?? '',
              timeSlot: m['slotLabel']?.toString() ?? '',
              type: isGroup ? ReservationKind.group : ReservationKind.individual,
            );
          }).toList();
        }
      });
    } catch (_) {
      setState(() {
        ResponsibilityLedger.instance.setHomeContext(mockOnly: HomeMockData.responsibilityScore);
        _apiUpcomingReservations = HomeMockData.upcomingReservations;
      });
    }
  }

  void _acceptInvitation(String id) {
    setState(() => _invitations = _invitations.where((e) => e.id != id).toList());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepted!')));
  }

  void _rejectInvitation(String id) {
    setState(() => _invitations = _invitations.where((e) => e.id != id).toList());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected')));
  }

  void _goTab(int index) => AppTabController.instance.selectTab(index);

  Future<void> _showDemoCheckInSheet(HomeUpcomingReservation reservation) async {
    final payload = 'DEMO-QR-${reservation.id}';
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('QR Check-In', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Payload: $payload', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() => _demoCheckedInIds.add(reservation.id));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demo mode: check-in simulated successfully.')),
                  );
                },
                child: const Text('Mark as Checked-In (Demo)'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _firstNameForGreeting() {
    final session = AuthSession.instance;
    final raw = (session.userName?.trim().isNotEmpty ?? false)
        ? session.userName!.trim()
        : (session.userNickname?.trim().isNotEmpty ?? false)
            ? session.userNickname!.trim()
            : 'Student';
    final parts = raw.split(RegExp(r'\s+'));
    return parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstName = _firstNameForGreeting();
    final upcoming = _apiUpcomingReservations != null
        ? _apiUpcomingReservations!
        : HomeMockData.upcomingReservations;
    final sessions = _apiTotalReservations ?? 8;
    final activeToday = _apiActiveToday ?? upcoming.length;
    // Hero badge: mock 75 (display) + buddy-listing delta; real DB score not shown. Reserve: session caps;
    // only per-session caps (reduced “rights” demo). BuddyListingScoreIntegrationNotes.java (BE).
    final displayScore = ResponsibilityLedger.instance.effectiveScore;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF9333EA), Color(0xFFDB2777)],
              ),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('StudySync', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Welcome, $firstName! 👋', style: const TextStyle(color: Color(0xFFDBEAFE), fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFDE047), size: 16),
                          const SizedBox(width: 4),
                          Text('$displayScore%',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _StatBox(label: 'Hours/Week', value: '12')),
                    const SizedBox(width: 8),
                    Expanded(child: _StatBox(label: 'Sessions', value: '$sessions')),
                    const SizedBox(width: 8),
                    Expanded(child: _StatBox(label: 'Buddies', value: '$activeToday')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF1F2937), Color(0xFF111827)]
                          : const [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF374151) : const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '💡 Study Tip',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your peak productivity is 9-11 AM. Reserve morning slots for better focus!',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Quick Actions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.92,
                  children: [
                    _QuickAction(
                      icon: Icons.calendar_month_rounded,
                      label: 'Bookings',
                      gradient: const [Color(0xFFA855F7), Color(0xFF9333EA)],
                      isDark: isDark,
                      onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(builder: (_) => const MyBookingsScreen()),
                          ),
                    ),
                    _QuickAction(
                      icon: Icons.star_rounded,
                      label: 'Rate Course',
                      gradient: const [Color(0xFFF97316), Color(0xFFEA580C)],
                      isDark: isDark,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CourseRatingScreen())),
                    ),
                    _QuickAction(
                      icon: Icons.inventory_2_rounded,
                      label: 'Lost & Found',
                      gradient: const [Color(0xFF14B8A6), Color(0xFF0D9488)],
                      isDark: isDark,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LostFoundScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: AiStudyController.instance,
                  builder: (context, _) {
                    final items = AiStudyController.instance.suggestions;
                    if (items.isEmpty) return const SizedBox.shrink();
                    final s = items.first;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [Color(0xFF111827), Color(0xFF1E1B4B)]
                              : const [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFC7D2FE)),
                        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                                  ),
                                ),
                                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AI Suggestions',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E1B4B),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1D4ED8) : const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '2h plan',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.message,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    AiStudyController.instance.acceptSuggestion(s);
                                    _goTab(1);
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Accept'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => AiStudyController.instance.rejectSuggestion(s.id),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Upcoming', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      TextButton(
                        onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(builder: (_) => const MyBookingsScreen()),
                            ),
                        child: const Text('View All →', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 2),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Check-In Required', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                              SizedBox(height: 4),
                              Text(
                                'Use QR Check In within 15 minutes of your session start time. Late check-ins result in automatic cancellation and score penalty.',
                                style: TextStyle(fontSize: 10, height: 1.35, color: Color(0xFF92400E)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...upcoming.take(2).map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 0,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF3F4F6)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.workspaceId, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF6B7280)),
                                            const SizedBox(width: 4),
                                            Text(r.timeSlot, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: r.type == ReservationKind.individual
                                          ? const Color(0xFFDBEAFE)
                                          : const Color(0xFFE9D5FF),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      r.type == ReservationKind.individual ? '👤 Solo' : '👥 Group',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: r.type == ReservationKind.individual
                                            ? const Color(0xFF1D4ED8)
                                            : const Color(0xFF7E22CE),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(r.date, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                                  if (_demoCheckedInIds.contains(r.id))
                                    const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Checked in (Demo)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showDemoCheckInSheet(r),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.qr_code_scanner_rounded, size: 14, color: Color(0xFF2563EB)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'QR Check In →',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_invitations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Color(0xFF9333EA), size: 22),
                      const SizedBox(width: 8),
                      const Text('Group Invitations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF9333EA), borderRadius: BorderRadius.circular(999)),
                        child: Text('${_invitations.length}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._invitations.map(
                    (inv) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFF3E8FF), Color(0xFFFCE7F3)]),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE9D5FF), width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Group Study Invitation',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7E22CE))),
                          const SizedBox(height: 4),
                          Text(inv.workspaceId, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF6B7280)),
                              const SizedBox(width: 4),
                              Text(inv.date, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                              const SizedBox(width: 12),
                              const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF6B7280)),
                              const SizedBox(width: 4),
                              Text(inv.slot, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              'Expires in: ${inv.expiresInMinutes} minutes',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF6B21A8), fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: () => _acceptInvitation(inv.id),
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                  label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: () => _rejectInvitation(inv.id),
                                  icon: const Icon(Icons.cancel_outlined, size: 16),
                                  label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Color(0xFFDBEAFE), fontSize: 9)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final List<Color> gradient;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF111827) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
