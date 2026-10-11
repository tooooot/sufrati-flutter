import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/auth/roles.dart';
import 'package:sufrati/data/links.dart';

void main() {
  test('شريك الإدارة: دعوة بدور مدير ثانٍ لبيت واحد (لا بيتان)، ولا تُقبل بدور غير دورها', () async {
    final l = MemoryLinkService();
    await l.createHousehold('بيتنا', 'saudi_family', 5);
    final inv = await l.createInvite(Role.owner);
    expect(l.inviteFor(Role.owner), isNotNull);
    expect(await l.redeem(inv.code, Role.cook), contains('مخصّص'), reason: 'دور الدعوة مدير لا طاهٍ');
    expect(await l.redeem(inv.code, Role.owner, who: 'الزوج'), isNull);
    expect(l.joinedBy(Role.owner)?.usedBy, 'الزوج');
    expect(l.membershipOf(Role.owner)?.householdLabel, 'بيتنا', reason: 'البيت نفسه');
  });

  test('مدير البيت يلغي دعوة معلّقة ويزيل من انضم', () async {
    final l = MemoryLinkService();
    await l.createHousehold('بيت', 'keto_general', 1);
    final inv = await l.createInvite(Role.cook);
    await l.removeRole(Role.cook);
    expect(l.inviteFor(Role.cook), isNull);
    expect(await l.redeem(inv.code, Role.cook), isNotNull, reason: 'الدعوة الملغاة لا تعمل');
    final inv2 = await l.createInvite(Role.cook);
    await l.redeem(inv2.code, Role.cook, who: 'ماريا');
    expect(l.joinedBy(Role.cook), isNotNull);
    await l.removeRole(Role.cook);
    expect(l.joinedBy(Role.cook), isNull);
  });

  test('مدير البيت يدعو الطاهي والطاهي يدخل الرمز مرة واحدة فقط', () async {
    final l = MemoryLinkService();
    await l.createHousehold('بيت أبو عبدالله', 'kidney_salama', 2);
    expect(l.hasHousehold, isTrue);
    final inv = await l.createInvite(Role.cook);
    expect(inv.code.length, 8);
    expect(l.inviteFor(Role.cook), isNotNull);

    expect(await l.redeem('ZZZZZZ', Role.cook), contains('غير صحيح'));
    expect(await l.redeem(inv.code, Role.doctor), contains('مخصّص لـ«الطاهي»'), reason: 'الدور يجب أن يطابق الدعوة');
    expect(await l.redeem(' ${inv.code.toLowerCase()} ', Role.cook, who: 'ماريا'), isNull, reason: 'حروف صغيرة ومسافات مقبولة');
    expect(l.joinedBy(Role.cook)?.usedBy, 'ماريا');
    expect(await l.redeem(inv.code, Role.cook), contains('استُخدم'), reason: 'يعمل مرة واحدة');
  });

  test('الرمز المنتهي مرفوض والحذف يمسح كل الارتباطات', () async {
    var now = DateTime(2026, 10, 9);
    final l = MemoryLinkService(clock: () => now);
    await l.createHousehold('بيت', 'keto_general', 1);
    final inv = await l.createInvite(Role.doctor);
    now = now.add(const Duration(days: 8));
    expect(await l.redeem(inv.code, Role.doctor), contains('انتهت'));
    expect(l.joinedBy(Role.doctor), isNull);
    await l.deleteMyData();
    expect(l.hasHousehold, isFalse);
    expect(l.memberships, isEmpty);
    expect(l.invites, isEmpty);
  });

  test('الارتباطات تظهر في الملف الشخصي بأدوارها', () async {
    final l = MemoryLinkService();
    await l.createHousehold('بيتي', 'keto_general', 1);
    expect(l.memberships.single.role, Role.owner);
    expect(roleName(Role.cook), 'الطاهي');
  });
}
