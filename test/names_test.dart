import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/logic/names.dart';

void main() {
  test('الاسم الأول للتحية: الكنية والأسماء المركبة لا تُقطع', () {
    expect(firstName('أبو سعد'), 'أبو سعد');
    expect(firstName('أم عبدالله الشهري'), 'أم عبدالله');
    expect(firstName('عبد الرحمن القحطاني'), 'عبد الرحمن');
    expect(firstName('سارة أحمد'), 'سارة');
    expect(firstName('  خالد  '), 'خالد');
    expect(firstName(''), '');
    expect(firstName('أم'), 'أم', reason: 'كلمة وحيدة تبقى كما هي');
  });
}
