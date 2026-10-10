import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/data/marketing.dart';

void main() {
  test('تطبيع رقم واتساب', () {
    expect(normalizePhone('0501234567'), '966501234567');
    expect(normalizePhone('+966 50 123 4567'), '966501234567');
    expect(normalizePhone('00966501234567'), '966501234567');
    expect(normalizePhone('501234567'), '966501234567');
    expect(normalizePhone('12'), isNull);
    expect(normalizePhone(''), isNull);
  });

  test('الرسالة: تعريف بالنفس في أول سطرين وجملة إلغاء والرابط', () {
    final m = buildMessage(TargetKind.doctor, 'د. خالد', 'https://maeda.wardyat.net/p/ABC');
    expect(m, startsWith('السلام عليكم د. خالد،'));
    expect(m, contains('فريق تطبيق «سفرتي»'));
    expect(m, contains('https://maeda.wardyat.net/p/ABC'));
    expect(m, contains('اكتب «لا»'));
    expect(buildMessage(TargetKind.coach, 'سلمى', 'x'), contains('جمهورك'));
    expect(TargetKindX.parse('group_owner'), TargetKind.coach, reason: 'الاسم القديم يعمل');
    expect(TargetKind.values.every((k) => k.pitchKind == 'doctor'), isTrue, reason: 'دور واحد للأخصائي وصاحب الجروب');
  });

  test('الحالة المعروضة: الرفض والتأجيل يغلبان، ثم الأعلى تقدماً', () {
    TargetStatus d(String m, {bool s = false, bool o = false, bool r = false}) =>
        deriveStatus(manual: m, sent: s, opened: o, registered: r);
    expect(d(''), TargetStatus.fresh);
    expect(d('', s: true), TargetStatus.sent);
    expect(d('', s: true, o: true), TargetStatus.opened);
    expect(d('', s: true, o: true, r: true), TargetStatus.registered);
    expect(d('declined', s: true, o: true), TargetStatus.declined);
    expect(d('skipped'), TargetStatus.skipped);
  });

  test('عدّاد اليوم يحسب اليوم نفسه فقط', () {
    final now = DateTime(2026, 10, 10, 15);
    final list = [DateTime(2026, 10, 10, 8), DateTime(2026, 10, 10, 14), DateTime(2026, 10, 9, 23), DateTime(2025, 10, 10)];
    expect(sentToday(list, now), 2);
    expect(dailySendLimit, 15);
  });
}
