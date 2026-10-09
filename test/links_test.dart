import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/auth/roles.dart';
import 'package:sufrati/data/links.dart';

void main() {
  test('صاحب البيت يدعو الطاهي والطاهي يدخل الرمز مرة واحدة فقط', () async {
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
