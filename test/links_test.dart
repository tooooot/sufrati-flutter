import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/auth/roles.dart';
import 'package:sufrati/data/links.dart';

void main() {
  test('صاحب البيت يدعو الطاهي والطاهي يدخل الرمز مرة واحدة فقط', () {
    final l = LinkService()..createHousehold('بيت أبو عبدالله', 'kidney_salama', 2);
    expect(l.hasHousehold, isTrue);
    final inv = l.createInvite(Role.cook);
    expect(inv.code.length, 6);
    expect(l.inviteFor(Role.cook), isNotNull);

    expect(l.redeem('ZZZZZZ', Role.cook), contains('غير صحيح'));
    expect(l.redeem(inv.code, Role.doctor), contains('مخصّص لـ«الطاهي»'), reason: 'الدور يجب أن يطابق الدعوة');
    expect(l.redeem(' ${inv.code.toLowerCase()} ', Role.cook, who: 'ماريا'), isNull, reason: 'حروف صغيرة ومسافات مقبولة');
    expect(l.joinedBy(Role.cook)?.usedBy, 'ماريا');
    expect(l.redeem(inv.code, Role.cook), contains('استُخدم'), reason: 'يعمل مرة واحدة');
  });

  test('الرمز المنتهي مرفوض والحذف يمسح كل الارتباطات', () {
    var now = DateTime(2026, 10, 9);
    final l = LinkService(clock: () => now)..createHousehold('بيت', 'keto_general', 1);
    final inv = l.createInvite(Role.doctor);
    now = now.add(const Duration(days: 8));
    expect(l.redeem(inv.code, Role.doctor), contains('انتهت'));
    expect(l.joinedBy(Role.doctor), isNull);
    l.leaveAll();
    expect(l.hasHousehold, isFalse);
    expect(l.memberships, isEmpty);
    expect(l.invites, isEmpty);
  });

  test('الارتباطات تظهر في الملف الشخصي بأدوارها', () {
    final l = LinkService()..createHousehold('بيتي', 'keto_general', 1);
    expect(l.memberships.single.role, Role.owner);
    expect(roleName(Role.cook), 'الطاهي');
  });
}
