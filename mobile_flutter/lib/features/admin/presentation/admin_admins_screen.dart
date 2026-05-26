import 'package:flutter/material.dart';

import '../../../core/admin/admin_email_utils.dart';
import '../../../core/admin/admin_roster_store.dart';
import '../../../core/auth/auth_scope.dart';
import '../data/admin_data_controller.dart';
import '../../../core/session/auth_session.dart';
import 'widgets/admin_ui.dart';

/// Shared sign-out — relies on [StudySyncApp] home rebuild (no manual route push).
void adminSignOut(BuildContext context) {
  AdminDataController.instance.clear();
  AuthScope.of(context).logout();
}

class AdminAdminsScreen extends StatelessWidget {
  const AdminAdminsScreen({super.key});

  Future<void> _showAddAdminDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    var errorText = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            return AlertDialog(
              title: const Text('Add staff admin', style: TextStyle(fontWeight: FontWeight.w800)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Staff email on @yeditepe.edu.tr.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'name@yeditepe.edu.tr',
                      errorText: errorText.isEmpty ? null : errorText,
                      border: AdminUi.inputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                  onPressed: () {
                    final email = AdminEmailUtils.normalize(ctrl.text);
                    if (!AdminEmailUtils.isValidStaffEmail(email)) {
                      setDialog(() => errorText = 'Use staff @yeditepe.edu.tr (not @std.).');
                      return;
                    }
                    if (AdminRosterStore.instance.isListed(email)) {
                      setDialog(() => errorText = 'Already an admin.');
                      return;
                    }
                    AdminRosterStore.instance.addAdmin(email);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$email added as admin (this session).')),
                    );
                  },
                  child: const Text('Grant admin'),
                ),
              ],
            );
          },
        );
      },
    );
    ctrl.dispose();
  }

  Future<void> _confirmRemove(BuildContext context, String email) async {
    final me = AuthSession.instance.userEmail?.toLowerCase();
    final isSelf = me == email;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove admin access?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          isSelf
              ? 'You will lose admin access. Sign in again only if another admin re-adds you.'
              : '$email will no longer be able to open StudySync Admin.',
          style: const TextStyle(height: 1.35),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    if (!AdminRosterStore.instance.canRemove(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one admin must remain.')),
      );
      return;
    }

    AdminRosterStore.instance.removeAdmin(email);
    if (!context.mounted) return;

    if (isSelf) {
      adminSignOut(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$email removed from admin roster (this session).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthSession.instance.userEmail?.toLowerCase();

    return ListenableBuilder(
      listenable: AdminRosterStore.instance,
      builder: (context, _) {
        final emails = List<String>.from(AdminRosterStore.instance.emails)..sort();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const AdminSectionTitle('Staff administrators'),
            Text(
              'Who can open StudySync Admin.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _showAddAdminDialog(context),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Grant admin access', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 16),
            ...emails.map((email) {
              final isSelf = me == email;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AdminSurfaceCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AdminUi.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          email[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AdminRosterStore.instance.displayNameFor(email),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(email, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            if (isSelf)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Signed in as you',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (AdminRosterStore.instance.canRemove(email))
                        IconButton(
                          tooltip: 'Remove admin',
                          onPressed: () => _confirmRemove(context, email),
                          icon: const Icon(Icons.person_remove_outlined, color: Color(0xFFB91C1C)),
                        )
                      else
                        Tooltip(
                          message: 'Cannot remove the last admin',
                          child: Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade400),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
