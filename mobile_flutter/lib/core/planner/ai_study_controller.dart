import 'package:flutter/foundation.dart';

import '../../features/auth/data/registration_mock_data.dart';
import '../../features/reservation/data/reservation_mock_data.dart';
import '../../features/schedule/data/schedule_mock_data.dart';
import '../session/auth_session.dart';

class AiSuggestion {
  const AiSuggestion({
    required this.id,
    required this.title,
    required this.message,
    required this.courseCode,
    required this.slotLabel,
    required this.dateIso,
  });

  final String id;
  final String title;
  final String message;
  final String courseCode;
  final String slotLabel;
  final String dateIso;
}

class ReservePrefill {
  const ReservePrefill({
    required this.courseCode,
    required this.slotLabel,
    required this.dateIso,
  });

  final String courseCode;
  final String slotLabel;
  final String dateIso;
}

class AiStudyController extends ChangeNotifier {
  AiStudyController._() {
    _scheduleBlocks = List.of(ScheduleMockData.initialBlocks());
    _rebuildSuggestions();
  }

  static final AiStudyController instance = AiStudyController._();

  List<ScheduleBlock> _scheduleBlocks = [];
  final Map<String, int> _courseRatings = {};
  String? _studyGoal;
  String? _preferredTime;
  String? _preferredDays;
  List<AiSuggestion> _suggestions = const [];
  ReservePrefill? _pendingPrefill;

  List<AiSuggestion> get suggestions => _suggestions;

  void updateSchedule(List<ScheduleBlock> blocks) {
    _scheduleBlocks = blocks
        .where((b) => b.type != ScheduleBlockType.exam || !_isPastExam(b))
        .toList(growable: false);
    _rebuildSuggestions();
  }

  void updateCourseRating(String courseCode, int rating) {
    _courseRatings[courseCode.toUpperCase()] = rating;
    _rebuildSuggestions();
  }

  void updateProfilePreferences({
    String? studyGoal,
    String? preferredTime,
    String? preferredDays,
  }) {
    _studyGoal = studyGoal;
    _preferredTime = preferredTime;
    _preferredDays = preferredDays;
    _rebuildSuggestions();
  }

  ReservePrefill acceptSuggestion(AiSuggestion s) {
    _suggestions = _suggestions.where((e) => e.id != s.id).toList(growable: false);
    final prefill = ReservePrefill(
      courseCode: s.courseCode,
      slotLabel: s.slotLabel,
      dateIso: s.dateIso,
    );
    _pendingPrefill = prefill;
    notifyListeners();
    return prefill;
  }

  void rejectSuggestion(String suggestionId) {
    _suggestions = _suggestions.where((e) => e.id != suggestionId).toList(growable: false);
    notifyListeners();
  }

  ReservePrefill? consumePendingPrefill() {
    final current = _pendingPrefill;
    _pendingPrefill = null;
    return current;
  }

  bool _isPastExam(ScheduleBlock b) {
    if (b.type != ScheduleBlockType.exam || b.examDate == null) return false;
    final today = DateTime.now();
    final nowDate = DateTime(today.year, today.month, today.day);
    final examDate = DateTime(b.examDate!.year, b.examDate!.month, b.examDate!.day);
    return examDate.isBefore(nowDate);
  }

  void _rebuildSuggestions() {
    final occupied = <String>{};
    for (final b in _scheduleBlocks) {
      occupied.add('${b.day}|${b.timeSlot}');
    }

    final preferredSlots = _preferredSlotCandidates();
    final dayCandidates = _preferredDayCandidates();
    final course = _pickCourseCode();
    final generated = <AiSuggestion>[];

    for (final day in dayCandidates) {
      for (final slot in preferredSlots) {
        if (occupied.contains('$day|$slot')) continue;
        final date = _nextDateForDay(day);
        final slotLabel = _toReservationSlotLabel(slot);
        if (slotLabel == null) continue;
        final dateIso = _toIso(date);
        final rating = _courseRatings[course];
        final reason = _studyGoal == null
            ? 'How about a focused $course session?'
            : 'This matches your $_studyGoal goal.';
        final ratingHint = rating == null ? '' : ' Community rating: $rating/5.';
        final friendlySlot = slotLabel.split(' (').first;
        generated.add(
          AiSuggestion(
            id: 'ai-$day-$slot-$course',
            title: 'AI suggestion',
            message: '$day $friendlySlot • Study $course for 2 hours. $reason$ratingHint',
            courseCode: course,
            slotLabel: slotLabel,
            dateIso: dateIso,
          ),
        );
        if (generated.length >= 2) break;
      }
      if (generated.length >= 2) break;
    }

    if (generated.isEmpty) {
      final fallbackDate = _nextDateForDay('Tue');
      generated.add(
        AiSuggestion(
          id: 'ai-fallback',
          title: 'AI suggestion',
          message: 'Tue 14-15 • Study $course for 2 hours to keep progress steady.',
          courseCode: course,
          slotLabel: '13:00 - 15:00 (Class Time)',
          dateIso: _toIso(fallbackDate),
        ),
      );
    }

    _suggestions = generated;
    Future.microtask(() {
      notifyListeners();
    });
  }

  List<String> _preferredSlotCandidates() {
    switch ((_preferredTime ?? '').toLowerCase()) {
      case 'morning':
        return const ['09-10', '10-11', '11-12'];
      case 'afternoon':
        return const ['13-14', '14-15', '15-16'];
      case 'evening':
        return const ['17-18', '18-19', '19-20'];
      default:
        return const ['14-15', '13-14', '11-12'];
    }
  }

  List<String> _preferredDayCandidates() {
    final pref = (_preferredDays ?? '').toLowerCase();
    if (pref == 'weekend') return const ['Fri', 'Thu', 'Wed'];
    return const ['Tue', 'Wed', 'Thu', 'Fri', 'Mon'];
  }

  String _pickCourseCode() {
    final enrolled = AuthSession.instance.enrolledCourseCodes;

    if (enrolled.isNotEmpty) {
      if (_courseRatings.isNotEmpty) {
        final enrolledRatings = _courseRatings.entries.where((e) => enrolled.contains(e.key)).toList();
        if (enrolledRatings.isNotEmpty) {
          enrolledRatings.sort((a, b) => a.value.compareTo(b.value));
          return enrolledRatings.first.key;
        }
      }
      return enrolled.first;
    }

    if (_courseRatings.isNotEmpty) {
      final sorted = _courseRatings.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
      return sorted.first.key;
    }
    
    for (final b in _scheduleBlocks) {
      final c = _extractCourseCode(b.label);
      if (c != null) return c;
    }
    return RegistrationMockData.courses.first.code;
  }

  String? _extractCourseCode(String? label) {
    if (label == null || label.isEmpty) return null;
    final r = RegExp(r'([A-Z]{2,4})-?(\d{3})').firstMatch(label.toUpperCase());
    if (r == null) return null;
    return '${r.group(1)}${r.group(2)}';
  }

  String? _toReservationSlotLabel(String scheduleSlot) {
    final map = <String, String>{
      '09-10': '09:00 - 11:00 (Class Time)',
      '10-11': '09:00 - 11:00 (Class Time)',
      '11-12': '11:00 - 13:00 (Class Time)',
      '12-13': '11:00 - 13:00 (Class Time)',
      '13-14': '13:00 - 15:00 (Class Time)',
      '14-15': '13:00 - 15:00 (Class Time)',
      '15-16': '15:00 - 17:00 (Class Time)',
      '16-17': '15:00 - 17:00 (Class Time)',
      '17-18': '17:00 - 20:00 (Evening 1)',
      '18-19': '17:00 - 20:00 (Evening 1)',
      '19-20': '20:00 - 23:00 (Evening 2)',
    };
    final label = map[scheduleSlot];
    if (label == null) return null;
    for (final s in ReservationMockData.timeSlots) {
      if (s.label == label) return label;
    }
    return ReservationMockData.timeSlots.first.label;
  }

  DateTime _nextDateForDay(String shortDay) {
    final target = switch (shortDay) {
      'Mon' => DateTime.monday,
      'Tue' => DateTime.tuesday,
      'Wed' => DateTime.wednesday,
      'Thu' => DateTime.thursday,
      'Fri' => DateTime.friday,
      'Sat' => DateTime.saturday,
      'Sun' => DateTime.sunday,
      _ => DateTime.tuesday,
    };
    final now = DateTime.now();
    var delta = target - now.weekday;
    if (delta <= 0) delta += 7;
    return DateTime(now.year, now.month, now.day).add(Duration(days: delta));
  }

  String _toIso(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
