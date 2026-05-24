import 'dart:async' show unawaited;
import 'dart:math' show Random;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/auth_scope.dart';
import '../../../core/platform/keyboard_host.dart';
import '../data/auth_api.dart';
import '../data/reference_api.dart';
import '../data/registration_mock_data.dart';

/// Figma / React `Register.tsx` — 5-step wizard (basic info → verify → dept → year → courses).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 1;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _verificationCode = TextEditingController();
  final _verifyFocus = FocusNode();
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  String? _emailError;
  String _sentCode = '';
  bool _loading = false;

  String _selectedDepartmentId = '';
  int? _selectedYear;
  final Set<String> _selectedCourseCodes = {};
  bool _coursesMenuOpen = false;
  bool _kvkkAccepted = false;
  List<RegistrationDepartment> _departments = List.of(RegistrationMockData.departments);

  static final _yeditepeEmail = RegExp(r'^[a-zA-Z0-9._%+-]+@std\.yeditepe\.edu\.tr$');

  String _normalizeEmail(String raw) {
    var s = raw.trim();
    while (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  String _buildNickname(String firstName, String lastName) {
    final first = firstName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final last = lastName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final number = (1000 + Random().nextInt(9000)).toString();
    if (first.isEmpty) return 'student_$number';
    if (last.isEmpty) return '${first}_$number';
    return '${first}_${last}_$number';
  }

  Future<void> _showKeyboardAfterFocus(FocusNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted || !node.hasFocus) return;
    await KeyboardHost.showSoftIfAndroid();
  }

  void _onVerifyFocusChange() {
    if (!_verifyFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verifyFocus.hasFocus) return;
      unawaited(_showKeyboardAfterFocus(_verifyFocus));
    });
  }

  void _onTextFieldFocusShowKb(FocusNode node) {
    node.addListener(() {
      if (!node.hasFocus) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !node.hasFocus) return;
        unawaited(_showKeyboardAfterFocus(node));
      });
    });
  }

  Future<void> _pickDepartment() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text('Select Department', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              ..._departments.map((d) {
                return ListTile(
                  title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: _selectedDepartmentId == d.id ? const Icon(Icons.check_circle, color: Color(0xFFDB2777)) : null,
                  onTap: () {
                    setState(() => _selectedDepartmentId = d.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _requestVerifyFieldAndKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _step != 2) return;
      FocusScope.of(context).requestFocus(_verifyFocus);
      unawaited(_showKeyboardAfterFocus(_verifyFocus));
    });
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 24)),
    );
  }

  Future<void> _sendCode() async {
    final email = _normalizeEmail(_email.text);
    setState(() => _emailError = null);
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      _toast('Please enter first name and last name.');
      return;
    }
    if (!_yeditepeEmail.hasMatch(email)) {
      setState(() => _emailError = 'Use a Yeditepe email: @std.yeditepe.edu.tr');
      _toast('A valid university email is required.');
      return;
    }
    if (_password.text.length < 6) {
      _toast('Password must be at least 6 characters.');
      return;
    }
    
    setState(() => _loading = true);
    try {
      final nickname = _buildNickname(_firstName.text, _lastName.text);
      await AuthApi().registerInit(
        email: email,
        password: _password.text,
        name: '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
        nickname: nickname,
      );
      if (!mounted) return;
      _toast('Verification code sent to $email.');
      setState(() => _step = 2);
      _requestVerifyFieldAndKeyboard();
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 409) {
        setState(() => _emailError = 'This email is already registered.');
        _toast('Email already registered.');
      } else {
        _toast('Could not send code. ${e.response?.data?['message'] ?? ''}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final v = _verificationCode.text.trim();
    if (v.length != 6) {
      _toast('Enter a 6-digit code.');
      return;
    }
    
    setState(() => _loading = true);
    try {
      await AuthApi().verifyOtp(
        email: _normalizeEmail(_email.text),
        otpCode: v,
      );
      if (!mounted) return;
      _toast('Email verified.');
      setState(() => _step = 3);
    } on DioException catch (e) {
      if (!mounted) return;
      _toast('Verification failed: ${e.response?.data?['message'] ?? 'Invalid code'}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showKvkkNotice() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('KVKK / Privacy Notice'),
        content: const SingleChildScrollView(
          child: Text(
            'StudySync processes your university email, profile, reservations, and course '
            'preferences to provide campus services. Data is stored for your account while you '
            'use the app. Contact your institution for full KVKK text and data officer details.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _finishRegistration() async {
    if (!_kvkkAccepted) {
      _toast('Please accept the KVKK privacy notice to complete registration.');
      return;
    }
    if (_selectedCourseCodes.isEmpty) {
      _toast('Select at least one course.');
      return;
    }
    if (_selectedDepartmentId.isEmpty || _selectedYear == null) {
      _toast('Department and year are required.');
      return;
    }
    final email = _normalizeEmail(_email.text);
    final password = _password.text;
    final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
    final nickname = _buildNickname(_firstName.text, _lastName.text);
    setState(() => _loading = true);
    try {
      final r = await AuthApi().registerComplete(// API call to register
        email: email,
        password: password,
        name: fullName,
        nickname: nickname,
        departmentId: _selectedDepartmentId,
        year: _selectedYear!,
        selectedCourseCodes: _selectedCourseCodes.toList(growable: false),
        kvkkAccepted: _kvkkAccepted,
      );
      if (!mounted) return;
      AuthScope.of(context).establishSession(
        accessToken: r.accessToken,
        refreshToken: r.refreshToken,
        user: r.user,
      );
      _toast('Registration successful. Welcome, ${_firstName.text.trim()}!');
      Navigator.of(context).popUntil((route) => route.isFirst); // popUntil is used to pop the routes until the first route.
    } on DioException catch (e) {
      if (!mounted) return; //mounted is used to check if the widget is still in the tree.
      final status = e.response?.statusCode;
      if (status == 409) {
        setState(() {
          _step = 1;
          _emailError = 'This email is already registered. Sign in or use another address.';
        });
        try {
          final loginResult = await AuthApi().login(email: email, password: password);
          if (!mounted) return;
          AuthScope.of(context).establishSession(
            accessToken: loginResult.accessToken,
            refreshToken: loginResult.refreshToken,
            user: loginResult.user,
          );
          _toast('Welcome back! Signed in automatically.');
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        } on DioException {
          if (!mounted) return;
          _toast('Email already registered. Use Login with the same password.');
        }
      } else if (status == 400) {
        _toast('Invalid registration data. Please review your inputs.');
      } else if (status == null) {
        _toast('Cannot reach backend. Check server and emulator API base URL.');
      } else {
        _toast('Registration failed (HTTP $status). Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadDepartments());
    _verificationCode.addListener(() => setState(() {}));
    _verifyFocus.addListener(_onVerifyFocusChange);
    _onTextFieldFocusShowKb(_firstNameFocus);
    _onTextFieldFocusShowKb(_lastNameFocus);
    _onTextFieldFocusShowKb(_emailFocus);
    _onTextFieldFocusShowKb(_passwordFocus);
  }

  Future<void> _loadDepartments() async {
    try {
      final remote = await ReferenceApi().getDepartments();// API call to get the departments
      if (!mounted || remote.isEmpty) return;
      setState(() => _departments = remote);
    } catch (_) {
      // Keep local fallback list when backend reference catalog is unavailable.
    }
  }

  InputDecoration _fieldDec({String? hint, Widget? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
    );
  }

  @override
  void dispose() {
    _verifyFocus.removeListener(_onVerifyFocusChange);
    _verifyFocus.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _verificationCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2563EB), Color(0xFF9333EA), Color(0xFFEC4899)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_step == 1) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() => _step -= 1);
                          if (_step == 2) _requestVerifyFieldAndKeyboard();
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    const Text('Create Account 🎓', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Join StudySync community', style: TextStyle(color: Colors.blue.shade100, fontSize: 11)),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(5, (i) {
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                            decoration: BoxDecoration(
                              color: _step > i ? Colors.white : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildStep(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _step1();
      case 2:
        return _step2();
      case 3:
        return _step3();
      case 4:
        return _step4();
      default:
        return _step5();
    }
  }

  Widget _stepHeader(IconData icon, Color bg, Color fg, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
          child: Icon(icon, color: fg, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _step1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(Icons.person_outline_rounded, const Color(0xFFDBEAFE), const Color(0xFF2563EB), 'Basic Information', 'Tell us about yourself'),
        const SizedBox(height: 14),
        Text('First Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
        const SizedBox(height: 6),
        TextField(
          focusNode: _firstNameFocus,
          controller: _firstName,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_lastNameFocus),
          decoration: _fieldDec(hint: 'Ahmet'),
        ),
        const SizedBox(height: 10),
        Text('Last Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
        const SizedBox(height: 6),
        TextField(
          focusNode: _lastNameFocus,
          controller: _lastName,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
          decoration: _fieldDec(hint: 'Yılmaz'),
        ),
        const SizedBox(height: 10),
        Text('University Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
        const SizedBox(height: 6),
        TextField(
          focusNode: _emailFocus,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
          decoration: _fieldDec(hint: 'name@std.yeditepe.edu.tr', prefix: Icon(Icons.mail_outline_rounded, color: Colors.grey.shade400)),
        ),
        if (_emailError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_emailError!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11))),
        const SizedBox(height: 10),
        Text('Password', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
        const SizedBox(height: 6),
        TextField(
          focusNode: _passwordFocus,
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: _fieldDec(hint: '••••••••', prefix: Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400)),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Already registered? Sign in',
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        FilledButton(
          onPressed: _loading ? null : _sendCode,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _loading 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
            : const Text('Send Verification Code', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _step2() {
    final email = _normalizeEmail(_email.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(Icons.mark_email_unread_outlined, const Color(0xFFE9D5FF), const Color(0xFF9333EA), 'Email Verification', 'Enter the code sent to your email'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBFDBFE))),
          child: Text(
            'We sent a 6-digit code to $email',
            style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.35),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          focusNode: _verifyFocus,
          controller: _verificationCode,
          keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (_verificationCode.text.trim().length == 6) _verifyCode();
          },
          onTap: () => unawaited(KeyboardHost.showSoftIfAndroid()),
          decoration: _fieldDec(hint: '______').copyWith(
            counterText: '',
            hintStyle: TextStyle(fontSize: 18, letterSpacing: 4, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: _loading ? null : _sendCode,
          child: const Text('Resend code', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _verificationCode.text.trim().length == 6 && !_loading ? _verifyCode : null,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9333EA), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _loading 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Verify Email', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _step3() {
    String? deptName;
    for (final d in _departments) {
      if (d.id == _selectedDepartmentId) deptName = d.name;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(Icons.school_outlined, const Color(0xFFFCE7F3), const Color(0xFFDB2777), 'Select Department', 'Which program are you in?'),
        const SizedBox(height: 14),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              unawaited(_pickDepartment());
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      deptName ?? 'Select Department',
                      style: TextStyle(fontWeight: FontWeight.w600, color: deptName == null ? Colors.grey : Colors.grey.shade900),
                    ),
                  ),
                  Icon(Icons.expand_more, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _selectedDepartmentId.isEmpty ? null : () => setState(() => _step = 4),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDB2777), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _step4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(Icons.calendar_today_outlined, const Color(0xFFD1FAE5), const Color(0xFF059669), 'Select Your Year', 'Which year are you in?'),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.4,
          children: RegistrationMockData.yearLevels.map((y) {
            final sel = _selectedYear == y.id;
            return Material(
              color: sel ? const Color(0xFFECFDF5) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => setState(() => _selectedYear = y.id),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sel ? const Color(0xFF059669) : const Color(0xFFE5E7EB), width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${y.id}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: sel ? const Color(0xFF059669) : Colors.grey.shade900)),
                      Text(y.name, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _selectedYear == null ? null : () => setState(() => _step = 5),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _step5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(Icons.check_circle_outline, const Color(0xFFFFEDD5), const Color(0xFFEA580C), 'Select Courses', 'Choose your courses this semester'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
          child: Text('${_selectedCourseCodes.length} course(s) selected', style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => setState(() => _coursesMenuOpen = !_coursesMenuOpen),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB), width: 2)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Courses', style: TextStyle(fontWeight: FontWeight.w600)),
                  Icon(_coursesMenuOpen ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        if (_coursesMenuOpen)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListView(
              shrinkWrap: true,
              children: RegistrationMockData.courses.map((c) {
                final on = _selectedCourseCodes.contains(c.code);
                return ListTile(
                  dense: true,
                  title: Text(c.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  subtitle: Text(c.name, style: const TextStyle(fontSize: 10)),
                  trailing: on ? const Icon(Icons.check_circle, color: Color(0xFFEA580C), size: 20) : null,
                  onTap: () => setState(() {
                    if (on) {
                      _selectedCourseCodes.remove(c.code);
                    } else {
                      _selectedCourseCodes.add(c.code);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
        if (_selectedCourseCodes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedCourseCodes.map((code) {
              return Chip(label: Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), backgroundColor: const Color(0xFFFFEDD5));
            }).toList(),
          ),
        ],
        const SizedBox(height: 14),
        Material(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          child: CheckboxListTile(
            value: _kvkkAccepted,
            onChanged: _loading ? null : (v) => setState(() => _kvkkAccepted = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('I accept the ', style: TextStyle(fontSize: 12)),
                GestureDetector(
                  onTap: _showKvkkNotice,
                  child: const Text(
                    'KVKK / Privacy Notice',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF9333EA), Color(0xFFEC4899)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: FilledButton(
            onPressed: _loading || _selectedCourseCodes.isEmpty || !_kvkkAccepted ? null : _finishRegistration,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : const Text('Complete Registration', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
