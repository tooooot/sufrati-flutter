// واجهة الدخول — الشاشات تتعامل معها فقط. التنفيذ الحقيقي (FirebaseAuthService: Google + Apple)
// يُضاف بعد تثبيت حزم Firebase؛ والويب يستعمل WebAuthService (بلا دخول).
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

  /// دخول المراجعين (Apple/Google Play): حساب بريد وكلمة سر حقيقي في Firebase، لا يُعرض إلا في قسم مطوي بشاشة الدخول.
  bool get supportsPassword => false;
  Future<void> signInWithPassword(String email, String password) async =>
      throw UnsupportedError('غير متاح');
  /// حذف الحساب وكل بياناته — شرط Apple/Google.
  Future<void> deleteAccount();
}

/// الويب: لا دخول (Firebase غير مسجَّل للويب). صفحات التصفح العامة فقط، والدخول في تطبيق الجوال.
class WebAuthService extends AuthService {
  @override
  AppUser? get user => null;
  @override
  bool isAvailable(SignInMethod m) => false;
  @override
  Future<void> signIn(SignInMethod m) async => throw UnsupportedError('الدخول متاح في تطبيق الجوال');
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount() async {}
}
