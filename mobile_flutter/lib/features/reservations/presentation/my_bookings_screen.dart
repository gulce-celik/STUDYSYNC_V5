import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/dashboard_api.dart';
import '../../../core/trust/responsibility_ledger.dart';
import '../../../shared/check_in/check_in_window.dart';
import '../../../shared/check_in/reservation_check_in_sheet.dart';
import '../../reservation/data/reservation_api.dart';
import '../../reservation/domain/reservation_detail_score.dart';
import '../../reservation/domain/reservation_models.dart';
import '../data/bookings_mock_data.dart';

/// Figma Make / React `MyReservations.tsx` + PDF: QR check-in, iptal, sekmeler.
/// Veri: GET /reservations/me; boş/hata → [BookingsMockData]. İptal: POST .../cancel.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _api = ReservationApi();
  final _dashboardApi = DashboardApi();

  List<ReservationDetail>? _all;
  bool _loading = true;
  _BookingsTab _tab = _BookingsTab.active;

  bool get _usingOfflineMock => _all == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final remote = await _api.getMyReservations();
      if (!mounted) return;
      setState(() {
        _all = remote;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _all = null; // fallback to mock on error if desired, or empty
        _loading = false;
      });
    }
  }

  bool _isActiveTab(ReservationDetail r) {
    final s = r.status.toUpperCase();
    return s == 'ACTIVE' || s == 'PENDING';
  }

  bool _isHistoryTab(ReservationDetail r) {
    final s = r.status.toUpperCase();
    return s == 'COMPLETED' || s == 'CANCELLED' || s == 'NO_SHOW';
  }

  bool _isCheckedIn(ReservationDetail r) {
    final s = r.status.toUpperCase();
    return r.checkedIn || s == 'COMPLETED';
  }

  List<ReservationDetail> get _visible {
    if (_all == null) return BookingsMockData.sampleBookings(); // Show mock ONLY if error occurred
    if (_tab == _BookingsTab.active) {
      return _all!.where(_isActiveTab).toList();
    }
    return _all!.where(_isHistoryTab).toList();
  }

  (Color bg, Color fg) _statusStyle(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return (const Color(0xFFD1FAE5), const Color(0xFF065F46));
      case 'PENDING':
        return (const Color(0xFFFEF9C3), const Color(0xFF854D0E));
      case 'COMPLETED':
        return (const Color(0xFFDBEAFE), const Color(0xFF1E40AF));
      case 'CANCELLED':
        return (const Color(0xFFF3F4F6), const Color(0xFF374151));
      case 'NO_SHOW':
        return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
      default:
        return (const Color(0xFFF3F4F6), const Color(0xFF374151));
    }
  }

  String _scoreImpactLabel(int delta) {
    if (delta > 0) return 'Responsibility score +$delta';
    if (delta < 0) return 'Responsibility score $delta';
    return 'No responsibility score change';
  }

  Future<void> _cancel(ReservationDetail r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: Text('${r.courseCode} • ${r.workspaceId}\nScoring may apply per policy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final start = CheckInWindow.slotStartLocal(r);
      await _api.cancelReservation(
        r.id,
        cancelledAt: DateTime.now(),
        slotStartAt: start,
      );
      await _syncResponsibilityFromDashboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancellation sent')));
      await _load();
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancel request failed')));
    }
  }

  Future<void> _syncResponsibilityFromDashboard() async {
    try {
      final dashboard = await _dashboardApi.getHome();
      final scoreRaw = dashboard['responsibilityScore'];
      if (scoreRaw is num) {
        ResponsibilityLedger.instance.setHomeContext(mockOnly: scoreRaw.toInt());
      }
    } catch (_) {
      // Keep current local score if dashboard refresh fails.
    }
  }

  void _openCheckIn(ReservationDetail r) {
    if (!CheckInWindow.canCheckInNow(r)) {
      final hint = CheckInWindow.availabilityHint(r);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hint ?? 'Check-in is not available right now.')),
      );
      return;
    }
    if (_usingOfflineMock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-in needs a live backend. Start the API and pull to refresh.'),
        ),
      );
      return;
    }

    showReservationCheckInSheet(
      context: context,
      reservation: r,
      onSuccess: () async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in successful!')),
        );
        await _syncResponsibilityFromDashboard();
        await _load();
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Bookings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const Text('Manage your reservations', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: _TabChip(
                      label: 'Active & Upcoming',
                      selected: _tab == _BookingsTab.active,
                      onTap: () => setState(() => _tab = _BookingsTab.active),
                    ),
                  ),
                  Expanded(
                    child: _TabChip(
                      label: 'History',
                      selected: _tab == _BookingsTab.history,
                      onTap: () => setState(() => _tab = _BookingsTab.history),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text(
                          'QR check-in opens 15 minutes before your slot and closes 15 minutes after it starts.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.35),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.event_busy_rounded, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _usingOfflineMock
                                    ? 'Could not load bookings from the server.'
                                    : 'No bookings in this tab.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              if (!_usingOfflineMock) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Create a reservation from the map, or sign in with a backend account that already has bookings.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        ..._visible.map((r) {
                          final (stBg, stFg) = _statusStyle(r.status);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFF3F4F6)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(r.courseCode,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: stBg, borderRadius: BorderRadius.circular(999)),
                                        child: Text(
                                          r.status,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: stFg),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      _miniIcon(Icons.calendar_today_outlined, r.date),
                                      _miniIcon(Icons.schedule_rounded, r.slotLabel),
                                      _miniIcon(Icons.location_on_outlined, r.workspaceId),
                                      if (r.isGroup)
                                        _miniIcon(Icons.groups_2_outlined, 'Group (${r.participants.length})'),
                                    ],
                                  ),
                                  if (r.hasScoreEffect) ...[
                                    const SizedBox(height: 8),
                                    Builder(
                                      builder: (context) {
                                        final delta = r.scoreEffect!;
                                        final positive = delta > 0;
                                        final negative = delta < 0;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: positive
                                                ? const Color(0xFFD1FAE5)
                                                : negative
                                                    ? const Color(0xFFFEE2E2)
                                                    : const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            _scoreImpactLabel(delta),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: positive
                                                  ? const Color(0xFF065F46)
                                                  : negative
                                                      ? const Color(0xFF991B1B)
                                                      : const Color(0xFF374151),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  if (_isCheckedIn(r)) ...[
                                    const SizedBox(height: 8),
                                    const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                                        SizedBox(width: 6),
                                        Text('Checked in', style: TextStyle(fontSize: 12, color: Color(0xFF15803D))),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (_isActiveTab(r) && !_isCheckedIn(r)) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed:
                                                CheckInWindow.canCheckInNow(r) ? () => _openCheckIn(r) : null,
                                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                                            label: const Text('QR Check-In'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (r.status.toUpperCase() == 'PENDING' || r.status.toUpperCase() == 'ACTIVE')
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => _cancel(r),
                                              child: const Text('Cancel'),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (CheckInWindow.availabilityHint(r) != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        CheckInWindow.availabilityHint(r)!,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ] else if (_isActiveTab(r) &&
                                      (r.status.toUpperCase() == 'PENDING' || r.status.toUpperCase() == 'ACTIVE'))
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _cancel(r),
                                            child: const Text('Cancel'),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static Widget _miniIcon(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B7280)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
      ],
    );
  }
}

enum _BookingsTab { active, history }

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF2563EB) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}
