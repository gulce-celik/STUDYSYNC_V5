import 'package:flutter/material.dart';

import '../../../../core/campus/campus_layout_store.dart';
import '../../reservation/data/reservation_mock_data.dart';
import '../data/admin_data_controller.dart';
import '../data/admin_mock_data.dart';
import '../data/admin_repository.dart';
import '../data/admin_workspace_closure_store.dart';
import 'admin_student_detail_screen.dart';
import 'widgets/admin_map_layout_card.dart';
import 'widgets/admin_ui.dart';
import 'widgets/admin_workspace_closure_sheet.dart';

int _dartWeekdayToSun0(int weekday) => weekday % 7;

class AdminBookingScreen extends StatefulWidget {
  const AdminBookingScreen({super.key});

  @override
  State<AdminBookingScreen> createState() => _AdminBookingScreenState();
}

class _AdminBookingScreenState extends State<AdminBookingScreen> {
  late int _dayIndex;

  @override
  void initState() {
    super.initState();
    _dayIndex = _dartWeekdayToSun0(DateTime.now().weekday);
  }

  AdminStudent? _student(String id) {
    for (final s in AdminMockData.students) {
      if (s.id == id) return s;
    }
    return null;
  }

  Color _heatColor(int percent) {
    if (percent >= 80) return const Color(0xFFDC2626);
    if (percent >= 50) return const Color(0xFFF59E0B);
    if (percent >= 20) return const Color(0xFF60A5FA);
    return const Color(0xFF86EFAC);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AdminWorkspaceClosureStore.instance,
        CampusLayoutStore.instance,
        AdminDataController.instance,
      ]),
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final layout = CampusLayoutStore.instance;
    final snap = AdminDataController.instance.snapshot;
    final repo = AdminDataController.instance.repository;
    final iso = AdminRepository.dateIsoForDayIndex(_dayIndex);
    final apiWs = snap.workspacesForDateIso(iso);
    final totalDesks = layout.individualDesks;
    final totalGroups = layout.groupRooms;
    final mapWorkspaces = apiWs.isNotEmpty ? apiWs : layout.workspaces;
    final day = repo.daySnapshot(_dayIndex, snap);
    final noShows = AdminMockData.noShowsForDay(_dayIndex);
    final stats = repo.workspaceStatsForDay(day, apiWs);
    final statById = {for (final s in stats) s.workspaceId: s};
    final isToday = _dayIndex == _dartWeekdayToSun0(DateTime.now().weekday);
    final closures = AdminWorkspaceClosureStore.instance.closuresForDay(_dayIndex);
    final closureStore = AdminWorkspaceClosureStore.instance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const AdminSectionTitle('Select day'),
        AdminWeekDayPicker(
          selectedIndex: _dayIndex,
          onSelected: (i) => setState(() => _dayIndex = i),
        ),
        const SizedBox(height: 12),
        const AdminMapLayoutCard(),
        const SizedBox(height: 12),
        AdminSurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? 'Today (${day.dayLabel})' : day.dayLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.activeReservations} bookings • ${closures.length} closed',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
                    ),
                  ],
                ),
              ),
              AdminDonutStat(percent: day.occupancyPercent, label: 'Booked'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AdminKpiCard(
                label: 'Desks in use',
                value: '${day.occupiedDesks}/$totalDesks',
                icon: Icons.chair_alt_rounded,
                color: const Color(0xFF1E40AF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AdminKpiCard(
                label: 'Group rooms',
                value: '${day.occupiedGroups}/$totalGroups',
                icon: Icons.groups_rounded,
                color: const Color(0xFF4338CA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminSectionTitle(
          'No-show (no check-in)',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${noShows.length}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFB91C1C)),
            ),
          ),
        ),
        Text(
          'Reserved slot started but student did not check in within 15 minutes.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
        ),
        const SizedBox(height: 8),
        if (noShows.isEmpty)
          AdminSurfaceCard(
            child: Text(
              'No no-shows recorded for ${day.dayLabel}.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          )
        else
          ...noShows.map((n) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AdminSurfaceCard(
                padding: const EdgeInsets.all(12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_off_outlined, color: Color(0xFFB91C1C)),
                  ),
                  title: Text(n.studentName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${n.workspaceId} • ${n.timeSlot}\n${n.minutesPastStart} min past start — no QR check-in',
                    style: const TextStyle(fontSize: 11, height: 1.35),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    final s = _student(n.studentId);
                    if (s == null) return;
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => AdminStudentDetailScreen(student: s)),
                    );
                  },
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        const AdminSectionTitle('Space heatmap'),
        Text(
          'Tap a desk or room to close it for ${day.dayLabel} (broken, maintenance, etc.) or reopen.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
        ),
        const SizedBox(height: 8),
        AdminSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _legend(const Color(0xFF86EFAC), 'Low'),
                  _legend(const Color(0xFF60A5FA), 'Medium'),
                  _legend(const Color(0xFFF59E0B), 'High'),
                  _legend(const Color(0xFFDC2626), 'Full'),
                  _legend(const Color(0xFF475569), 'Closed'),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final h = maxW * (ReservationMockData.mapHeight / ReservationMockData.mapWidth);
                  final sx = maxW / ReservationMockData.mapWidth;
                  final sy = h / ReservationMockData.mapHeight;

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: maxW,
                      height: h,
                      color: const Color(0xFFF8FAFC),
                      child: Stack(
                        children: [
                          ...mapWorkspaces.map((ws) {
                            final closed = closureStore.isClosed(_dayIndex, ws.id);
                            final st = statById[ws.id];
                            final pct = st?.occupancyPercent ?? 0;
                            final w = (ws.type == 'individual' ? 35 : 70) * sx;
                            final hi = (ws.type == 'individual' ? 50 : 100) * sy;
                            return Positioned(
                              left: ws.x * sx,
                              top: ws.y * sy,
                              width: w,
                              height: hi,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => showAdminWorkspaceClosureSheet(
                                    context: context,
                                    dayIndex: _dayIndex,
                                    dayLabel: day.dayLabel,
                                    workspaceId: ws.id,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: closed ? const Color(0xFF475569) : _heatColor(pct),
                                      borderRadius: BorderRadius.circular(ws.type == 'individual' ? 4 : 8),
                                      border: Border.all(
                                        color: closed ? const Color(0xFF94A3B8) : Colors.white,
                                        width: closed ? 2 : 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: closed
                                        ? const Icon(Icons.block, color: Colors.white, size: 16)
                                        : Text(
                                            ws.type == 'individual' ? ws.id.split('-').last : ws.id,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 9,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (closures.isNotEmpty) ...[
          const SizedBox(height: 16),
          AdminSectionTitle('Closed for ${day.dayLabel}', trailing: Text('${closures.length}')),
          ...closures.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AdminSurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.block, color: Color(0xFF475569)),
                  title: Text(c.workspaceId, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(c.reason, style: const TextStyle(fontSize: 11)),
                  trailing: TextButton(
                    onPressed: () {
                      closureStore.reopenWorkspace(dayIndex: _dayIndex, workspaceId: c.workspaceId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${c.workspaceId} reopened for ${day.dayLabel}.')),
                      );
                    },
                    child: const Text('Reopen'),
                  ),
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 12),
        Text(
          'Closures apply only to the selected day.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
