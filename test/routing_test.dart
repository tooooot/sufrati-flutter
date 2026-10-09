import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/auth/auth_service.dart';
import 'fake_auth.dart';
import 'package:sufrati/auth/roles.dart';
import 'package:sufrati/auth/session.dart';
import 'package:sufrati/routing.dart';

void main() {
  test('بلا دخول: كل شيء يذهب للدخول عدا التصفح', () {
    final s = Session(FakeAuthService());
    expect(appRedirect(s, '/'), '/login');
    expect(appRedirect(s, '/profile'), '/login');
    expect(appRedirect(s, '/household'), '/login');
    expect(appRedirect(s, '/login'), isNull);
    expect(appRedirect(s, '/browse'), isNull);
    expect(appRedirect(s, '/programs/keto_general'), isNull);
  });

  test('بعد الدخول وقبل اختيار الدور: الدور أولاً، لكن الملف الشخصي يفتح', () async {
    final auth = FakeAuthService();
    final s = Session(auth);
    await auth.signIn(SignInMethod.google);
    expect(appRedirect(s, '/login'), '/role');
    expect(appRedirect(s, '/'), '/role');
    expect(appRedirect(s, '/household'), '/role');
    expect(appRedirect(s, '/role'), isNull);
    expect(appRedirect(s, '/profile'), isNull, reason: 'الخطأ السابق: الملف الشخصي كان يُحوَّل لاختيار الدور');
    expect(appRedirect(s, '/browse'), isNull);
  });

  test('بعد اختيار الدور: الصفحات مفتوحة، والدخول يعيدك للرئيسية', () async {
    final auth = FakeAuthService();
    final s = Session(auth);
    await auth.signIn(SignInMethod.apple);
    s.chooseRole(Role.owner);
    expect(appRedirect(s, '/household'), isNull);
    expect(appRedirect(s, '/profile'), isNull);
    expect(appRedirect(s, '/login'), '/');
  });
}
