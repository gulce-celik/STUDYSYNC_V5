import 'package:flutter/foundation.dart';

import 'admin_email_utils.dart';

/// Session-only admin roster until `GET/POST /admin/staff` exists on backend.
class AdminRosterStore extends ChangeNotifier {
  AdminRosterStore._();

  static final AdminRosterStore instance = AdminRosterStore._();

  static const defaultDemoPassword = 'Admin123!';

  final Map<String, String> _passwords = {
    'oykuaksungur@yeditepe.edu.tr': '${defaultDemoPassword}oa',
    'emreunuvar@yeditepe.edu.tr': '${defaultDemoPassword}eu',
    'efekasapoglu@yeditepe.edu.tr': '${defaultDemoPassword}ek',
    'emrebardak@yeditepe.edu.tr': '${defaultDemoPassword}eb',
    'nazyunusoglu@yeditepe.edu.tr': '${defaultDemoPassword}ny',
    'gulcecelik@yeditepe.edu.tr': '${defaultDemoPassword}gc',
    'melisatokatli@yeditepe.edu.tr': '${defaultDemoPassword}mt',
    'admin@yeditepe.edu.tr': defaultDemoPassword
  };

  List<String> get emails {
    final sorted = _passwords.keys.toList()..sort();
    return List.unmodifiable(sorted);
  }

  bool isListed(String email) => _passwords.containsKey(AdminEmailUtils.normalize(email));

  bool verifyPassword(String email, String password) {
    final key = AdminEmailUtils.normalize(email);
    final expected = _passwords[key];
    return expected != null && expected == password;
  }

  String displayNameFor(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return 'Administrator';
    return local[0].toUpperCase() + local.substring(1);
  }

  /// Grants staff admin access for this device session (demo: default password).
  bool addAdmin(String rawEmail) {
    final email = AdminEmailUtils.normalize(rawEmail);
    if (!AdminEmailUtils.isValidStaffEmail(email)) return false;
    if (_passwords.containsKey(email)) return false;
    _passwords[email] = defaultDemoPassword;
    notifyListeners();
    return true;
  }

  /// Revokes admin access. Returns false if blocked (last admin or unknown).
  bool removeAdmin(String rawEmail) {
    final email = AdminEmailUtils.normalize(rawEmail);
    if (!_passwords.containsKey(email)) return false;
    if (_passwords.length <= 1) return false;
    _passwords.remove(email);
    notifyListeners();
    return true;
  }

  bool canRemove(String rawEmail) {
    final email = AdminEmailUtils.normalize(rawEmail);
    if (!_passwords.containsKey(email)) return false;
    return _passwords.length > 1;
  }
}
