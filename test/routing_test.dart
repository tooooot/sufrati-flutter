import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/auth/auth_service.dart';
import 'fake_auth.dart';
import 'package:sufrati/auth/roles.dart';
import 'package:sufrati/auth/session.dart';
import 'package:sufrati/data/household.dart';
import 'package:sufrati/data/links.dart';
import 'package:sufrati/logic/shopping.dart';
import 'package:sufrati/routing.dart';

void main() {
  test('روابط الدخول الأول تصل وجهتها حتى بلا دور: دعوة الطاهي ومتابعو الطبيب والتسويق وطلب الطبيب', () async {
    final auth = FakeAuthService();
    final s = Session(auth, MemoryLinkService());
    await auth.signIn(SignInMethod.google);
    expect(s.needsRole, isTrue);
    for (final n in ['/i/K7M2QX4D', '/dr/AB12CD34/join', '/r/TOKEN123', '/doctor/apply', '/join/cook']) {
      expect(appRedirect(s, '/login', next: n), n, reason: n);
      expect(appRedirect(s, '/loading', next: n), n, reason: 'تحديث الصفحة: $n');
    }
    expect(appRedirect(s, '/login', next: '/me'), '/role', reason: 'الرئيسية تتطلب دوراً');
    expect(appRedirect(s, '/login', next: '//evil.example'), '/role', reason: 'خارجي مرفوض');
  });

  test('الصفحة التعريفية للزائر على الويب فقط، والدعوة تُقبل قبل اختيار الدور', () {
    final s = Session(FakeAuthService(), MemoryLinkService());
    expect(appRedirect(s, '/', landingForGuests: true), isNull);
    expect(appRedirect(s, '/'), startsWith('/login'));
    expect(appRedirect(s, '/me', landingForGuests: true), startsWith('/login'));
  });

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
    expect(appRedirect(s, '/login'), '/new-house', reason: 'صاحب خطة بلا بيت ← إنشاء البيت');
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

  test('أثناء تحميل الارتباطات تُحفظ الوجهة فلا يضيع الرابط العميق', () async {
    final auth = FakeAuthService();
    final links = _SlowLinks();
    final s = Session(auth, links);
    await auth.signIn(SignInMethod.google);
    expect(s.ready, isFalse);
    expect(appRedirect(s, '/cook', full: '/cook?x=1'), '/loading?next=%2Fcook%3Fx%3D1');
    expect(appRedirect(s, '/loading'), isNull);
    links.finish();
    await links.createHousehold('بيت', 'keto_general', 1);
    expect(s.ready, isTrue);
    expect(appRedirect(s, '/loading', next: '/cook?x=1'), '/cook?x=1');
  });

  test('سباق الدخول: وهو على /login والارتباطات تُحمَّل تُحمل وجهة الدخول (next) لا عنوان الدخول', () async {
    final auth = FakeAuthService();
    final links = _SlowLinks();
    final s = Session(auth, links);
    await auth.signIn(SignInMethod.google);
    expect(s.ready, isFalse);
    expect(appRedirect(s, '/login', full: '/login?next=%2Fjourney%2Ffinish', next: '/journey/finish'), '/loading?next=%2Fjourney%2Ffinish');
    links.finish();
    await links.createHousehold('بيت', 'keto_general', 1);
    expect(appRedirect(s, '/loading', next: '/journey/finish'), '/journey/finish');
  });

  test('قفل المشتريات الافتراضي الخميس مساءً (السبت=0 ← الخميس=5)', () async {
    final links = MemoryLinkService();
    expect(links.hasHousehold, isFalse);
    final h = Household(id: 'h', label: 'x', programId: 'keto_general');
    expect(h.cutoffDay, 5);
    // الأسبوع يبدأ السبت 2026-10-10، فالقفل الخميس 2026-10-15 الساعة 20:00
    final wk = DateTime(2026, 10, 10);
    expect(isLocked(wk, DateTime(2026, 10, 14, 23), h.cutoffDay, h.cutoffTime), isFalse, reason: 'الأربعاء مفتوح');
    expect(isLocked(wk, DateTime(2026, 10, 15, 19, 59), h.cutoffDay, h.cutoffTime), isFalse);
    expect(isLocked(wk, DateTime(2026, 10, 15, 20, 0), h.cutoffDay, h.cutoffTime), isTrue);
  });
}

class _SlowLinks extends MemoryLinkService {
  bool _r = false;
  void finish() => _r = true;
  @override
  bool get ready => _r;
}
