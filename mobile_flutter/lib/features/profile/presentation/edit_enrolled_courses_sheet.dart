import 'package:flutter/material.dart';

import '../../../core/session/auth_session.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/registration_mock_data.dart';
import '../../courses/data/course_api.dart';

/// Lets the user update enrolled courses for the current session.
/// Persists to [AuthSession] only until a backend profile API exists.
Future<void> showEditEnrolledCoursesSheet({
  required BuildContext context,
  required VoidCallback onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _EditEnrolledCoursesSheet(
      onSaved: () {
        Navigator.of(sheetContext).pop();
        onSaved();
      },
    ),
  );
}

class _CourseOption {
  const _CourseOption({required this.code, required this.name});
  final String code;
  final String name;
}

class _EditEnrolledCoursesSheet extends StatefulWidget {
  const _EditEnrolledCoursesSheet({required this.onSaved});

  final VoidCallback onSaved;

  @override
  State<_EditEnrolledCoursesSheet> createState() => _EditEnrolledCoursesSheetState();
}

class _EditEnrolledCoursesSheetState extends State<_EditEnrolledCoursesSheet> {
  final Set<String> _selected = {};
  List<_CourseOption> _courses = [];
  bool _loadingCourses = true;
  bool _saving = false;
  String? _inlineMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(AuthSession.instance.enrolledCourseCodes);
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final remote = await CourseApi().getCourses();
      if (!mounted) return;
      final parsed = remote
          .map((m) {
            final code = m['code']?.toString() ?? '';
            final name = m['name']?.toString() ?? code;
            if (code.isEmpty) return null;
            return _CourseOption(code: code, name: name);
          })
          .whereType<_CourseOption>()
          .toList();
      setState(() {
        _courses = parsed.isNotEmpty
            ? parsed
            : RegistrationMockData.courses
                .map((c) => _CourseOption(code: c.code, name: c.name))
                .toList();
        _loadingCourses = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _courses = RegistrationMockData.courses
            .map((c) => _CourseOption(code: c.code, name: c.name))
            .toList();
        _loadingCourses = false;
      });
    }
  }

  Future<void> _save() async {
    if (_selected.isEmpty) {
      setState(() {
        _inlineMessage = 'Select at least one course.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _saving = true;
      _inlineMessage = null;
      _isError = false;
    });

    try {
      await AuthApi().updateMyCourses(_selected.toList());
      if (!mounted) return;
      AuthSession.instance.enrolledCourseCodes = _selected.toList()..sort();
      widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _inlineMessage = 'Could not save to server. Please try again.';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Edit my courses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const Text(
            'Changes are saved to your profile and applied in this session.',
            style: TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          if (_loadingCourses)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final c = _courses[index];
                  final on = _selected.contains(c.code);
                  return CheckboxListTile(
                    value: on,
                    onChanged: _saving
                        ? null
                        : (checked) {
                            setState(() {
                              if (checked == true) {
                                _selected.add(c.code);
                              } else {
                                _selected.remove(c.code);
                              }
                              _inlineMessage = null;
                            });
                          },
                    title: Text(c.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    subtitle: Text(c.name, style: const TextStyle(fontSize: 11)),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  );
                },
              ),
            ),
          if (_inlineMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _inlineMessage!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isError ? const Color(0xFFDC2626) : const Color(0xFF15803D),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving || _loadingCourses ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Save (${_selected.length} selected)'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
