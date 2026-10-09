// جلسة المستخدم: الدخول (Google/Apple) ثم اختيار الدور. الراوتر يقرأ منها ليقرّر أي شاشة تظهر.
// الدور المختار محفوظ في الذاكرة فقط حالياً؛ يصير عضوية دائمة في Firestore (households.members) بعد نشر القواعد.
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'roles.dart';

class Session extends ChangeNotifier {
  final AuthService auth;
  Role? _role;

  Session(this.auth) {
    auth.addListener(() {
      if (auth.user == null) _role = null; // خروج ← يُنسى الدور
      notifyListeners();
    });
  }

  AppUser? get user => auth.user;
  bool get signedIn => user != null;

  /// المدير لا يحتاج اختيار دور.
  Role? get role => (user?.isAdmin ?? false) ? Role.admin : _role;
  bool get needsRole => signedIn && role == null;

  void chooseRole(Role r) {
    _role = r;
    notifyListeners();
  }
}
