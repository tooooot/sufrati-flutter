import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/data/household.dart';
import 'package:sufrati/data/i18n.dart';
import 'package:sufrati/data/repository.dart';
import 'package:sufrati/data/store.dart';
import 'package:sufrati/notify/cook_alerts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('تنبيهان لكل وجبة × 7 أيام: قبلها بـ45 دقيقة وعند موعدها، بمعرّفات فريدة', () async {
    final lib = await Library.load();
    final i18n = await CookI18n.load();
    final store = LocalStore(lib, Household(id: 'h', label: 'بيت', programId: 'kidney_salama', eaters: 2), seed: 1);
    final program = await store.program();
    final now = DateTime(2026, 10, 10, 0, 0); // سبت، منتصف الليل: كل أوقات اليوم قادمة
    final alerts = await buildCookAlerts(store, i18n, nowSaudi: now);

    expect(alerts.length, 7 * program.slots.length * 2);
    expect(alerts.map((a) => a.id).toSet().length, alerts.length, reason: 'المعرّفات فريدة ← إعادة الجدولة تستبدل');
    expect(alerts.every((a) => a.at.isAfter(now)), isTrue);

    final prep = alerts.where((a) => a.title.contains('ابدأ التحضير')).toList();
    final serve = alerts.where((a) => a.title.contains('وقت التقديم')).toList();
    expect(prep.length, serve.length);
    // أول وجبة: تنبيه التحضير قبل التقديم بـ45 دقيقة بالضبط
    final firstServe = serve.first;
    final firstPrep = prep.firstWhere((a) => a.id == firstServe.id - 1);
    expect(firstServe.at.difference(firstPrep.at).inMinutes, prepLeadMinutes);
    expect(firstServe.body, isNotEmpty);
  });

  test('الأوقات الماضية تُتخطّى: بعد آخر وجبة اليوم لا تنبيهات لليوم نفسه', () async {
    final lib = await Library.load();
    final i18n = await CookI18n.load();
    final store = LocalStore(lib, Household(id: 'h', label: 'بيت', programId: 'kidney_salama'), seed: 2);
    final late = DateTime(2026, 10, 10, 23, 59);
    final alerts = await buildCookAlerts(store, i18n, nowSaudi: late);
    expect(alerts.where((a) => a.at.day == 10), isEmpty);
    expect(alerts, isNotEmpty);
  });

  test('اللغة الإنجليزية تغيّر عناوين التنبيه', () async {
    final lib = await Library.load();
    final i18n = await CookI18n.load();
    final store = LocalStore(lib, Household(id: 'h', label: 'بيت', programId: 'kidney_salama'), seed: 3);
    final alerts = await buildCookAlerts(store, i18n, nowSaudi: DateTime(2026, 10, 10), lang: 'en');
    expect(alerts.first.title, anyOf(contains('Start preparing'), contains('Time to serve')));
  });
}
