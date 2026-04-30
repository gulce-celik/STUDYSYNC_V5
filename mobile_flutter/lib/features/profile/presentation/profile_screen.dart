import 'package:flutter/material.dart';

import '../../../core/auth/auth_scope.dart';
import '../../../core/planner/ai_study_controller.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/trust/responsibility_ledger.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../auth/data/registration_mock_data.dart';
import '../../schedule/presentation/weekly_schedule_screen.dart';
import '../data/profile_mock_data.dart';

/// Figma / React `Profile.tsx` — gradient header, courses, nickname, buddy prefs, score history, links.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _studyGoal;
  String? _userLevel;
  String? _learningStyle;
  String? _preferredTime;
  String? _preferredDays;
  _DarkModePref _darkMode = _DarkModePref.off;

  @override
  void initState() {
    super.initState();
    final mode = ThemeModeController.instance.mode;
    _darkMode = switch (mode) {
      ThemeMode.system => _DarkModePref.auto,
      ThemeMode.dark => _DarkModePref.on,
      ThemeMode.light => _DarkModePref.off,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AuthScope.of(context).refreshProfile();
      }
    });
  }

  bool get _prefsComplete =>
      _studyGoal != null &&
      _userLevel != null &&
      _learningStyle != null &&
      _preferredTime != null &&
      _preferredDays != null;

  List<RegistrationCourse> _userCourses() {
    final out = <RegistrationCourse>[];
    final session = AuthSession.instance;
    for (final code in session.enrolledCourseCodes) {
      for (final c in RegistrationMockData.courses) {
        if (c.code == code) out.add(c);
      }
    }
    return out;
  }

  void _passwordSheet() {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Change password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password (6+ chars)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  if (current.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter current password')));
                    return;
                  }
                  if (next.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be 6+ chars')));
                    return;
                  }
                  if (next.text != confirm.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                    return;
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed!')));
                },
                child: const Text('Save'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _selectGrid({
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelect,
    int crossAxisCount = 2,
    double aspect = 2.6,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final totalSpacing = spacing * (crossAxisCount - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;
        final itemHeight = (itemWidth / aspect).clamp(36.0, 56.0);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: options.map((o) {
            final sel = selected == o;
            return SizedBox(
              width: itemWidth,
              height: itemHeight,
              child: Material(
                color: sel ? const Color(0xFFF3E8FF) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => setState(() {
                    onSelect(o);
                    _syncAiPreferences();
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? const Color(0xFF9333EA) : const Color(0xFFE9D5FF), width: 2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      o,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: crossAxisCount >= 3 ? 9 : 10,
                        fontWeight: FontWeight.w700,
                        color: sel ? const Color(0xFF6B21A8) : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _setDarkMode(_DarkModePref pref) {
    setState(() => _darkMode = pref);
    final mode = switch (pref) {
      _DarkModePref.auto => ThemeMode.system,
      _DarkModePref.on => ThemeMode.dark,
      _DarkModePref.off => ThemeMode.light,
    };
    ThemeModeController.instance.setMode(mode);
  }

  void _syncAiPreferences() {
    AiStudyController.instance.updateProfilePreferences(
      studyGoal: _studyGoal,
      preferredTime: _preferredTime,
      preferredDays: _preferredDays,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final mutedSurface = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final session = AuthSession.instance;
    final name = (session.userName?.trim().isNotEmpty ?? false) ? session.userName!.trim() : 'Student';
    final dept = (session.userDepartment?.trim().isNotEmpty ?? false) ? session.userDepartment!.trim() : 'Computer Engineering';
    final year = session.userYear ?? 3;
    final courses = _userCourses();
    final nickname = (session.userNickname?.trim().isNotEmpty ?? false) ? session.userNickname!.trim() : ProfileMockData.nickname;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF9333EA)],
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Manage your preferences', style: TextStyle(color: Colors.blue.shade100, fontSize: 10)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Transform.translate(
                  offset: const Offset(0, -12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF9333EA)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white.withValues(alpha: 0.35),
                              child: const Icon(Icons.person_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                  Text('$dept • Year $year', style: TextStyle(color: Colors.blue.shade100, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListenableBuilder(
                            listenable: ResponsibilityLedger.instance,
                            builder: (context, _) {
                              final score = ResponsibilityLedger.instance.effectiveScore;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Responsibility Score', style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 10)),
                                      const Icon(Icons.emoji_events_rounded, color: Color(0xFFFDE047), size: 18),
                                    ],
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('$score', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                                      const Text('%', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      value: score / 100,
                                      minHeight: 4,
                                      backgroundColor: Colors.white.withValues(alpha: 0.35),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('My Courses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(builder: (_) => const WeeklyScheduleScreen()),
                                ),
                            icon: const Icon(Icons.calendar_view_week_rounded, size: 14),
                            label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                          ),
                        ],
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final tileWidth = (constraints.maxWidth - 8) / 2;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: courses.take(4).map((c) {
                              return SizedBox(
                                width: tileWidth,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(c.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                                      Text(
                                        c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      if (courses.length > 4)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('+${courses.length - 4} more', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.indigo.shade50, Colors.purple.shade50]),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.indigo.shade200, width: 2),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.indigo.shade100, child: Icon(Icons.tag_rounded, color: Colors.indigo.shade700, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Nickname', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.indigo.shade600)),
                            Text(nickname, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.indigo.shade900)),
                            const SizedBox(height: 4),
                            Text('Used for group reservations', style: TextStyle(fontSize: 9, color: Colors.indigo.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.purple.shade50, Colors.pink.shade50]),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.purple.shade300, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(backgroundColor: Colors.purple.shade500, radius: 18, child: const Icon(Icons.groups_rounded, color: Colors.white, size: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Study Buddy Preferences', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF581C87))),
                                Text('Required for AI matching', style: TextStyle(fontSize: 9, color: Colors.purple.shade700)),
                              ],
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                          ),
                          if (_prefsComplete) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 22),
                          ],
                        ],
                      ),
                      if (!_prefsComplete)
                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFCD34D))),
                          child: const Text('⚠️ Complete your preferences to improve match accuracy', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                        ),
                      Text('Study Goal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.purple.shade900)),
                      const SizedBox(height: 4),
                      _selectGrid(
                        options: const ['Exam Prep', 'Homework Help', 'Practice', 'Project Work'],
                        selected: _studyGoal,
                        onSelect: (v) => _studyGoal = v,
                        crossAxisCount: 2,
                      ),
                      const SizedBox(height: 8),
                      Text('User Level', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.purple.shade900)),
                      const SizedBox(height: 6),
                      _selectGrid(
                        options: const ['Beginner', 'Intermediate', 'Advanced'],
                        selected: _userLevel,
                        onSelect: (v) => _userLevel = v,
                        crossAxisCount: 3,
                        aspect: 2.4,
                      ),
                      const SizedBox(height: 8),
                      Text('Study Style', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.purple.shade900)),
                      const SizedBox(height: 6),
                      _selectGrid(
                        options: const ['Explain to others', 'Practice together', 'Listen & Learn', 'Accountability'],
                        selected: _learningStyle,
                        onSelect: (v) => _learningStyle = v,
                        crossAxisCount: 2,
                        aspect: 2.9,
                      ),
                      const SizedBox(height: 8),
                      Text('Preferred Time', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.purple.shade900)),
                      const SizedBox(height: 6),
                      _selectGrid(
                        options: const ['Morning', 'Afternoon', 'Evening'],
                        selected: _preferredTime,
                        onSelect: (v) => _preferredTime = v,
                        crossAxisCount: 3,
                      ),
                      const SizedBox(height: 8),
                      Text('Preferred Days', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.purple.shade900)),
                      const SizedBox(height: 6),
                      _selectGrid(
                        options: const ['Weekdays', 'Weekend'],
                        selected: _preferredDays,
                        onSelect: (v) => _preferredDays = v,
                        crossAxisCount: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.emoji_events_rounded, size: 18, color: Colors.purple.shade600),
                          const SizedBox(width: 6),
                          const Text('Score History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView(
                          shrinkWrap: true,
                          children: ProfileMockData.scoreHistory.map((e) {
                            final pos = e.scoreChange >= 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: mutedSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(pos ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 18, color: pos ? const Color(0xFF22C55E) : const Color(0xFFDC2626)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(e.description, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                        Text(e.date, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${pos ? '+' : ''}${e.scoreChange}%',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: pos ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dark_mode_rounded, size: 18, color: Colors.indigo.shade600),
                          const SizedBox(width: 6),
                          const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _darkModeChip(
                              label: 'Auto',
                              icon: Icons.computer_rounded,
                              selected: _darkMode == _DarkModePref.auto,
                              isDark: isDark,
                              onTap: () => _setDarkMode(_DarkModePref.auto),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _darkModeChip(
                              label: 'On',
                              icon: Icons.dark_mode_rounded,
                              selected: _darkMode == _DarkModePref.on,
                              isDark: isDark,
                              onTap: () => _setDarkMode(_DarkModePref.on),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _darkModeChip(
                              label: 'Off',
                              icon: Icons.light_mode_rounded,
                              selected: _darkMode == _DarkModePref.off,
                              isDark: isDark,
                              onTap: () => _setDarkMode(_DarkModePref.off),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Auto adjusts based on system preference', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 18, color: Colors.red.shade600),
                          const SizedBox(width: 6),
                          const Text('Security', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: mutedSurface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _passwordSheet,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF4B5563)),
                                SizedBox(width: 8),
                                Expanded(child: Text('Change password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                                Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF9CA3AF)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(height: 8),
                      _accountRow('Email', session.userEmail ?? 'unknown@std.yeditepe.edu.tr', isDark: isDark),
                      const SizedBox(height: 6),
                      _accountRow('Major', dept, isDark: isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9333EA),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: const Color(0xFFDC2626),
                  leading: const Icon(Icons.logout_rounded, color: Colors.white),
                  title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  onTap: () => AuthScope.of(context).logout(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountRow(String label, String value, {required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static Widget _darkModeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEEF2FF))
          : (isDark ? const Color(0xFF111827) : Colors.white),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4F46E5)
                  : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: selected ? const Color(0xFF4F46E5) : const Color(0xFF6B7280)),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF4F46E5) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DarkModePref { auto, on, off }
