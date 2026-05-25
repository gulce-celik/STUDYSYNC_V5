import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/demo/buddy_interaction_log.dart';
import '../../../core/planner/ai_study_controller.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/trust/responsibility_ledger.dart';
import '../../reservation/data/reservation_mock_data.dart';
import '../../schedule/data/schedule_api.dart';
import '../../schedule/data/schedule_mock_data.dart';
import '../data/study_buddy_api.dart';
import '../data/study_buddy_mock_data.dart';
import '../../home/data/home_mock_data.dart';

/// Figma Make / React `StudyBuddy.tsx` — filtre + GET /study-buddies/suggestions; boşta mock.
class StudyBuddyScreen extends StatefulWidget {
  const StudyBuddyScreen({super.key});

  @override
  State<StudyBuddyScreen> createState() => _StudyBuddyScreenState();
}

class _StudyBuddyScreenState extends State<StudyBuddyScreen> {
  final _api = StudyBuddyApi();
  final _scheduleApi = ScheduleApi();
  String _courseCode = '';
  String _slotId = 'slot-2';
  String _selectedYear = '';
  String _selectedPreference = '';
  String _genderPreference = '';
  int _minSessionMinutes = 0;
  String _preferredWeekday = '';
  String _focusFilter = '';
  int _minMatchScore = 0;
  String? _aiBuddySuggestion;
  String? _suggestedCourseCode;
  String? _suggestedSlotId;
  /// AI’den türetilen; sadece [Apply] basılınca filtre alanlarına kopyalanır
  String? _aiSuggestedWeekday;
  String? _aiSuggestedYearLabel;
  String? _upcomingExamCourse;
  DateTime? _upcomingExamDate;
  List<StudyBuddyMockRow> _results = [];
  bool _loading = false;
  bool _fromFallback = true;
  bool _showFilters = false;
  bool _showMyListing = false;

  final _myListingNote = TextEditingController();
  String _myListingCourse = '';
  /// e.g. Exam prep, project — required to post
  String _myListingPurpose = '';
  String _myListingPreferredWeekday = '';
  String _myListingPreferredSlotId = 'slot-2';

  final _reportReason = TextEditingController();
  final _reportComment = TextEditingController();
  int _sectionIndex = 0;

  @override
  void initState() {
    super.initState();
    ResponsibilityLedger.instance.setHomeContext(mockOnly: HomeMockData.responsibilityScore);
    _courseCode = ReservationMockData.courses.isNotEmpty ? ReservationMockData.courses.first.code : 'CSE344';
    _myListingCourse = _courseCode;
    _results = List.of(StudyBuddyMockData.buddies);
    _prepareAiBuddySuggestion();
  }

  @override
  void dispose() {
    _myListingNote.dispose();
    _reportReason.dispose();
    _reportComment.dispose();
    super.dispose();
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  static const _kShortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String? _academicYearFromSession() {
    final y = AuthSession.instance.userYear;
    if (y == null || y < 1 || y > 4) return null;
    return switch (y) {
      1 => 'Freshman',
      2 => 'Sophomore',
      3 => 'Junior',
      4 => 'Senior',
      _ => null,
    };
  }

  String? _weekdayFromMessage(String? message) {
    if (message == null || message.isEmpty) return null;
    final m = RegExp(r'(?:^|\s)(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\b').firstMatch(message);
    return m?.group(1);
  }

  String? _weekdayFromDateIso(String? dateIso) {
    if (dateIso == null || dateIso.isEmpty) return null;
    final d = DateTime.tryParse(dateIso);
    if (d == null) return null;
    return _kShortDays[d.weekday - 1];
  }

  TextStyle _filterLabelStyle(bool isDark) {
    return TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E3A8A),
    );
  }

  InputDecoration _filterFieldDecoration(bool isDark) {
    return InputDecoration(
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }

  bool _passesLocalFilters(StudyBuddyMockRow row) {
    if (row.matchScore < _minMatchScore) return false;

    if (_selectedYear.isNotEmpty) {
      if (row.academicYear != null && row.academicYear!.isNotEmpty) {
        if (row.academicYear != _selectedYear) return false;
      }
    }
    if (_selectedPreference.isNotEmpty) {
      if (row.studyStyle != null && row.studyStyle!.isNotEmpty) {
        if (row.studyStyle != _selectedPreference) return false;
      }
    }
    if (_genderPreference.isNotEmpty) {
      if (row.gender != null && row.gender!.isNotEmpty) {
        if (row.gender != _genderPreference) return false;
      }
    }
    if (_minSessionMinutes > 0) {
      if (row.sessionLengthOfferedMinutes != null) {
        if (row.sessionLengthOfferedMinutes! < _minSessionMinutes) return false;
      }
    }
    if (_preferredWeekday.isNotEmpty) {
      if (row.typicalWeekday != null && row.typicalWeekday!.isNotEmpty) {
        if (row.typicalWeekday != _preferredWeekday) return false;
      }
    }
    if (_focusFilter.isNotEmpty) {
      if (row.studyFocus != null && row.studyFocus!.isNotEmpty) {
        if (row.studyFocus != _focusFilter) return false;
      }
    }
    return true;
  }

  Future<void> _prepareAiBuddySuggestion() async {
    final controllerItems = AiStudyController.instance.suggestions;
    String? suggestionMessage;
    String? suggestedCourse;
    String? suggestedSlot;
    String? aiWeek;
    final aiYear = _academicYearFromSession();

    if (controllerItems.isNotEmpty) {
      final first = controllerItems.first;
      suggestionMessage = first.message;
      suggestedCourse = first.courseCode;
      suggestedSlot = _slotIdFromLabel(first.slotLabel);
      aiWeek = _weekdayFromMessage(first.message) ?? _weekdayFromDateIso(first.dateIso);
    }

    try {
      final weekly = await _scheduleApi.getWeekly();
      if (!mounted) return;
      final upcomingExam = _nearestUpcomingExam(weekly);
      if (upcomingExam != null) {
        final examCourse = (upcomingExam.courseCode ?? _extractCourseCode(upcomingExam.label) ?? '').toUpperCase();
        final examDate = upcomingExam.examDate;
        if (examCourse.isNotEmpty && examDate != null) {
          suggestionMessage =
              'AI Suggestion: You have a $examCourse exam on ${_formatDate(examDate)}. Find a study buddy for a focused revision session.';
          suggestedCourse = examCourse;
        }
        setState(() {
          _upcomingExamCourse = examCourse.isEmpty ? null : examCourse;
          _upcomingExamDate = examDate;
          _aiBuddySuggestion = suggestionMessage;
          _suggestedCourseCode = suggestedCourse;
          _suggestedSlotId = suggestedSlot;
          _aiSuggestedWeekday = examDate != null ? _kShortDays[examDate.weekday - 1] : null;
          _aiSuggestedYearLabel = aiYear;
        });
        return;
      }
    } on DioException {
      // Keep local suggestion fallback.
    } catch (_) {
      // Keep local suggestion fallback.
    }

    setState(() {
      _aiBuddySuggestion = suggestionMessage ?? 'AI Suggestion: Try matching with a buddy for your next tough course this week.';
      _suggestedCourseCode = suggestedCourse;
      _suggestedSlotId = suggestedSlot;
      _aiSuggestedWeekday = aiWeek;
      _aiSuggestedYearLabel = aiYear;
    });
  }

  ScheduleBlock? _nearestUpcomingExam(List<ScheduleBlock> blocks) {
    final today = DateTime.now();
    final nowDate = DateTime(today.year, today.month, today.day);
    final exams = blocks
        .where((b) => b.type == ScheduleBlockType.exam && b.examDate != null)
        .where((b) {
          final d = b.examDate!;
          final examDate = DateTime(d.year, d.month, d.day);
          return !examDate.isBefore(nowDate);
        })
        .toList();
    if (exams.isEmpty) return null;
    exams.sort((a, b) => a.examDate!.compareTo(b.examDate!));
    return exams.first;
  }

  String? _slotIdFromLabel(String? label) {
    if (label == null || label.isEmpty) return null;
    for (final slot in ReservationMockData.timeSlots) {
      if (slot.label == label) return slot.id;
    }
    return null;
  }

  String _formatDate(DateTime d) {
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${monthNames[d.month - 1]}';
  }

  String? _extractCourseCode(String? label) {
    if (label == null || label.isEmpty) return null;
    final r = RegExp(r'([A-Z]{2,4})-?(\d{3})').firstMatch(label.toUpperCase());
    if (r == null) return null;
    return '${r.group(1)}${r.group(2)}';
  }

  Future<void> _search() async {
    if (_courseCode.isEmpty) {
      _toast('Select a course');
      return;
    }
    setState(() => _loading = true);
    try {
      final raw = await _api.getSuggestions(courseCode: _courseCode, slotId: _slotId);
      if (!mounted) return;
      if (raw.isEmpty) {
        setState(() {
          var list = StudyBuddyMockData.buddies
              .where((b) => b.commonCourses.any((c) => c == _courseCode))
              .where(_passesLocalFilters)
              .toList();
          if (list.isEmpty) {
            list = StudyBuddyMockData.buddies.where((b) => b.commonCourses.any((c) => c == _courseCode)).toList();
          }
          if (list.isEmpty) {
            list = List.of(StudyBuddyMockData.buddies);
          }
          _results = list;
          _fromFallback = true;
          _loading = false;
          _showFilters = false;
        });
        _toast('Server returned no matches — using sample data with your filters (relaxed if needed).');
        return;
      }
      final mapped = raw.map((m) {
        final cc = m['commonCourses'];
        final ct = m['commonTopics'];
        return StudyBuddyMockRow(
          userId: m['userId']?.toString() ?? '',
          name: m['name']?.toString() ?? '',
          matchScore: (m['matchScore'] as num?)?.toInt() ?? 0,
          commonCourses: cc is List ? cc.map((e) => e.toString()).toList() : <String>[],
          commonTopics: ct is List ? ct.map((e) => e.toString()).toList() : <String>[],
          gender: m['gender']?.toString(),
          academicYear: m['academicYear']?.toString(),
          studyStyle: m['studyStyle']?.toString(),
          typicalWeekday: m['typicalWeekday']?.toString(),
          sessionLengthOfferedMinutes: (m['sessionLengthOfferedMinutes'] as num?)?.toInt(),
          studyFocus: m['studyFocus']?.toString(),
        );
      }).toList();
      setState(() {
        _results = mapped.where(_passesLocalFilters).toList();
        if (_results.isEmpty && mapped.isNotEmpty) {
          _results = mapped;
          _toast('No API rows match strict filters — showing all server results.');
        }
        _fromFallback = false;
        _loading = false;
        _showFilters = false;
      });
    } on DioException {
      if (!mounted) return;
      setState(() {
        var list = StudyBuddyMockData.buddies
            .where((b) => b.commonCourses.any((c) => c == _courseCode))
            .where(_passesLocalFilters)
            .toList();
        if (list.isEmpty) {
          list = List.of(StudyBuddyMockData.buddies);
        }
        _results = list;
        _fromFallback = true;
        _loading = false;
        _showFilters = false;
      });
      _toast('Offline: sample buddies (filters applied when data allows).');
    }
  }

  static bool _actionSuccess(dynamic value) => value == true || value == 'true';

  static String _dioErrorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return 'Log in required (HTTP $code).';
    if (code != null) return '$fallback (HTTP $code)';
    return fallback;
  }

  void _openReportDialog(StudyBuddyMockRow buddy) {
    _reportReason.clear();
    _reportComment.clear();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var submitting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Report User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reporting ${buddy.name}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reportReason,
                      enabled: !submitting,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason *',
                        hintText: 'Describe inappropriate behavior...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reportComment,
                      enabled: !submitting,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Comment (optional)',
                        hintText: 'Additional context for moderators...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (_reportReason.text.trim().isEmpty) {
                            _toast('Please enter a report reason.');
                            return;
                          }
                          final token = AuthSession.instance.accessToken;
                          if (token == null || token.isEmpty) {
                            _toast('Log in to submit a report.');
                            return;
                          }
                          if (buddy.userId.trim().isEmpty) {
                            _toast('Cannot report this user — missing user id.');
                            return;
                          }
                          setDialogState(() => submitting = true);
                          try {
                            final res = await _api.submitReport(
                              reportedUserId: buddy.userId,
                              reason: _reportReason.text.trim(),
                              comment: _reportComment.text.trim(),
                            );
                            if (!ctx.mounted) return;
                            if (!_actionSuccess(res['success'])) {
                              setDialogState(() => submitting = false);
                              _toast(res['message']?.toString() ?? 'Report failed — try again.');
                              return;
                            }
                            BuddyInteractionLog.add(
                              buddyName: buddy.name,
                              reportedUserId: buddy.userId,
                              reportReason: _reportReason.text.trim(),
                              comment: _reportComment.text.trim(),
                            );
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            setState(() => _sectionIndex = 1);
                            _toast('Report submitted — see Previous tab.');
                          } on DioException catch (e) {
                            if (!ctx.mounted) return;
                            setDialogState(() => submitting = false);
                            _toast(_dioErrorMessage(e, 'Could not submit report'));
                          } catch (_) {
                            if (!ctx.mounted) return;
                            setDialogState(() => submitting = false);
                            _toast('Could not submit report.');
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTabs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: const Text('Find', style: TextStyle(fontWeight: FontWeight.w700)),
              selected: _sectionIndex == 0,
              onSelected: _loading ? null : (_) => setState(() => _sectionIndex = 0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: Text(
                'Previous (${BuddyInteractionLog.entries.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              selected: _sectionIndex == 1,
              onSelected: _loading ? null : (_) => setState(() => _sectionIndex = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousTab(bool isDark) {
    final entries = BuddyInteractionLog.entries;
    if (entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SizedBox(height: 24),
          Icon(Icons.history_rounded, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(
            'No reports yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use Report on a buddy card. Entries stay in this session until the backend stores moderation history.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Session reports & comments',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827)),
        ),
        const SizedBox(height: 8),
        ...entries.map(
          (e) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(e.buddyName, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Reason: ${e.reportReason}', style: const TextStyle(fontSize: 12, height: 1.35)),
                  if (e.comment.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Comment: ${e.comment}', style: const TextStyle(fontSize: 12, height: 1.35)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatReportTime(e.createdAt),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          ),
        ),
      ],
    );
  }

  String _formatReportTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }

  void _submitMyListing() {
    if (_myListingCourse.isEmpty) {
      _toast('Select a course for your listing.');
      return;
    }
    if (_myListingPurpose.isEmpty) {
      _toast('Select what you are studying for (exam, project, etc.).');
      return;
    }
    final block = ResponsibilityLedger.instance.tryConsumeBuddyListing();
    if (block != null) {
      _toast(block);
      return;
    }
    var slotPart = '';
    for (final ts in ReservationMockData.timeSlots) {
      if (ts.id == _myListingPreferredSlotId) {
        slotPart = ts.label;
        break;
      }
    }
    final dayPart = _myListingPreferredWeekday.isEmpty
        ? 'any day'
        : _myListingPreferredWeekday;
    final details =
        '$_myListingCourse · $_myListingPurpose · prefers $dayPart'
        '${slotPart.isNotEmpty ? ' · $slotPart' : ''}';
    _toast(
      'Listing posted: $details '
      '(-${ResponsibilityLedger.scoreCostPerBuddyListing} score → ${ResponsibilityLedger.instance.effectiveScore}%)',
    );
    setState(() {
      _showMyListing = false;
      _myListingNote.clear();
      _myListingPurpose = '';
    });
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Buddy',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Find your perfect study partner',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildSectionTabs(isDark),
          Expanded(
            child: _sectionIndex == 1
                ? _buildPreviousTab(isDark)
                : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (_fromFallback)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      'Sample buddies shown — GET /study-buddies/suggestions is empty or offline. '
                      'Backend should implement matching for live API results.',
                      style: TextStyle(fontSize: 11, height: 1.35, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF92400E)),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF1F2937), Color(0xFF111827)]
                          : const [Color(0xFFF5F3FF), Color(0xFFFDF2F8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF374151) : const Color(0xFFE9D5FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How AI matching works',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• AI matching combines common courses, topics, and study preferences.\n'
                        '• Max 4 students per group rule is enforced on reserve flow.\n'
                        '• Report inappropriate behavior via Report button.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B21A8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'False reports may result in account restrictions.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
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
                            'AI Suggestion',
                            style: TextStyle(
                              fontSize: 14,
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
                              'Buddy match',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _aiBuddySuggestion ??
                            'AI Suggestion: Want to study with someone for your next course session?',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            if (_suggestedCourseCode != null && _suggestedCourseCode!.isNotEmpty) {
                              _courseCode = _suggestedCourseCode!;
                            }
                            if (_suggestedSlotId != null && _suggestedSlotId!.isNotEmpty) {
                              _slotId = _suggestedSlotId!;
                            }
                            if (_aiSuggestedWeekday != null && _aiSuggestedWeekday!.isNotEmpty) {
                              _preferredWeekday = _aiSuggestedWeekday!;
                            }
                            if (_aiSuggestedYearLabel != null && _aiSuggestedYearLabel!.isNotEmpty) {
                              _selectedYear = _aiSuggestedYearLabel!;
                            }
                            _minSessionMinutes = 120;
                            if (_upcomingExamDate != null) {
                              _minMatchScore = 70;
                              _focusFilter = 'Exam prep';
                            } else {
                              _focusFilter = '';
                            }
                            _showFilters = true;
                          });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Apply suggestion to filters'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      final open = !_showMyListing;
                      _showMyListing = open;
                      if (open) {
                        _myListingCourse = _courseCode;
                        _myListingPreferredWeekday = _preferredWeekday;
                        _myListingPreferredSlotId = _slotId;
                        if (_myListingPurpose.isEmpty && _focusFilter.isNotEmpty) {
                          if (_focusFilter == 'Exam prep') {
                            _myListingPurpose = 'Exam prep';
                          } else if (_focusFilter == 'Project work') {
                            _myListingPurpose = 'Project / assignment';
                          } else if (_focusFilter == 'Weekly reviews') {
                            _myListingPurpose = 'Lecture / weekly review';
                          }
                        }
                      }
                    });
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Create My Study Buddy Listing'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9333EA),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                if (_showMyListing) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E1B2E), const Color(0xFF1A1523)]
                            : [const Color(0xFFF5F3FF), const Color(0xFFFCE7F3)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF4C1D95) : const Color(0xFFE9D5FF),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Post your listing',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF3E8FF) : const Color(0xFF4C1D95),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Help others know why you want a buddy and when you usually study.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B21A8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ListenableBuilder(
                          listenable: ResponsibilityLedger.instance,
                          builder: (context, _) {
                            final L = ResponsibilityLedger.instance;
                            return Text(
                              '${L.buddyDemoLine()}\n'
                              'Used: ${L.listingsPosted}/${L.maxBuddyListingsPerSession} · '
                              'Each post: −${ResponsibilityLedger.scoreCostPerBuddyListing} pt · '
                              'Current: ${L.effectiveScore}%.',
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.25,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7C3AED),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Text('Course', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _myListingCourse.isEmpty ? null : _myListingCourse,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: ReservationMockData.courses
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.code,
                                  child: Text('${c.code} — ${c.name}', style: const TextStyle(fontSize: 13)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _myListingCourse = v ?? ''),
                        ),
                        const SizedBox(height: 10),
                        Text('What are you studying for? *', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _myListingPurpose.isEmpty ? null : _myListingPurpose,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          hint: const Text('Choose a goal'),
                          decoration: _filterFieldDecoration(isDark),
                          items: const [
                            DropdownMenuItem(value: 'Exam prep', child: Text('Exam prep')),
                            DropdownMenuItem(value: 'Project / assignment', child: Text('Project / assignment')),
                            DropdownMenuItem(
                              value: 'Homework & problem sets',
                              child: Text('Homework & problem sets'),
                            ),
                            DropdownMenuItem(
                              value: 'Lecture / weekly review',
                              child: Text('Lecture / weekly review'),
                            ),
                            DropdownMenuItem(value: 'General study', child: Text('General study')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (v) => setState(() => _myListingPurpose = v ?? ''),
                        ),
                        const SizedBox(height: 10),
                        Text('Preferred day (optional)', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _myListingPreferredWeekday.isEmpty ? null : _myListingPreferredWeekday,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('No preference')),
                            DropdownMenuItem(value: 'Mon', child: Text('Mon')),
                            DropdownMenuItem(value: 'Tue', child: Text('Tue')),
                            DropdownMenuItem(value: 'Wed', child: Text('Wed')),
                            DropdownMenuItem(value: 'Thu', child: Text('Thu')),
                            DropdownMenuItem(value: 'Fri', child: Text('Fri')),
                            DropdownMenuItem(value: 'Sat', child: Text('Sat')),
                            DropdownMenuItem(value: 'Sun', child: Text('Sun')),
                          ],
                          onChanged: (v) => setState(() => _myListingPreferredWeekday = v ?? ''),
                        ),
                        const SizedBox(height: 10),
                        Text('Preferred time on campus (optional)', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _myListingPreferredSlotId,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: ReservationMockData.timeSlots
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.label, style: const TextStyle(fontSize: 13, height: 1.2)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _myListingPreferredSlotId = v ?? _myListingPreferredSlotId),
                        ),
                        const SizedBox(height: 10),
                        Text('Note (optional)', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _myListingNote,
                          maxLines: 3,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark).copyWith(
                            alignLabelWithHint: true,
                            hintText: 'e.g. library quiet floor, work in English…',
                            hintStyle: TextStyle(
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListenableBuilder(
                          listenable: ResponsibilityLedger.instance,
                          builder: (context, _) {
                            final can = ResponsibilityLedger.instance.canPostAnotherBuddyListing;
                            return FilledButton(
                              onPressed: can ? _submitMyListing : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF7C3AED) : const Color(0xFF1E1B4B),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Post listing'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _showFilters = !_showFilters),
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                              : [const Color(0xFFF0F9FF), const Color(0xFFEFF6FF)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD)),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showFilters ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              color: const Color(0xFF2563EB),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _showFilters ? 'Hide filters' : 'Show filters',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_showFilters) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? const [Color(0xFF111827), Color(0xFF0F172A)]
                            : const [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 18, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(
                              'Smart Filters',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Course', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _courseCode.isEmpty ? null : _courseCode,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: ReservationMockData.courses
                              .map((c) => DropdownMenuItem(value: c.code, child: Text(c.code)))
                              .toList(),
                          onChanged: (v) => setState(() => _courseCode = v ?? ''),
                        ),
                        const SizedBox(height: 12),
                        Text('Time window (campus hours)', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _slotId,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: ReservationMockData.timeSlots
                              .map((s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(s.label, style: const TextStyle(fontSize: 14, height: 1.2)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _slotId = v ?? _slotId),
                        ),
                        const SizedBox(height: 12),
                        Text('Preferred day (typical, optional)', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _preferredWeekday.isEmpty ? null : _preferredWeekday,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('No preference')),
                            DropdownMenuItem(value: 'Mon', child: Text('Mon')),
                            DropdownMenuItem(value: 'Tue', child: Text('Tue')),
                            DropdownMenuItem(value: 'Wed', child: Text('Wed')),
                            DropdownMenuItem(value: 'Thu', child: Text('Thu')),
                            DropdownMenuItem(value: 'Fri', child: Text('Fri')),
                            DropdownMenuItem(value: 'Sat', child: Text('Sat')),
                            DropdownMenuItem(value: 'Sun', child: Text('Sun')),
                          ],
                          onChanged: (v) => setState(() => _preferredWeekday = v ?? ''),
                        ),
                        const SizedBox(height: 12),
                        Text('Minimum session length (buddy offers)', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: _minSessionMinutes,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('No minimum', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 60, child: Text('At least 1 hour', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 120, child: Text('At least 2 hours', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 180, child: Text('At least 3 hours', style: TextStyle(fontSize: 14, height: 1.2))),
                          ],
                          onChanged: (v) => setState(() => _minSessionMinutes = v ?? 0),
                        ),
                        const SizedBox(height: 12),
                        Text('Academic year (optional)', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedYear.isEmpty ? null : _selectedYear,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('No preference', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 'Freshman', child: Text('Freshman', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 'Sophomore', child: Text('Sophomore', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 'Junior', child: Text('Junior', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 'Senior', child: Text('Senior', style: TextStyle(fontSize: 14, height: 1.2))),
                          ],
                          onChanged: (v) => setState(() => _selectedYear = v ?? ''),
                        ),
                        const SizedBox(height: 12),
                        Text('Study style (optional)', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedPreference.isEmpty ? null : _selectedPreference,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('No preference', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 'Silent study', child: Text('Silent study', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(
                                value: 'Discussion-based study', child: Text('Discussion-based', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(
                                value: 'Problem solving together', child: Text('Problem solving', style: TextStyle(fontSize: 14, height: 1.2))),
                          ],
                          onChanged: (v) => setState(() => _selectedPreference = v ?? ''),
                        ),
                        const SizedBox(height: 12),
                        Text('Buddy gender (optional)', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _genderPreference.isEmpty ? null : _genderPreference,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('No preference', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 'Woman', child: Text('Woman', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 'Man', child: Text('Man', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 'Non-binary', child: Text('Non-binary', style: TextStyle(fontSize: 14, height: 1.2))),
                          ],
                          onChanged: (v) => setState(() => _genderPreference = v ?? ''),
                        ),
                        const SizedBox(height: 12),
                        Text('Study focus (optional)', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _focusFilter.isEmpty ? null : _focusFilter,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('No filter', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 'Exam prep', child: Text('Exam prep', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 'Project work', child: Text('Project work', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 'Weekly reviews', child: Text('Weekly reviews', style: TextStyle(fontSize: 14, height: 1.2))),
                          ],
                          onChanged: (v) => setState(() => _focusFilter = v ?? ''),
                        ),
                        const SizedBox(height: 12),
                        Text('Minimum AI match', style: _filterLabelStyle(isDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: _minMatchScore,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          decoration: _filterFieldDecoration(isDark),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Any score', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 70, child: Text('70% and above', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 80, child: Text('80% and above', style: TextStyle(fontSize: 14, height: 1.2))),
                            DropdownMenuItem(value: 90, child: Text('90% and above', style: TextStyle(fontSize: 14, height: 1.2))),
                          ],
                          onChanged: (v) => setState(() => _minMatchScore = v ?? 0),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _loading ? null : _search,
                          icon: _loading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.search_rounded),
                          label: const Text('Search buddies'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF9333EA),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Results (AI ranked)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(width: 8),
                    Text('${_results.length} matches', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                ),
                const SizedBox(height: 8),
                ..._results.map(
                  (b) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    const Text('Study partner', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                    if (b.gender != null || b.academicYear != null || b.studyStyle != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          if (b.gender != null && b.gender!.isNotEmpty) b.gender,
                                          if (b.academicYear != null && b.academicYear!.isNotEmpty) b.academicYear,
                                          if (b.studyStyle != null && b.studyStyle!.isNotEmpty) b.studyStyle,
                                        ].join(' · '),
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.3),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(999)),
                                child: Text(
                                  'AI ${b.matchScore}%',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'AI score is based on course overlap, topic similarity, and study style fit.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_upcomingExamCourse != null &&
                              _upcomingExamDate != null &&
                              b.commonCourses.map((e) => e.toUpperCase()).contains(_upcomingExamCourse)) ...[
                            Text(
                              'Exam overlap: You both have $_upcomingExamCourse focus before ${_formatDate(_upcomingExamDate!)}.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            'Common courses: ${b.commonCourses.join(", ")}\n'
                            'Common topics: ${b.commonTopics.take(3).join(", ")}',
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                          if (b.typicalWeekday != null ||
                              b.sessionLengthOfferedMinutes != null ||
                              (b.studyFocus != null && b.studyFocus!.isNotEmpty)) ...[
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (b.typicalWeekday != null && b.typicalWeekday!.isNotEmpty) 'Often: ${b.typicalWeekday}',
                                if (b.sessionLengthOfferedMinutes != null) '~${b.sessionLengthOfferedMinutes} min blocks',
                                if (b.studyFocus != null && b.studyFocus!.isNotEmpty) b.studyFocus!,
                              ].join(' · '),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), height: 1.35),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _toast('Request sent to ${b.name}.'),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                  label: const Text('Connect', style: TextStyle(fontSize: 15)),
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9333EA)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openReportDialog(b),
                                  icon: const Icon(Icons.flag_outlined, size: 18),
                                  label: const Text('Report', style: TextStyle(fontSize: 15)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
