import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/auth/auth_service.dart';
import 'fake_auth.dart';
import 'package:sufrati/auth/roles.dart';
import 'package:sufrati/auth/session.dart';
import 'package:sufrati/data/links.dart';
import 'package:sufrati/routing.dart';

void main() {
  test('بلا دخول: كل شيء يذهب للدخول عدا التصفح', () {
    final s = Session(FakeAuthService(), MemoryLinkService());
    expect(appRedirect(s, '/'), startsWith('/login'));
    expect(appRedirect(s, '/profile'), '/login?next=%2Fprofile');
    expect(appRedirect(s, '/household', full: '/household?x=1'), '/login?next=%2Fhousehold%3Fx%3D1');
    expect(appRedirect(s, '/login'), isNull);
    expect(appRedirect(s, '/browse'), isNull);
    expect(appRedirect(s, '/programs/keto_general'), isNull);
  });

  test('بعد الدخول وقبل اختيار الدور: الدور أولاً، لكن الملف الشخصي يفتح', () async {
    final auth = FakeAuthService();
    final s = Session(auth, MemoryLinkService());
    await auth.signIn(SignInMethod.google);
    expect(appRedirect(s, '/login'), '/role');
    expect(appRedirect(s, '/'), '/role');
    expect(appRedirect(s, '/household'), '/role');
    expect(appRedirect(s, '/role'), isNull);
    expect(appRedirect(s, '/profile'), isNull, reason: 'الخطأ السابق: الملف الشخصي كان يُحوَّل لاختيار الدور');
    expect(appRedirect(s, '/browse'), isNull);
  });

  test('بعد اختيار الدور: الصفحات مفتوحة، والدخول يعيدك لشاشة الدور', () async {
    final auth = FakeAuthService();
    final s = Session(auth, MemoryLinkService());
    await auth.signIn(SignInMethod.apple);
    s.chooseRole(Role.owner);
    expect(appRedirect(s, '/household'), isNull);
    expect(appRedirect(s, '/profile'), isNull);
    expect(appRedirect(s, '/login'), '/household', reason: 'صاحب بيت بلا بيت ← صفحة بيتي');
  });

  test('الهبوط بحسب الدور بعد وجود الارتباطات', () async {
    final auth = FakeAuthService();
    final links = MemoryLinkService();
    final s = Session(auth, links);
    await auth.signIn(SignInMethod.google);
    await links.createHousehold('بيت', 'keto_general', 1);
    expect(s.role, Role.owner, reason: 'الدور يُستنتج من الارتباط بلا اختيار');
    expect(appRedirect(s, '/'), '/me');
    expect(appRedirect(s, '/login'), '/me');
    s.chooseRole(Role.cook);
    expect(appRedirect(s, '/'), '/join/cook', reason: 'طاهٍ بلا ارتباط ← إدخال الرمز');
  });

  test('الطبيب لا يُمنح بالاختيار الذاتي', () async {
    final auth = FakeAuthService();
    final s = Session(auth, MemoryLinkService());
    await auth.signIn(SignInMethod.google);
    s.chooseRole(Role.doctor);
    expect(s.role, isNull, reason: 'isDoctor=false ← لا دور طبيب');
    expect(s.needsRole, isTrue);
  });

  test('لوحة المدير للمدير وحده', () async {
    final auth = FakeAuthService();
    final s = Session(auth, MemoryLinkService());
    await auth.signIn(SignInMethod.google);
    s.chooseRole(Role.owner);
    expect(appRedirect(s, '/admin'), isNot('/admin'));
  });

  test('الدخول يعيدك للصفحة التي كنت فيها، ويرفض الوجهات الخارجية', () async {
    final auth = FakeAuthService();
    final links = MemoryLinkService();
    final s = Session(auth, links);
    await auth.signIn(SignInMethod.google);
    await links.createHousehold('بيت', 'keto_general', 1);
    expect(appRedirect(s, '/login', next: '/cook'), '/cook');
    expect(appRedirect(s, '/login', next: '/profile'), '/profile');
    expect(appRedirect(s, '/login', next: 'https://evil.example'), '/me');
    expect(appRedirect(s, '/login', next: '//evil.example'), '/me');
    expect(appRedirect(s, '/login', next: '/login?next=/x'), '/me');
  });
}
