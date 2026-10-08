import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/auth/roles.dart';

void main() {
  test('جدول الصلاحيات مطابق للمعتمد', () {
    // [الصلاحية, مدير, طبيب, صاحب, طباخ]
    final table = <Perm, List<bool>>{
      Perm.viewPlan: [true, true, true, true],
      Perm.editPlan: [true, true, true, false],
      Perm.viewShopping: [true, true, true, true],
      Perm.editShopping: [true, true, true, false],
      Perm.markPrepared: [true, false, false, true],
      Perm.viewHealth: [true, true, true, false],
      Perm.requestProgram: [true, true, true, false],
      Perm.uploadProgram: [true, true, false, false],
      Perm.deleteHousehold: [true, false, true, false],
      Perm.viewPlatform: [true, false, false, false],
    };
    const order = [Role.admin, Role.doctor, Role.owner, Role.cook];
    for (final e in table.entries) {
      for (var i = 0; i < 4; i++) {
        expect(can(order[i], e.key), e.value[i], reason: '${order[i].name} / ${e.key.name}');
      }
    }
    expect(table.length, Perm.values.length, reason: 'كل صلاحية لها صف في الجدول');
  });

  test('الدعوات', () {
    expect(canInvite(Role.owner, Role.cook), isTrue);
    expect(canInvite(Role.owner, Role.doctor), isTrue);
    expect(canInvite(Role.owner, Role.owner), isFalse);
    expect(canInvite(Role.doctor, Role.owner), isTrue);
    expect(canInvite(Role.doctor, Role.cook), isFalse);
    expect(canInvite(Role.cook, Role.cook), isFalse);
    expect(canInvite(Role.admin, Role.admin), isFalse);
    expect(Role.parse('cook'), Role.cook);
    expect(Role.parse('x'), isNull);
  });
}
