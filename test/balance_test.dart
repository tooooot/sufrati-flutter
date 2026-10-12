import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/data/models.dart';
import 'package:sufrati/logic/calories.dart';
import 'package:sufrati/logic/planner.dart';

Program load(String id) => Program(
    ProgramMeta({'id': id, 'label': id, 'icon': '', 'blurb': '', 'status': 'active', 'category': ''}),
    jsonDecode(File('assets/data/programs/$id.json').readAsStringSync()));

void main() {
  const personal = ['weight_loss_general', 'low_carb', 'keto_general', 'muscle_gain', 'cutting_gym', 'carb_cycle'];

  test('كل نظام شخصي فيه ≥8 خيارات لكل وقت وبتغذية مقدَّرة كاملة', () {
    for (final id in personal) {
      final p = load(id);
      for (final s in p.slots) {
        expect(s.options.length, greaterThanOrEqualTo(8), reason: '$id/${s.id}');
        for (final o in s.options) {
          expect(optionNutri(p, o).missing, 0, reason: '$id/${o.id}');
        }
      }
    }
  });

  test('الأسبوع المتوازن: أيامه متقاربة بالسعرات، بلا وجبة مكررة أكثر من مرتين ولا متتالية', () {
    final rnd = Random(7);
    for (final id in personal.where((x) => x != 'carb_cycle')) {
      final p = load(id);
      var good = 0;
      const runs = 20;
      for (var r = 0; r < runs; r++) {
        final picks = pickBalancedWeek(p, random: rnd);
        final days = List<double>.filled(7, 0);
        for (final k in picks) {
          days[k.day] += optionNutri(p, k.option).total.kcal;
        }
        final mean = days.reduce((a, b) => a + b) / 7;
        if (days.every((d) => (d - mean).abs() / mean <= .15)) good++;
        for (final s in p.slots) {
          final ids = [for (final k in picks.where((k) => k.slotId == s.id)) k.option.id];
          for (final o in ids.toSet()) {
            expect(ids.where((x) => x == o).length, lessThanOrEqualTo(2), reason: '$id/${s.id}/$o');
          }
          for (var d = 1; d < 7; d++) {
            expect(ids[d] == ids[d - 1], isFalse, reason: '$id متتالية');
          }
        }
      }
      // ignore: avoid_print
      print('$id: أسابيع ضمن ±15%: $good/$runs');
      expect(good, greaterThanOrEqualTo(runs * 0.8), reason: id);
    }
  });
}
