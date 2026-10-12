import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/data/models.dart';
import 'package:sufrati/logic/calories.dart';

Program load(String id) => Program(
    ProgramMeta({'id': id, 'label': id, 'icon': '', 'blurb': '', 'status': 'active', 'category': ''}),
    jsonDecode(File('assets/data/programs/$id.json').readAsStringSync()));

void main() {
  test('Mifflin-St Jeor: رجل 30 سنة 180سم 80كجم', () {
    const p = Profile(sex: Sex.male, age: 30, heightCm: 180, weightKg: 80, activity: Activity.sedentary);
    expect(bmr(p).round(), 1780);
    expect(planFor(p)!.kcal, 2150); // 1780×1.2=2136 → 2150
  });

  test('تنحيف: عجز آمن وحدّ أدنى وزمن الوصول', () {
    const p = Profile(sex: Sex.female, age: 35, heightCm: 160, weightKg: 85, activity: Activity.light, goalKg: 70, paceKgWeek: 0.5);
    final pl = planFor(p)!;
    expect(pl.kcal, lessThan(pl.tdee));
    expect(pl.kcal, greaterThanOrEqualTo(1200));
    expect(pl.weeks, inInclusiveRange(25, 40)); // 15 كجم بنحو 0.5 كجم/أسبوع
    expect(pl.proteinG, closeTo(170, 1));
  });

  test('حدّ أدنى للسعرات ولا حساب للقاصر والحالات الخاصة', () {
    const small = Profile(sex: Sex.female, age: 50, heightCm: 150, weightKg: 50, activity: Activity.sedentary, goalKg: 45, paceKgWeek: 1);
    expect(planFor(small)!.kcal, greaterThanOrEqualTo(1200));
    expect(planFor(const Profile(sex: Sex.male, age: 16, heightCm: 170, weightKg: 70, activity: Activity.light, goalKg: 60)), isNull);
    expect(planFor(const Profile(sex: Sex.female, age: 30, heightCm: 165, weightKg: 70, activity: Activity.light, goalKg: 60, needsSpecialist: true)), isNull);
    expect(planFor(const Profile(sex: Sex.male, age: 30, heightCm: 17, weightKg: 70, activity: Activity.light)), isNull);
  });

  test('كل مكوّنات برنامجي الأسرة والتنحيف لها تقدير غذائي', () {
    for (final id in ['saudi_family', 'weight_loss_general', 'muscle_gain', 'cutting_gym', 'kidney_salama']) {
      final prog = load(id);
      for (final s in prog.slots) {
        for (final o in s.options) {
          expect(optionNutri(prog, o).missing, 0, reason: '$id/${o.id}');
        }
      }
    }
  });

  test('يوم التنحيف معقول والحصة تقترب من الهدف', () {
    final prog = load('weight_loss_general');
    final day = avgDayNutri(prog).kcal;
    // ignore: avoid_print
    print('weight_loss avg day: ${day.round()} kcal; saudi: ${avgDayNutri(load('saudi_family')).kcal.round()}');
    expect(day, inInclusiveRange(1000, 2600));
    final por = portionFor(prog, 1600);
    expect(por, inInclusiveRange(0.6, 1.5));
    expect((day * por - 1600).abs() < 15 || por == 0.6 || por == 1.5, isTrue); // الحصة مقرَّبة لخانتين
  });
  test('بناء العضل: فائض فوق الاحتياج وبروتين 1.8 وزمن الوصول، والتنشيف بروتين 2.2', () {
    const g = Profile(sex: Sex.male, age: 25, heightCm: 178, weightKg: 70, activity: Activity.moderate, goalKg: 75, mode: Mode.gain);
    final pl = planFor(g)!;
    expect(pl.kcal, greaterThan(pl.tdee));
    expect(pl.kcal - pl.tdee, lessThan(pl.tdee * 0.12));
    expect(pl.proteinG, closeTo(126, 1));
    expect(pl.weeks, inInclusiveRange(15, 40));
    const noGoal = Profile(sex: Sex.male, age: 25, heightCm: 178, weightKg: 70, activity: Activity.moderate, mode: Mode.gain);
    expect(planFor(noGoal)!.weeks, isNull);
    const c = Profile(sex: Sex.male, age: 30, heightCm: 180, weightKg: 90, activity: Activity.high, goalKg: 82, mode: Mode.cut);
    final pc = planFor(c)!;
    expect(pc.kcal, lessThan(pc.tdee));
    expect(pc.proteinG, closeTo(198, 1));
  });
}
