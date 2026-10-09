// دخول وهمي للاختبارات فقط — غير موجود في التطبيق.
import 'package:sufrati/auth/auth_service.dart';

/// يسجّل دخولاً وهمياً بلا شبكة.
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
