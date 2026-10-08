import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/data/household.dart';
import 'package:sufrati/data/models.dart';
import 'package:sufrati/logic/planner.dart';
import 'package:sufrati/logic/prayer.dart';
import 'package:sufrati/logic/shopping.dart';

int mins(String hm) => int.parse(hm.split(':')[0]) * 60 + int.parse(hm.split(':')[1]);

void main() {
  test('مواقيت جدة المحلية تطابق Aladhan (أم القرى) المخزّنة في maeda بفارق ≤ دقيقتين', () {
    // من prayer_cache في قاعدة الإنتاج (Aladhan method=4)
    final ref = {
      DateTime(2026, 10, 9): {'Fajr': '05:01', 'Sunrise': '06:17', 'Dhuhr': '12:11', 'Asr': '15:33', 'Maghrib': '18:04', 'Isha': '19:34'},
      DateTime(2026, 10, 10): {'Fajr': '05:01', 'Sunrise': '06:17', 'Dhuhr': '12:10', 'Asr': '15:33', 'Maghrib': '18:03', 'Isha': '19:33'},
      DateTime(2026, 10, 11): {'Fajr': '05:01', 'Sunrise': '06:18', 'Dhuhr': '12:10', 'Asr': '15:32', 'Maghrib': '18:02', 'Isha': '19:32'},
    };
    ref.forEach((date, expected) {
      final got = prayerTimes(date, 'Jeddah');
      for (final name in prayerNames) {
        expect((mins(got[name]!) - mins(expected[name]!)).abs(), lessThanOrEqualTo(2),
            reason: '$date $name: ${got[name]} vs ${expected[name]}');
      }
    });
  });

  test('وقت الوجبة = الصلاة + الإزاحة، و ar12', () {
    final t = resolveMealTimes(DateTime(2026, 10, 10), 'Jeddah', defaultMealLinks);
    expect(mins(t['meal2']!), mins(prayerTimes(DateTime(2026, 10, 10), 'Jeddah')['Dhuhr']!) + 60);
    expect(ar12('20:00'), '08:00 م');
    expect(ar12('00:30', 'en'), '12:30 AM');
  });

  test('المشتريات: تقريب لأعلى بوحدات الشراء، والحفاظ على تعديل المستخدم', () {
    final index = jsonDecode(File('assets/data/programs_index.json').readAsStringSync());
    final p = Program(ProgramMeta((index['programs'] as List).firstWhere((x) => x['id'] == 'kidney_salama')),
        jsonDecode(File('assets/data/programs/kidney_salama.json').readAsStringSync()));
    final picks = pickWeekOptions(p, random: Random(1));
    final days = List.generate(7, (_) => <String, String>{});
    for (final pk in picks) {
      days[pk.day][pk.slotId] = pk.option.id;
    }
    final plan = WeekPlan(DateTime(2026, 10, 3), days);
    final lines = buildShopping(p, plan, 2);
    for (final l in lines) {
      var total = 0.0;
      for (final d in days) {
        for (final e in d.entries) {
          final o = p.slots.firstWhere((s) => s.id == e.key).options.firstWhere((o) => o.id == e.value);
          for (final (k, q) in o.items) {
            if (k == l.key) total += q * 2;
          }
        }
      }
      expect(l.packs, max(1, (total / p.ingredients[l.key]!.buyQty).ceil()), reason: l.key);
    }
    lines.first.packs = 9;
    lines.first.bought = true;
    final again = buildShopping(p, plan, 2, previous: lines);
    expect(again.first.packs, 9);
    expect(again.first.bought, isTrue);
  });

  test('قفل المشتريات: نفس is_locked', () {
    final ws = DateTime(2026, 10, 3); // سبت
    expect(isLocked(ws, DateTime(2026, 10, 6, 19, 59), 3, '20:00'), isFalse);
    expect(isLocked(ws, DateTime(2026, 10, 6, 20, 0), 3, '20:00'), isTrue);
    expect(isLocked(DateTime(2026, 9, 26), DateTime(2026, 10, 4), 3, '20:00'), isTrue);
    expect(isLocked(DateTime(2026, 10, 10), DateTime(2026, 10, 9, 23), 3, '20:00'), isFalse);
  });
}
