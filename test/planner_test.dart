import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/data/models.dart';
import 'package:sufrati/logic/planner.dart';

Program load(String id) {
  final index = jsonDecode(File('assets/data/programs_index.json').readAsStringSync());
  final meta = ProgramMeta((index['programs'] as List).firstWhere((p) => p['id'] == id));
  return Program(meta, jsonDecode(File('assets/data/programs/$id.json').readAsStringSync()));
}

void main() {
  test('formatQty يطابق _format_qty في بايثون حرفياً', () {
    // القيم المرجعية مأخوذة من تشغيل maeda/app/planner.py
    final ref = <double, String>{1.0: '1', 2.0: '2', 0.5: '½', 1.5: '1½', 1 / 3: '⅓', 2 / 3: '⅔', 0.25: '¼', 2.75: '2¾',
      1 / 6: '¼', 5 / 12: '½', 3.0: '3', 7 / 3: '2⅓', 0.2: '¼', 1.1: '1'};
    ref.forEach((v, expected) => expect(formatQty(v), expected, reason: '$v'));
  });

  test('الأسبوع يبدأ السبت', () {
    expect(weekStartFor(DateTime(2026, 10, 5)), DateTime(2026, 10, 3)); // الاثنين ← السبت
    expect(weekStartFor(DateTime(2026, 10, 3)), DateTime(2026, 10, 3));
    expect(weekStartFor(DateTime(2026, 10, 9)), DateTime(2026, 10, 3)); // الجمعة
  });

  final ids = (jsonDecode(File('assets/data/programs_index.json').readAsStringSync())['programs'] as List)
      .where((p) => p['status'] == 'active').map((p) => p['id'] as String).toList();

  for (final id in ids) {
    test('$id: 300 أسبوع عشوائي تحترم الحدود الأسبوعية ونوع اليوم', () {
      final program = load(id);
      for (var seed = 0; seed < 300; seed++) {
        final picks = pickWeekOptions(program, random: Random(seed));
        expect(picks.length, 7 * program.slots.length);
        for (final MapEntry(key: tag, value: rule) in program.limits.entries) {
          final n = picks.where((p) => p.option.tags.contains(tag)).length;
          if (rule.maxMeals != null) expect(n, lessThanOrEqualTo(rule.maxMeals!), reason: '$tag max seed=$seed');
          if (rule.minMeals != null) expect(n, greaterThanOrEqualTo(rule.minMeals!), reason: '$tag min seed=$seed');
        }
        if (program.dayTypePattern != null) {
          for (final p in picks) {
            if (p.option.dayType != null) expect(p.option.dayType, program.dayTypePattern![p.day]);
          }
        }
      }
    });
  }

  test('كل مكوّن مستخدم معرّف (التصدير سليم)', () {
    for (final id in ids) {
      final program = load(id);
      for (final s in program.slots) {
        for (final o in s.options) {
          for (final (key, _) in o.items) {
            expect(program.ingredients.containsKey(key), isTrue, reason: '$id/${o.id}/$key');
          }
        }
      }
    }
  });
}
