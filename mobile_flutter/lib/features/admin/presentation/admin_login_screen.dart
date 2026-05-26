import 'package:flutter/material.dart';

import '../../../core/admin/admin_allowlist.dart';
import '../../../core/admin/admin_email_utils.dart';
import '../../../core/auth/auth_scope.dart';
import '../../auth/data/auth_api.dart';
import '../data/admin_api.dart';
import '../data/admin_data_controller.dart';
import 'widgets/admin_ui.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = AdminEmailUtils.normalize(_emailCtrl.text);
    final password = _passwordCtrl.text.trim();

    setState(() => _error = null);

    if (!AdminEmailUtils.isValidStaffEmail(email)) {
      setState(() => _error = 'Use staff email: name@yeditepe.edu.tr (not @std.yeditepe.edu.tr).');
      return;
    }
    if (!AdminAllowlist.isListed(email)) {
      setState(() => _error = 'This email is not on the admin allowlist.');
      return;
    }
    if (!AdminAllowlist.verifyPassword(email, password)) {
      setState(() {
        _error = 'Invalid password.';
      });
      return;
    }

    setState(() => _loading = true);

    String? accessToken;
    String? refreshToken;
    try {
      final r = await AuthApi().login(email: email, password: password);
      accessToken = r.accessToken;
      refreshToken = r.refreshToken;
    } catch (_) {
      try {
        final bridge = await AuthApi().login(
          email: AdminApi.bridgeStudentEmail,
          password: AdminApi.bridgeStudentPassword,
        );
        accessToken = bridge.accessToken;
        refreshToken = bridge.refreshToken;
      } catch (_) {}
    }

    if (!mounted) return;
    AuthScope.of(context).establishAdminSession(
      email: email,
      displayName: AdminAllowlist.displayNameFor(email),
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await AdminDataController.instance.refresh();
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AdminUi.brandGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, size: 44, color: Color(0xFF1E40AF)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'StudySync Admin',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Campus operations & student safety console',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
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
                      const Text(
                        'Staff sign in',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Only @yeditepe.edu.tr emails on the allowlist can access this console.',
                        style: TextStyle(fontSize: 12, height: 1.35, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Staff email',
                          hintText: 'name@yeditepe.edu.tr',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: AdminUi.inputBorder(),
                          enabledBorder: AdminUi.inputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: AdminUi.inputBorder(),
                          enabledBorder: AdminUi.inputBorder(),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AdminUi.accentGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _loading ? null : _submit,
                              child: SizedBox.expand(
                                child: Center(
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text(
                                          'Enter admin console',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
