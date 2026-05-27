import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../auth_email_utils.dart';
import '../data/auth_api.dart';

/// Full-screen forgot password — matches Login gradient + card style.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFFA855F7), Color(0xFFEC4899)],
  );

  late final TextEditingController _emailCtrl;
  late final TextEditingController _otpCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _confirmPasswordCtrl;

  bool _loading = false;
  String? _inlineMessage;
  bool _isError = false;
  bool _otpSent = false;
  bool _completed = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _otpCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (_loading || _otpSent) return;

    final email = AuthEmailUtils.normalize(_emailCtrl.text);
    if (!AuthEmailUtils.isValidYeditepeEmail(email)) {
      setState(() {
        _inlineMessage = 'Use your full @std.yeditepe.edu.tr address.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _inlineMessage = null;
      _isError = false;
    });

    try {
      final result = await AuthApi().requestPasswordReset(email: email);
      if (!mounted) return;

      final isSuccess = result.status == PasswordResetStatus.submitted;
      setState(() {
        _loading = false;
        if (isSuccess) {
          _otpSent = true;
          _inlineMessage = 'Verification code has been sent to your email.';
          _isError = false;
        } else {
          _inlineMessage = result.message;
          _isError = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _inlineMessage = 'An unexpected error occurred. Please try again.';
        _isError = true;
      });
    }
  }

  Future<void> _submitReset() async {
    if (_loading || _completed) return;

    final email = AuthEmailUtils.normalize(_emailCtrl.text);
    final otp = _otpCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (otp.length != 6) {
      setState(() {
        _inlineMessage = 'Verification code must be 6 digits.';
        _isError = true;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _inlineMessage = 'Password must be at least 6 characters.';
        _isError = true;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _inlineMessage = 'Passwords do not match.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _inlineMessage = null;
      _isError = false;
    });

    try {
      await AuthApi().resetPasswordOtp(
        email: email,
        otpCode: otp,
        newPassword: password,
      );
      if (!mounted) return;

      setState(() {
        _loading = false;
        _completed = true;
        _inlineMessage = 'Your password has been successfully reset.';
        _isError = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      String errMsg = 'Failed to reset password. Check the code and try again.';
      if (data is Map<String, dynamic> && data['message'] != null) {
        errMsg = data['message'].toString();
      }
      setState(() {
        _loading = false;
        _inlineMessage = errMsg;
        _isError = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _inlineMessage = 'An unexpected error occurred. Please try again.';
        _isError = true;
      });
    }
  }

  OutlineInputBorder _inputBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = _inputBorder();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: _gradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _loading
                        ? null
                        : () {
                            if (_otpSent && !_completed) {
                              setState(() {
                                _otpSent = false;
                                _inlineMessage = null;
                                _isError = false;
                                _otpCtrl.clear();
                                _passwordCtrl.clear();
                                _confirmPasswordCtrl.clear();
                              });
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock_reset_rounded, size: 44, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reset password',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  _otpSent
                      ? 'Enter verification code and new password'
                      : 'We will email a verification code to your university inbox',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.35, color: Colors.white.withValues(alpha: 0.92)),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _completed
                            ? 'Password reset successful!'
                            : _otpSent
                                ? 'Verify OTP & Reset'
                                : 'Forgot your password?',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _completed
                            ? 'Your password has been changed. You can now log in with your new password.'
                            : _otpSent
                                ? 'Enter the 6-digit code sent to your email and choose your new password.'
                                : 'Enter your university email address. We will send you a 6-digit verification code.',
                        style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade600),
                      ),
                      if (_completed) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD1FAE5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, size: 40, color: Color(0xFF10B981)),
                          ),
                        ),
                      ] else if (_otpSent) ...[
                        const SizedBox(height: 20),
                        Text(
                          'University Email',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailCtrl,
                          enabled: false,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.mail_outline_rounded, color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: inputBorder,
                            disabledBorder: inputBorder.copyWith(
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Verification Code',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _otpCtrl,
                          enabled: !_loading,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: '123456',
                            counterText: '',
                            prefixIcon: Icon(Icons.pin_outlined, color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.white,
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: inputBorder.copyWith(
                              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'New Password',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordCtrl,
                          enabled: !_loading,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey.shade400,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: inputBorder.copyWith(
                              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Confirm Password',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _confirmPasswordCtrl,
                          enabled: !_loading,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submitReset(),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey.shade400,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: inputBorder.copyWith(
                              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 20),
                        Text(
                          'University Email',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailCtrl,
                          enabled: !_loading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submitEmail(),
                          decoration: InputDecoration(
                            hintText: 'name@std.yeditepe.edu.tr',
                            prefixIcon: Icon(Icons.mail_outline_rounded, color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.white,
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: inputBorder.copyWith(
                              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          ),
                        ),
                      ],
                      if (_inlineMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isError ? const Color(0xFFFECACA) : const Color(0xFF86EFAC),
                            ),
                          ),
                          child: Text(
                            _inlineMessage!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              color: _isError ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF9333EA)]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _loading
                                  ? null
                                  : _completed
                                      ? () => Navigator.of(context).pop()
                                      : _otpSent
                                          ? _submitReset
                                          : _submitEmail,
                              child: Center(
                                child: _loading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                      )
                                    : Text(
                                        _completed
                                            ? 'Back to login'
                                            : _otpSent
                                                ? 'Reset Password'
                                                : 'Send Verification Code',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_otpSent && !_completed) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  setState(() {
                                    _otpSent = false;
                                    _inlineMessage = null;
                                    _isError = false;
                                    _otpCtrl.clear();
                                    _passwordCtrl.clear();
                                    _confirmPasswordCtrl.clear();
                                  });
                                },
                          child: Text(
                            'Change email address',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
