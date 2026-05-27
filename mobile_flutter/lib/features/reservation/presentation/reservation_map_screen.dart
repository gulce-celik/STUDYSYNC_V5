import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../core/campus/campus_layout_store.dart';
import '../../../core/planner/ai_study_controller.dart';
import '../../../core/trust/responsibility_ledger.dart';
import '../../../shared/widgets/lost_map_badge.dart';
import '../../lost_found/data/lost_found_api.dart';
import '../../lost_found/lost_found_map_sync.dart';
import '../../../shared/check_in/check_in_window.dart';
import '../data/reservation_api.dart';
import '../data/reservation_mock_data.dart';
import '../domain/reservation_models.dart';
import '../../../core/session/auth_session.dart';

enum _DeskFilter { all, individual, group }

const _kDayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/// Reserve Space — aligned with Figma/React `ReservationMap.tsx` and analysis rules
/// (Mon/Fri booking windows, instant desks, lost-item warning, scoring hints).
class ReservationMapScreen extends StatefulWidget {
  const ReservationMapScreen({super.key});

  @override
  State<ReservationMapScreen> createState() => _ReservationMapScreenState();
}

class _ReservationMapScreenState extends State<ReservationMapScreen> {
  final _api = ReservationApi();
  late DateTime _selectedDate;
  String _selectedSlot = '';
  String _selectedCourse = '';
  String? _selectedWorkspaceId;
  ReservationType _reservationType = ReservationType.individual;
  bool _allowStudyBuddy = false;
  _DeskFilter _filter = _DeskFilter.all;
  bool _sheetExpanded = false;
  final List<String> _groupNicknames = [];
  final _nicknameCtrl = TextEditingController();

  /// GET /reservations/workspaces doluysa harita sunucu koordinatlarını kullanır; yoksa mock ızgara.
  List<Workspace>? _remoteWorkspaces;
  bool _remoteLoading = false;
  bool _submittingReservation = false;
  bool _hideAiShortcut = false;

  /// Workspaces with active lost-item reports from GET /lost-found.
  Set<String> _lostWorkspaceIds = {};

  /// 0=Sun … 6=Sat (matches React `getDay()` semantics).
  late int _simulatedDay;

  @override
  void initState() {
    super.initState();
    LostFoundMapSync.addListener(_reloadLostMarkers);
    final now = DateTime.now();
    // Antigravity Modification: Initialized with today's real date instead of a hardcoded 2026 date.
    _simulatedDay = _dartWeekdayToSun0(now.weekday);
    _selectedDate = now;
    AiStudyController.instance.addListener(_onAiControllerChanged);
    _consumePendingAiPrefill();
    _reloadLostMarkers();
    CampusLayoutStore.instance.addListener(_onCampusLayoutChanged);
  }

  void _onCampusLayoutChanged() {
    if (_selectedWorkspaceId != null &&
        !CampusLayoutStore.instance.workspaceExists(_selectedWorkspaceId!)) {
      _selectedWorkspaceId = null;
    }
    if (mounted) setState(() {});
  }

  /// Antigravity Modification: Helper to link the Top Day Menu with the Calendar Date.
  /// When a day is selected, it calculates the corresponding calendar date.
  void _updateSimulatedDay(int dayIndex) {
    final now = DateTime.now();
    final currentSun0 = _dartWeekdayToSun0(now.weekday);
    int diff = dayIndex - currentSun0;
    // We don't want to go back in time for the selected date
    if (diff < 0) diff += 7;
    
    setState(() {
      _simulatedDay = dayIndex;
      _selectedDate = now.add(Duration(days: diff));
      _prunePastSelectedSlot();
    });
    _reloadWorkspacesFromServer();
  }

  @override
  void dispose() {
    CampusLayoutStore.instance.removeListener(_onCampusLayoutChanged);
    LostFoundMapSync.removeListener(_reloadLostMarkers);
    AiStudyController.instance.removeListener(_onAiControllerChanged);
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadLostMarkers() async {
    try {
      final raw = await LostFoundApi().getLostItems();
      if (!mounted) return;
      setState(() {
        _lostWorkspaceIds = raw
            .where((e) {
              final status = e['status']?.toString().toUpperCase() ?? 'REPORTED';
              return status != 'FOUND';
            })
            .map((e) => e['workspaceId']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _lostWorkspaceIds = {});
    }
  }

  void _onAiControllerChanged() {
    _consumePendingAiPrefill();
  }

  void _consumePendingAiPrefill() {
    final pending = AiStudyController.instance.consumePendingPrefill();
    if (pending != null) {
      _hideAiShortcut = true;
      _applyAiPrefill(pending);
    }
  }

  static int _dartWeekdayToSun0(int dartWeekday) {
    if (dartWeekday == DateTime.sunday) return 0;
    return dartWeekday;
  }

  bool get _canReserveAdvance {
    final now = DateTime.now();
    final todaySun0 = _dartWeekdayToSun0(now.weekday);
    final isTodayMonday = todaySun0 == 1;
    final isTodayFriday = todaySun0 == 5;

    // Rule: On Monday/Friday, you can reserve for any day (advance booking window).
    if (isTodayMonday || isTodayFriday) return true;

    // Rule: Other days (Tue, Wed, Thu) can ONLY reserve for the current calendar day.
    final selectedIso = _selectedDateIso;
    final todayIso = DateTime(now.year, now.month, now.day).toString().split(' ').first;
    return selectedIso == todayIso;
  }

  String get _currentDayName => _kDayNames[_simulatedDay];

  List<Workspace> get _layoutWorkspaces {
    if (_remoteWorkspaces != null && _remoteWorkspaces!.isNotEmpty) {
      return _remoteWorkspaces!;
    }
    return ReservationMockData.workspaces;
  }

  String get _layoutStatusCaption {
    if (_remoteWorkspaces != null && _remoteWorkspaces!.isNotEmpty) {
      return 'Masa düzeni ve doluluk sunucudan • Kayıp işaretler raporlardan';
    }
    return 'Masa düzeni admin panelinden (bu oturum) • Doluluk örnek veya sunucudan';
  }

  static String _groupRoomLabel(String workspaceId) {
    final n = workspaceId.replaceFirst('group-', '');
    return 'Oda $n';
  }

  List<CourseOption> get _userCourses {
    final enrolled = AuthSession.instance.enrolledCourseCodes;
    if (enrolled.isEmpty) return ReservationMockData.courses;
    return ReservationMockData.courses.where((c) => enrolled.contains(c.code)).toList();
  }

  Workspace? _workspaceById(String? id) {
    if (id == null) return null;
    for (final w in _layoutWorkspaces) {
      if (w.id == id) return w;
    }
    return null;
  }

  String? get _selectedSlotId {
    for (final s in ReservationMockData.timeSlots) {
      if (s.label == _selectedSlot) return s.id;
    }
    return null;
  }

  List<TimeSlot> get _selectableTimeSlots => ReservationMockData.timeSlots
      .where(
        (s) => CheckInWindow.isSlotBookableForDate(
          dateIso: _selectedDateIso,
          slotId: s.id,
          slotLabel: s.label,
        ),
      )
      .toList();

  void _prunePastSelectedSlot() {
    final sid = _selectedSlotId;
    if (sid == null || _selectedSlot.isEmpty) return;
    if (CheckInWindow.isSlotBookableForDate(
      dateIso: _selectedDateIso,
      slotId: sid,
      slotLabel: _selectedSlot,
    )) {
      return;
    }
    _selectedSlot = '';
  }

  Future<void> _reloadWorkspacesFromServer() async {
    final sid = _selectedSlotId;
    if (sid == null || _selectedDateIso.isEmpty) return;
    setState(() => _remoteLoading = true);
    try {
      final type = _reservationType == ReservationType.individual ? 'individual' : 'group';
      final list = await ReservationApi().getWorkspaces(
        date: _selectedDateIso,
        slotId: sid,
        type: type,
      );
      if (!mounted) return;
      setState(() {
        _remoteWorkspaces = list.isNotEmpty ? list : null;
        _remoteLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _remoteWorkspaces = null;
        _remoteLoading = false;
      });
    }
  }

  Iterable<Workspace> get _filteredWorkspaces {
    final list = _layoutWorkspaces;
    switch (_filter) {
      case _DeskFilter.all:
        return list;
      case _DeskFilter.individual:
        return list.where((w) => w.type == 'individual');
      case _DeskFilter.group:
        return list.where((w) => w.type == 'group');
    }
  }

  bool _lostAt(String workspaceId) => _lostWorkspaceIds.contains(workspaceId);

  bool _isInstantDesk(String id) => ReservationMockData.instantDeskIds.contains(id);

  /// Non–Mon/Fri: map highlights only cells that are instant id + actually free.
  bool get _isInstantMapMode => false; // Always allow interaction to let backend handle rules

  bool _isInstantBookableCell(Workspace ws) {
    if (!ReservationMockData.instantDeskIds.contains(ws.id)) return false;
    if (_isBaseOccupied(ws)) return false;
    return true;
  }

  Color _fillForWorkspace(Workspace ws) {
    if (_isInstantMapMode) {
      if (_isInstantBookableCell(ws)) return const Color(0xFF60A5FA);
      return const Color(0xFFDC2626);
    }
    if (ws.status == 'occupied') return const Color(0xFFF87171);
    return const Color(0xFF60A5FA);
  }

  Color _strokeForWorkspace(Workspace ws) {
    if (_isInstantMapMode) {
      if (_isInstantBookableCell(ws)) return const Color(0xFF2563EB);
      return const Color(0xFF7F1D1D);
    }
    if (ws.status == 'occupied') return const Color(0xFFDC2626);
    return const Color(0xFF2563EB);
  }

  double _opacityForWorkspace(Workspace ws) {
    if (_canReserveAdvance) return 1;
    if (_isInstantBookableCell(ws)) return 1;
    return 0.38;
  }

  bool _typeMismatch(Workspace ws) {
    if (_reservationType == ReservationType.individual && ws.type == 'group') return true;
    if (_reservationType == ReservationType.group && ws.type == 'individual') return true;
    return false;
  }

  bool _isBaseOccupied(Workspace ws) => ws.status == 'occupied';

  bool _isWorkspaceOccupied(String workspaceId) {
    if (_isInstantDesk(workspaceId)) {
      // Instant desks are explicit last-minute openings.
      return false;
    }
    final ws = _workspaceById(workspaceId);
    if (ws == null) return false;
    if (_isBaseOccupied(ws)) return true;
    return false;
  }

  String get _selectedDateIso =>
      '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  void _onWorkspaceTap(Workspace ws) {
    if (_typeMismatch(ws)) return;

    if (_lostAt(ws.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Note: A lost item was reported here.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    if (_isInstantMapMode) {
      if (!_isInstantBookableCell(ws)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Today only instant desks can be selected — pick a bright blue desk.')),
        );
        return;
      }
    }
    if (_isBaseOccupied(ws)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This workspace is occupied')));
      return;
    }

    setState(() {
      _selectedWorkspaceId = ws.id;
      if (_isInstantDesk(ws.id)) {
        _selectedDate = DateTime.now();
        if (ws.id == 'desk-2') {
          _selectedSlot = '09:00 - 11:00 (Class Time)';
        } else if (ws.id == 'desk-15') {
          _selectedSlot = '13:00 - 15:00 (Class Time)';
        }
      }
    });
    _reloadWorkspacesFromServer();
  }

  void _addNickname() {
    final ws = _workspaceById(_selectedWorkspaceId);
    if (ws == null) return;
    final nick = _nicknameCtrl.text.trim();
    if (nick.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter nickname')));
      return;
    }
    if (_groupNicknames.contains(nick)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nickname already added')));
      return;
    }
    if (_groupNicknames.length >= ws.capacity - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Max ${ws.capacity - 1} members')),
      );
      return;
    }
    setState(() {
      _groupNicknames.add(nick);
      _nicknameCtrl.clear();
    });
  }

  Future<void> _confirmReservation() async {
    final block = ResponsibilityLedger.instance.canAttemptReservation();
    if (block != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(block)));
      return;
    }
    if (_selectedWorkspaceId == null || _selectedSlot.isEmpty || _selectedCourse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all fields')));
      return;
    }

    final instant = _isInstantDesk(_selectedWorkspaceId!);
    if (!_canReserveAdvance && !instant) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advance booking only on Mon & Fri — or pick an instant slot')),
      );
      return;
    }

    final ws = _workspaceById(_selectedWorkspaceId);
    if (_reservationType == ReservationType.group && ws != null) {
      if (_groupNicknames.length != ws.capacity - 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Add ${ws.capacity - 1} group member nicknames')),
        );
        return;
      }
    }

    final slotId = _selectedSlotId;
    if (slotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a valid slot')));
      return;
    }
    if (!CheckInWindow.isSlotBookableForDate(
      dateIso: _selectedDateIso,
      slotId: slotId,
      slotLabel: _selectedSlot,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This time slot has already started. Choose a later slot today or another day.'),
        ),
      );
      return;
    }

    setState(() => _submittingReservation = true);
    try {
      final created = await _api.createReservation(
        date: _selectedDateIso,
        slotId: slotId,
        workspaceId: _selectedWorkspaceId!,
        courseCode: _selectedCourse,
        reservationType: _reservationType == ReservationType.group ? 'GROUP' : 'INDIVIDUAL',
        allowStudyBuddy: _allowStudyBuddy,
        participantNicknames: List<String>.from(_groupNicknames),
      );
      if (!mounted) return;
      final msg = instant
          ? 'Instant reservation confirmed (${created.id})'
          : (_reservationType == ReservationType.group ? 'Invites sent (${created.id})' : 'Reservation confirmed (${created.id})');
      ResponsibilityLedger.instance.recordReservationConfirmed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() {
        _selectedWorkspaceId = null;
        _selectedSlot = '';
        _selectedCourse = '';
        _groupNicknames.clear();
        _sheetExpanded = false;
      });
      await _reloadWorkspacesFromServer();
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      final backendMessage = _extractBackendMessage(e.response?.data);
      if (status == 401 || status == 403) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session expired. Please sign in again.')));
      } else if (status == 400 || status == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(backendMessage ?? 'This slot is no longer available.')),
        );
      } else if (status == 500 && backendMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(backendMessage)));
      } else if (status == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot reach backend.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reservation failed (HTTP $status)')));
      }
    } finally {
      if (mounted) setState(() => _submittingReservation = false);
    }
  }

  String? _extractBackendMessage(dynamic data) {
    if (data == null) return null;
    if (data is Map && data['message'] != null) {
      final m = data['message'].toString().trim();
      return m.isEmpty ? null : m;
    }
    if (data is String) {
      final m = data.trim();
      return m.isEmpty ? null : m;
    }
    return null;
  }

  bool get _instantLocked =>
      _selectedWorkspaceId != null && _isInstantDesk(_selectedWorkspaceId!);

  bool get _showConfirmButton => _selectedWorkspaceId != null;

  void _applyAiPrefill(ReservePrefill p) {
    final d = DateTime.tryParse(p.dateIso);
    if (d == null) return;
    final sun0 = _dartWeekdayToSun0(d.weekday);
    setState(() {
      _selectedDate = d;
      _simulatedDay = sun0;
      _selectedSlot = p.slotLabel;
      _selectedCourse = p.courseCode;
      _sheetExpanded = true;
    });
    _reloadWorkspacesFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterRow(),
                  const SizedBox(height: 6),
                  _buildResponsibilityPolicyBanner(),
                  const SizedBox(height: 6),
                  _buildLegend(),
                  const SizedBox(height: 8),
                  if (_remoteLoading) const LinearProgressIndicator(minHeight: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, top: 2),
                    child: Text(
                      _layoutStatusCaption,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  _buildMap(),
                  const SizedBox(height: 10),
                  _buildInfoBanner(),
                  const SizedBox(height: 10),
                  _buildAiSuggestionShortcut(),
                ],
              ),
            ),
          ),
          _buildBottomSheet(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF111827) : Colors.white,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 6, 12, 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Reserve Space',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              ),
            ),
            _DayMenu(
              currentLabel: _currentDayName,
              selectedIndex: _simulatedDay,
              // Antigravity Modification: Now calls the helper to sync date with day label.
              onSelect: _updateSimulatedDay,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          'Study Area',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
          ),
        ),
        const Spacer(),
        _tinyFilterChip('All', _filter == _DeskFilter.all, () => setState(() => _filter = _DeskFilter.all)),
        const SizedBox(width: 4),
        _tinyFilterIcon(_filter == _DeskFilter.individual, Icons.person_outline_rounded, () => setState(() => _filter = _DeskFilter.individual)),
        const SizedBox(width: 4),
        _tinyFilterIcon(_filter == _DeskFilter.group, Icons.groups_2_outlined, () => setState(() => _filter = _DeskFilter.group)),
      ],
    );
  }

  Widget _tinyFilterChip(String label, bool selected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF111827)
              : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _tinyFilterIcon(bool selected, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF111827)
              : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 12, color: selected ? Colors.white : const Color(0xFF6B7280)),
      ),
    );
  }

  Widget _buildLegend() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget dot(Color fill, Color border) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: border),
        ),
      );
    }

    if (_isInstantMapMode) {
      return Row(
        children: [
          dot(const Color(0xFF60A5FA), const Color(0xFF2563EB)),
          const SizedBox(width: 4),
          Text('Open now', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade700)),
          const SizedBox(width: 10),
          dot(
            const Color(0xFFDC2626).withValues(alpha: 0.45),
            const Color(0xFF7F1D1D).withValues(alpha: 0.5),
          ),
          const SizedBox(width: 4),
          Text('Not open', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade700)),
          const SizedBox(width: 10),
          _lostLegendRow(isDark),
        ],
      );
    }
    return Row(
      children: [
        dot(const Color(0xFF60A5FA), const Color(0xFF2563EB)),
        const SizedBox(width: 4),
        Text('Free', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade700)),
        const SizedBox(width: 10),
        dot(const Color(0xFFF87171), const Color(0xFFDC2626)),
        const SizedBox(width: 4),
        Text('Busy', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade700)),
        const SizedBox(width: 10),
        _lostLegendRow(isDark),
      ],
    );
  }

  Widget _lostLegendRow(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LostMapBadge(size: 20),
        const SizedBox(width: 6),
        Text('Lost item', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildMap() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final h = maxW * (ReservationMockData.mapHeight / ReservationMockData.mapWidth);
        final sx = maxW / ReservationMockData.mapWidth;
        final sy = h / ReservationMockData.mapHeight;
        final layout = _layoutWorkspaces;
        final groupRooms = layout.where((w) => w.type == 'group').toList();
        final groupLabelY = groupRooms.isEmpty
            ? 220.0 * sy
            : (groupRooms.map((w) => w.y).reduce(math.min) * sy - 20).clamp(8.0, h - 28);

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: maxW,
            height: h,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Text(
                    'Individual Desks',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFD1D5DB) : Colors.grey.shade600,
                    ),
                  ),
                ),
                Positioned(
                  top: groupLabelY,
                  left: 0,
                  right: 0,
                  child: Text(
                    'Group Rooms',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFD1D5DB) : Colors.grey.shade600,
                    ),
                  ),
                ),
                ..._filteredWorkspaces.map((ws) {
                  final w = (ws.type == 'individual' ? 35 : 70) * sx;
                  final hi = (ws.type == 'individual' ? 50 : 100) * sy;
                  final blocked = _isInstantMapMode
                      ? (_typeMismatch(ws) || (!_isInstantBookableCell(ws) && !_lostAt(ws.id)))
                      : (_typeMismatch(ws) || _isBaseOccupied(ws));
                  final selected = _selectedWorkspaceId == ws.id;
                  final op = _opacityForWorkspace(ws);

                  return Positioned(
                    left: ws.x * sx,
                    top: ws.y * sy,
                    width: w,
                    height: hi,
                    child: Opacity(
                      opacity: op,
                      child: GestureDetector(
                        onTap: blocked ? null : () => _onWorkspaceTap(ws),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                decoration: BoxDecoration(
                                  color: _lostAt(ws.id) && ws.status == 'occupied' ? null : _fillForWorkspace(ws),
                                  gradient: _lostAt(ws.id) && ws.status == 'occupied'
                                      ? const LinearGradient(
                                          colors: [Color(0xFFF87171), Color(0xFFFBBF24)],
                                          stops: [0.5, 0.5],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(ws.type == 'individual' ? 3 : 6),
                                  border: Border.all(
                                    color: _lostAt(ws.id) ? const Color(0xFFF59E0B) : _strokeForWorkspace(ws),
                                    width: _lostAt(ws.id) ? 3 : (selected ? 3 : 2),
                                  ),
                                ),
                                child: Center(
                                  child: ws.type == 'individual'
                                      ? Text(
                                          ws.id.split('-').last,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        )
                                      : FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _groupRoomLabel(ws.id),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                Text(
                                                  'Cap ${ws.capacity}',
                                                  style: const TextStyle(color: Colors.white, fontSize: 8),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            if (_lostAt(ws.id))
                              const Positioned(
                                top: -10,
                                right: -10,
                                child: LostMapBadge(size: 28),
                              ),
                          ],
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
    );
  }

  Widget _buildResponsibilityPolicyBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: ResponsibilityLedger.instance,
      builder: (context, _) {
        final L = ResponsibilityLedger.instance;
        final line = L.reserveDemoBannerLine();
        final high = L.effectiveScore >= 85;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? (high ? const Color(0xFF1C2E1E) : const Color(0xFF1E2A3D))
                : (high ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: high
                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFFA7F3D0))
                  : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFFDE68A)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                high ? Icons.verified_user_outlined : Icons.tune_rounded,
                size: 16,
                color: high ? const Color(0xFF059669) : const Color(0xFFD97706),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$line\n'
                  'This session: ${L.reservationsThisSession}/${L.maxReservationsThisSessionForScore()} bookings used (demo).',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.35,
                    color: isDark ? const Color(0xFFECFDF5) : (high ? const Color(0xFF14532D) : const Color(0xFF713F12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1F2937), Color(0xFF111827)]
              : const [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 10,
                height: 1.35,
                color: isDark ? const Color(0xFFD1D5DB) : Colors.grey.shade800,
              ),
              children: _isInstantMapMode
                  ? const [
                      TextSpan(text: 'Bright blue', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                      TextSpan(text: ' = open for instant today · '),
                      TextSpan(text: 'Faded red', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF991B1B))),
                      TextSpan(text: ' = not available · '),
                      TextSpan(text: 'Faded yellow', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                      TextSpan(text: ' = lost item'),
                    ]
                  : const [
                      TextSpan(text: 'Bright', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                      TextSpan(text: ' = Available · '),
                      TextSpan(text: 'Red', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                      TextSpan(text: ' = Occupied · '),
                      TextSpan(text: 'Yellow', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                      TextSpan(text: ' = Lost item'),
                    ],
            ),
            textAlign: TextAlign.center,
          ),
          Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _isInstantMapMode
                  ? 'Tap a bright blue desk only. Date & time auto-fill, then confirm.'
                  : 'How to reserve: 1) Date  2) Time  3) Tap a workspace on the map. Red = occupied.',
              style: TextStyle(
                fontSize: 9,
                height: 1.4,
                color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 8,
      color: isDark ? const Color(0xFF111827) : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _sheetExpanded = !_sheetExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedWorkspaceId != null ? '$_selectedWorkspaceId selected' : 'Select workspace',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  Icon(_sheetExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_sheetExpanded)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _policyBanner(),
                    if (!_canReserveAdvance) _instantPolicyBanner(),
                    const SizedBox(height: 12),
                    Text('Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _typeButton(
                            label: 'Individual',
                            icon: Icons.person_outline_rounded,
                            selected: _reservationType == ReservationType.individual,
                            onTap: () {
                              setState(() => _reservationType = ReservationType.individual);
                              _reloadWorkspacesFromServer();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _typeButton(
                            label: 'Group',
                            icon: Icons.groups_2_outlined,
                            selected: _reservationType == ReservationType.group,
                            onTap: () {
                              setState(() => _reservationType = ReservationType.group);
                              _reloadWorkspacesFromServer();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _instantLocked
                          ? null
                          : () async {
                              final now = DateTime.now();
                              final todayStart = DateTime(now.year, now.month, now.day);
                              final selectedStart = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                              );
                              final d = await showDatePicker(
                                context: context,
                                initialDate: selectedStart.isBefore(todayStart) ? todayStart : _selectedDate,
                                firstDate: todayStart,
                                lastDate: DateTime(2027, 12, 31),
                              );
                              if (d != null) {
                                setState(() {
                                  _selectedDate = d;
                                  // Antigravity Modification: Sync the Top Day Menu label when a calendar date is picked.
                                  _simulatedDay = _dartWeekdayToSun0(d.weekday);
                                  _prunePastSelectedSlot();
                                });
                                _reloadWorkspacesFromServer();
                              }
                            },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          fillColor: _instantLocked ? const Color(0xFFF3F4F6) : Colors.white,
                          filled: _instantLocked,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_selectedDateIso, style: TextStyle(fontSize: 12, color: _instantLocked ? Colors.grey : Colors.black87)),
                            Icon(Icons.calendar_today_outlined, size: 16, color: _instantLocked ? Colors.grey : const Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                    ),
                    if (_instantLocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Auto-filled for instant booking',
                          style: TextStyle(fontSize: 9, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text('Time slot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('slot_${_selectedSlot}_$_instantLocked'),
                      initialValue: _selectedSlot.isEmpty ? null : _selectedSlot,
                      isExpanded: true,
                      hint: const Text('Select time slot', style: TextStyle(fontSize: 12)),
                      items: _selectableTimeSlots
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.label,
                              child: Text(s.label, style: const TextStyle(fontSize: 12)),
                            ),
                          )
                          .toList(),
                      onChanged: _instantLocked
                          ? null
                          : (v) {
                              setState(() => _selectedSlot = v ?? '');
                              _reloadWorkspacesFromServer();
                            },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        fillColor: _instantLocked ? const Color(0xFFF3F4F6) : Colors.white,
                        filled: _instantLocked,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Course', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('course_$_selectedCourse'),
                      initialValue: _selectedCourse.isEmpty ? null : _selectedCourse,
                      isExpanded: true,
                      hint: const Text('Select course', style: TextStyle(fontSize: 12)),
                      items: _userCourses
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.code,
                              child: Text('${c.code} — ${c.name}', style: const TextStyle(fontSize: 12)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCourse = v ?? ''),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (_reservationType == ReservationType.group && _selectedWorkspaceId != null) ...[
                      const SizedBox(height: 14),
                      _groupPanel(),
                    ],
                    if (_reservationType == ReservationType.individual) ...[
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _allowStudyBuddy,
                        onChanged: (v) => setState(() => _allowStudyBuddy = v ?? false),
                        title: const Text('Allow study buddy matching', style: TextStyle(fontSize: 12)),
                        controlAffinity: ListTileControlAffinity.leading,
                        fillColor: WidgetStateProperty.resolveWith((s) {
                          if (s.contains(WidgetState.selected)) return const Color(0xFF9333EA);
                          return null;
                        }),
                      ),
                    ],
                    if (_showConfirmButton) ...[
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: (!_submittingReservation &&
                                _selectedWorkspaceId != null &&
                                _selectedSlot.isNotEmpty &&
                                _selectedCourse.isNotEmpty &&
                                !_isWorkspaceOccupied(_selectedWorkspaceId!))
                            ? _confirmReservation
                            : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF2563EB),
                        ),
                        child: _submittingReservation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _instantLocked ? 'Instant reserve' : 'Confirm reservation',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiSuggestionShortcut() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: AiStudyController.instance,
      builder: (context, _) {
        if (_hideAiShortcut) return const SizedBox.shrink();
        final list = AiStudyController.instance.suggestions;
        if (list.isEmpty) return const SizedBox.shrink();
        final s = list.first;
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
                      gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Suggestions',
                    style: TextStyle(
                      fontSize: 13,
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
                  fontSize: 11,
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
    );
  }

  Widget _policyBanner() {
    String title;
    final today = DateTime.now();
    final isMon = today.weekday == DateTime.monday;
    final isFri = today.weekday == DateTime.friday;

    if (isMon) {
      title = 'Monday: reserve for whole week';
    } else if (isFri) {
      title = 'Friday: reserve Sat–Mon';
    } else {
      title = '$_currentDayName: instant booking only';
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title\nCancel ≥24h early: +3 · No-show: -10',
              style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF1E3A8A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instantPolicyBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mon opens Tue–Fri · Fri opens Sat–Mon · Bright desks may be cancelled slots',
                style: TextStyle(fontSize: 10, height: 1.35, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? const Color(0xFF2563EB) : const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? const Color(0xFF2563EB) : const Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _groupPanel() {
    final ws = _workspaceById(_selectedWorkspaceId);
    if (ws == null) return const SizedBox.shrink();
    final need = ws.capacity - 1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group members ($_groupNicknames.length / $need)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF581C87)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nicknameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Nickname',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onSubmitted: (_) => _addNickname(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addNickname,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9333EA)),
                child: const Text('Add'),
              ),
            ],
          ),
          ..._groupNicknames.map(
            (n) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(child: Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  TextButton(
                    onPressed: () => setState(() => _groupNicknames.remove(n)),
                    child: const Text('Remove', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Members must accept within 10 minutes',
            style: TextStyle(fontSize: 9, color: Colors.purple.shade800),
          ),
        ],
      ),
    );
  }
}

class _DayMenu extends StatelessWidget {
  const _DayMenu({
    required this.currentLabel,
    required this.selectedIndex,
    required this.onSelect,
  });

  final String currentLabel;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      offset: const Offset(0, 36),
      onSelected: onSelect,
      itemBuilder: (context) => List.generate(
        7,
        (i) => PopupMenuItem(
          value: i,
          child: Text(
            _kDayNames[i],
            style: TextStyle(
              fontWeight: i == selectedIndex ? FontWeight.w800 : FontWeight.w500,
              color: i == selectedIndex ? const Color(0xFF2563EB) : null,
            ),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFDBEAFE),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more_rounded, size: 14, color: Color(0xFF1D4ED8)),
          ],
        ),
      ),
    );
  }
}
