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

/// سبب فشل الدخول بلغة المستخدم (لا نعرض «بيانات خاطئة» لكل خطأ).
enum AuthFailureKind { credentials, network, tooMany, disabled, other }

class AuthFailure implements Exception {
  final AuthFailureKind kind;
  const AuthFailure(this.kind);

  String get message => switch (kind) {
        AuthFailureKind.credentials => 'البريد أو كلمة السر غير صحيحة.',
        AuthFailureKind.network => 'تعذّر الاتصال بالإنترنت. تأكد من الشبكة وحاول مرة أخرى.',
        AuthFailureKind.tooMany => 'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.',
        AuthFailureKind.disabled => 'هذا الحساب موقوف. تواصل معنا.',
        AuthFailureKind.other => 'تعذّر تسجيل الدخول. حاول مرة أخرى.',
      };
}

abstract class AuthService extends ChangeNotifier {
  AppUser? get user;

  /// يكتمل بعد استعادة الجلسة المحفوظة (حتى لا نومض شاشة الدخول لمن هو مسجَّل أصلاً).
  Future<void> get initialized async {}
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
