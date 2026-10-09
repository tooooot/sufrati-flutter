// جلسة المستخدم: الدخول (Google/Apple) ثم الدور. الدور يُستنتج من ارتباطاته الحقيقية (بيت/دعوة)،
// ولا يُمنح الطبيب بالاختيار الذاتي: يلزم تفعيل المدير (users/{uid}.isDoctor).
import 'package:flutter/foundation.dart';

import '../data/links.dart';
import 'auth_service.dart';
import 'roles.dart';

class Session extends ChangeNotifier {
  final AuthService auth;
  final LinkService links;
  Role? _role;

  Session(this.auth, this.links) {
    auth.addListener(() {
      if (auth.user == null) _role = null; // خروج ← يُنسى الدور
      notifyListeners();
    });
    links.addListener(notifyListeners);
  }

  AppUser? get user => auth.user;
  bool get signedIn => user != null;
  bool get isAdmin => user?.isAdmin ?? false;

  /// لا نسأل عن الدور قبل أن تُحمَّل ارتباطات المستخدم.
  bool get ready => !signedIn || links.ready;

  Role? get role {
    if (isAdmin) return Role.admin;
    if (_role == Role.doctor && !links.isDoctor) return null; // لا طبيب بلا تفعيل
    return _role ?? links.suggestedRole;
  }

  bool get needsRole => signedIn && ready && role == null;

  void chooseRole(Role r) {
    _role = r;
    notifyListeners();
  }
}
