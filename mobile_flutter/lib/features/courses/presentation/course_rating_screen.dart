import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/planner/ai_study_controller.dart';
import '../data/course_api.dart';

/// Figma / React `CourseRating.tsx` — arama, zorluk yıldızı, konu etiketleri, oylama.
/// Liste [GET /courses], gönderim [POST /courses/{code}/rating].
class CourseRatingScreen extends StatefulWidget {
  const CourseRatingScreen({super.key});

  @override
  State<CourseRatingScreen> createState() => _CourseRatingScreenState();
}

class _MockCourse {
  const _MockCourse({
    required this.id,
    required this.code,
    required this.name,
    required this.department,
    required this.difficultyRating,
    required this.ratingCount,
    required this.topics,
  });

  final String id;
  final String code;
  final String name;
  final String department;
  final double difficultyRating;
  final int ratingCount;
  final List<String> topics;
}

class _CourseRatingScreenState extends State<CourseRatingScreen> {
  final _search = TextEditingController();
  final _courseApi = CourseApi();
  String? _ratingCourseId;
  int _userRating = 0;
  final _comment = TextEditingController();

  List<_MockCourse> _courses = [];
  bool _loadingList = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _loadingList = true;
    });
    try {
      final raw = await _courseApi.getCourses();
      final mapped = raw.map((e) => _parseCourseFromApi(Map<String, dynamic>.from(e))).whereType<_MockCourse>().toList();
      if (!mounted) return;
      setState(() {
        _courses = mapped;
        _loadingList = false;
      });
    } on DioException {
      if (!mounted) return;
      setState(() {
        _courses = [];
        _loadingList = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _courses = [];
        _loadingList = false;
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _comment.dispose();
    super.dispose();
  }

  List<_MockCourse> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _courses;
    return _courses
        .where((c) => c.name.toLowerCase().contains(q) || c.code.toLowerCase().contains(q))
        .toList();
  }

  static ({String label, Color fg, Color bg}) _difficultyLabel(double r) {
    if (r >= 4.5) return (label: 'Very Hard', fg: const Color(0xFFDC2626), bg: const Color(0xFFFEE2E2));
    if (r >= 4.0) return (label: 'Hard', fg: const Color(0xFFEA580C), bg: const Color(0xFFFFEDD5));
    if (r >= 3.5) return (label: 'Moderate', fg: const Color(0xFFD97706), bg: const Color(0xFFFEF9C3));
    if (r >= 3.0) return (label: 'Easy', fg: const Color(0xFF16A34A), bg: const Color(0xFFD1FAE5));
    return (label: 'Very Easy', fg: const Color(0xFF2563EB), bg: const Color(0xFFDBEAFE));
  }

  Widget _stars(double rating, {bool interactive = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = interactive ? star <= _userRating : star <= rating.round();
        return GestureDetector(
          onTap: interactive ? () => setState(() => _userRating = star) : null,
          child: Icon(
            Icons.star_rounded,
            size: 22,
            color: filled ? const Color(0xFFFACC15) : const Color(0xFFD1D5DB),
          ),
        );
      }),
    );
  }

  Future<void> _submit(_MockCourse c) async {
    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a rating')));
      return;
    }
    try {
      await _courseApi.rateCourse(courseCode: c.code, rating: _userRating);
      AiStudyController.instance.updateCourseRating(c.code, _userRating);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rated $_userRating/5 for ${c.code}')));
      setState(() {
        _ratingCourseId = null;
        _userRating = 0;
        _comment.clear();
      });
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit rating — check backend')));
    }
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
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rate Courses', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const Text('Help others choose wisely', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reload',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _loadingList ? null : _loadCourses,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search courses...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_loadingList)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  ..._filtered.map((course) {
                  final (:label, :fg, :bg) = _difficultyLabel(course.difficultyRating);
                  final isRating = _ratingCourseId == course.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFF3F4F6))),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('${course.code} • ${course.department}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _stars(course.difficultyRating),
                              const SizedBox(width: 8),
                              Text(course.difficultyRating.toStringAsFixed(1),
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(width: 4),
                              Text('(${course.ratingCount})', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                            child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.menu_book_rounded, size: 14, color: Color(0xFF9CA3AF)),
                              const SizedBox(width: 4),
                              const Text('Topics', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: course.topics
                                .map((t) => Chip(
                                      label: Text(t, style: const TextStyle(fontSize: 10)),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.trending_up_rounded, size: 18, color: Color(0xFF2563EB)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'AI: Study ${(course.difficultyRating * 2).ceil()}h/week',
                                    style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF1E40AF)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!isRating)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEAB308),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => setState(() {
                                  _ratingCourseId = course.id;
                                  _userRating = 0;
                                  _comment.clear();
                                }),
                                child: const Text('Rate This Course', style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            )
                          else ...[
                            const Text('Your rating', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            _stars(0, interactive: true),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _comment,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Optional comment',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _ratingCourseId = null),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _submit(course),
                                    child: const Text('Submit'),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
}

List<String> _topicsForCourseCode(String code) {
  const hints = {
    'CSE344': ['Requirements Analysis', 'UML Diagrams', 'Software Design'],
    'CSE331': ['SQL', 'Normalization', 'Transactions'],
    'CSE312': ['Process Management', 'Memory Management', 'Concurrency'],
    'MATH301': ['Matrices', 'Vector Spaces', 'Eigenvalues'],
  };
  return hints[code] ?? ['General'];
}

_MockCourse? _parseCourseFromApi(Map<String, dynamic> m) {
  final code = m['code']?.toString() ?? '';
  if (code.isEmpty) return null;
  final dr = m['difficultyRating'];
  final rating = dr is num ? dr.toDouble() : double.tryParse('$dr') ?? 0;
  final rc = m['ratingCount'];
  final count = rc is int ? rc : int.tryParse('$rc') ?? 0;
  final name = m['name']?.toString() ?? code;
  final id = code.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return _MockCourse(
    id: id,
    code: code,
    name: name,
    department: 'Course catalog',
    difficultyRating: rating,
    ratingCount: count,
    topics: _topicsForCourseCode(code),
  );
}
