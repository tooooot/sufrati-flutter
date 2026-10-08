// واجهة الدخول — الشاشات تتعامل معها فقط. التنفيذ الحقيقي (FirebaseAuthService: Google + Apple)
// يُضاف بعد تثبيت حزم Firebase؛ والمعاينة تستعمل FakeAuthService.
import 'package:flutter/foundation.dart';

enum SignInMethod { google, apple }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final bool isAdmin; // claim يضعه السيرفر لإيميل المدير فقط
  final bool isDoctor; // يمنحه المدير
  const AppUser({required this.uid, required this.name, required this.email, this.isAdmin = false, this.isDoctor = false});
}

class SignInCancelled implements Exception {
  const SignInCancelled();
}

abstract class AuthService extends ChangeNotifier {
  AppUser? get user;
  /// Apple متاح على iOS/macOS/الويب؛ على أندرويد يظهر Google فقط.
  bool isAvailable(SignInMethod method);
  Future<void> signIn(SignInMethod method);
  Future<void> signOut();
  /// حذف الحساب وكل بياناته — شرط Apple/Google.
  Future<void> deleteAccount();
}

/// للمعاينة والاختبار: يسجّل دخولاً وهمياً بلا شبكة.
class FakeAuthService extends AuthService {
  AppUser? _user;
  final bool apple;
  FakeAuthService({this.apple = true});
  @override
  AppUser? get user => _user;
  @override
  bool isAvailable(SignInMethod m) => m == SignInMethod.google || apple;
  @override
  Future<void> signIn(SignInMethod m) async {
    _user = AppUser(uid: 'fake-${m.name}', name: 'مستخدم تجريبي', email: 'demo@example.com');
    notifyListeners();
  }
  @override
  Future<void> signOut() async {
    _user = null;
    notifyListeners();
  }
  @override
  Future<void> deleteAccount() => signOut();
}
