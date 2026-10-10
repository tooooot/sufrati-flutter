import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/auth/roles.dart';
import 'package:sufrati/data/growth.dart';
import 'package:sufrati/data/links.dart';
import 'package:sufrati/routing.dart';
import 'package:sufrati/screens/pitch_content.dart';
import 'package:sufrati/screens/pitch_visuals.dart';

import 'fake_auth.dart';
import 'package:sufrati/auth/session.dart';

void main() {
  test('رمز الطبيب 8 خانات بلا حروف ملتبسة', () {
    for (var i = 0; i < 50; i++) {
      final c = newDoctorCode(Random(i));
      expect(c.length, 8);
      expect(RegExp(r'^[A-HJ-NP-Z2-9]+$').hasMatch(c), isTrue, reason: c);
    }
  });

  test('الطبيب غير المعتمد لا يظهر علناً، وبعد الاعتماد يطلب المريض الربط ويقبل الطبيب', () async {
    final links = MemoryLinkService();
    final g = MemoryGrowthService(links);
    final p = await g.saveProfile(name: 'د. أحمد', specialty: 'تغذية علاجية', city: 'جدة');
    expect(await g.byCode(p.code), isNull, reason: 'غير موثَّق');
    expect(await g.requestLink(p.code), contains('غير متاح'));
    g.profiles[p.code] = DoctorProfile(code: p.code, uid: p.uid, name: p.name, verified: true);
    expect((await g.byCode(p.code.toLowerCase()))?.name, 'د. أحمد', reason: 'الرمز يُقبل بحروف صغيرة');

    expect(await g.requestLink(p.code), contains('بيتك'), reason: 'لا بيت بعد');
    await links.createHousehold('بيت سارة', 'kidney_salama', 1);
    expect(await g.requestLink(p.code), isNull);
    final reqs = await g.requests();
    expect(reqs, hasLength(1));
    expect(await g.accept(reqs.first), isNull);
    expect(await g.requests(), isEmpty);
    expect(links.joinedBy(Role.doctor), isNotNull);
  });

  test('رابط التسويق: النوع والاسم، ورابط مجهول يعود للعرض العام', () async {
    final g = MemoryGrowthService(MemoryLinkService());
    g.pitches['TOK'] = const PitchLink('TOK', 'doctor', 'د. خالد');
    expect((await g.pitch('TOK'))?.kind, 'doctor');
    expect(await g.pitch('NOPE'), isNull);
  });

  test('لقطات العرض: أربع لكل دور، وكلها ببنية سليمة', () {
    for (final k in ['user', 'doctor', 'group', 'cook', 'غير معروف']) {
      final b = beatsFor(k, name: 'د. خالد');
      expect(b, hasLength(4), reason: k);
      for (final x in b) {
        expect(x.title, isNotEmpty);
        expect(x.sub, isNotEmpty);
      }
    }
  });

  test('المسارات العامة: التسويق وصفحة الطبيب بلا دخول، وربط الطبيب (join) بدخول', () {
    final s = Session(FakeAuthService(), MemoryLinkService());
    expect(appRedirect(s, '/p/ABC123'), isNull);
    expect(appRedirect(s, '/pitch/doctor'), isNull);
    expect(appRedirect(s, '/dr/ABCD2345'), isNull);
    expect(appRedirect(s, '/dr/ABCD2345/join', full: '/dr/ABCD2345/join'), startsWith('/login?next='));
    expect(appRedirect(s, '/doctor/profile'), startsWith('/login'));
  });

  test('عرض الطاهي بثلاث لغات: أربع لقطات لكل لغة، ونصوص الرسوم مكتملة، واللغة المجهولة عربية', () {
    for (final l in ['ar', 'en', 'am']) {
      final b = cookBeats(l);
      expect(b, hasLength(4), reason: l);
      expect(chromeFor(l).cta, isNotEmpty);
      for (final k in ['meal', 'time', 'dish', 'i1', 'i2', 'i3', 'n1', 'n2', 'btn', 'ok']) {
        expect(cookText[l]![k], isNotEmpty, reason: '$l/$k');
      }
    }
    expect(cookBeats('xx').first.title, cookBeats('ar').first.title);
    expect(chromeFor('en').rtl, isFalse);
    expect(chromeFor('am').rtl, isFalse);
    expect(chromeFor('ar').rtl, isTrue);
  });
}
