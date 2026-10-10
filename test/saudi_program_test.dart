import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/data/models.dart';
import 'package:sufrati/logic/planner.dart';

Program load() {
  final j = jsonDecode(File('assets/data/programs/saudi_family.json').readAsStringSync()) as Map<String, dynamic>;
  final meta = ProgramMeta({'id': 'saudi_family', 'label': 'المطبخ السعودي للأسرة', 'icon': '🍛', 'blurb': '', 'status': 'active', 'category': 'family'});
  return Program(meta, j);
}

void main() {
  test('النظام السعودي: بنية سليمة (مكوّنات معرّفة، وصفات، تذكيرات، فيديو وبرومبت صورة لكل وجبة)', () {
    final p = load();
    expect(p.slots.map((s) => s.name), ['الفطور', 'الغداء', 'جلسة المغرب', 'العشاء']);
    for (final s in p.slots) {
      for (final o in s.options) {
        expect(o.items, isNotEmpty, reason: o.id);
        for (final (k, q) in o.items) {
          expect(p.ingredients.containsKey(k), isTrue, reason: '${o.id} يستعمل $k');
          expect(q, greaterThan(0));
        }
        if (o.recipe != null) expect(p.recipes[o.recipe], isNotNull, reason: o.id);
        expect(o.photoPrompt, isNotEmpty, reason: '${o.id} بلا برومبت صورة');
        for (final r in o.remind) {
          expect(r.hoursBefore, greaterThan(0));
          expect(r.text, isNotEmpty);
        }
      }
    }
    final kabsa = p.slots[1].options.firstWhere((o) => o.id == 's2o1');
    expect(kabsa.remind.map((r) => r.hoursBefore), containsAll([14, 1.5, 2]));
    expect(kabsa.videoUrl.toString(), startsWith('https://www.tiktok.com/search?q='));
    expect(p.mealLinks['meal3']!.prayer, 'Maghrib');
    expect(p.ingredients.values.every((i) => i.category.isNotEmpty), isTrue);
  });

  test('الأسبوع بلا تكرار مزعج: الكبسة ≤3، سمك مرة على الأقل، ولا وجبة نفسها يومين متتاليين', () {
    final p = load();
    for (var seed = 0; seed < 150; seed++) {
      final picks = pickWeekOptions(p, random: Random(seed));
      int count(String tag) => picks.where((x) => x.option.tags.contains(tag)).length;
      expect(count('kabsa'), lessThanOrEqualTo(3), reason: 'seed $seed');
      expect(count('fish'), greaterThanOrEqualTo(1), reason: 'seed $seed');
      for (final slot in p.slots) {
        final ids = [for (final x in picks.where((x) => x.slotId == slot.id)) x.option.id];
        for (var i = 1; i < ids.length; i++) {
          expect(ids[i], isNot(ids[i - 1]), reason: '${slot.id} seed $seed');
        }
      }
    }
  });

  test('الأسبوع الجديد لا يكرر غداء الأسبوع الماضي حرفياً', () {
    final p = load();
    for (var seed = 0; seed < 60; seed++) {
      final w1 = pickWeekOptions(p, random: Random(seed));
      final avoid = <String, Set<String>>{};
      for (final x in w1) {
        (avoid[x.slotId] ??= {}).add(x.option.id);
      }
      final w2 = pickWeekOptions(p, random: Random(seed + 1000), avoid: avoid);
      final lunch1 = {for (final x in w1.where((x) => x.slotId == 'meal2')) x.option.id};
      final lunch2 = [for (final x in w2.where((x) => x.slotId == 'meal2')) x.option.id];
      // قد يفرض الحد الأدنى للسمك استبدالاً واحداً؛ لكن التداخل يبقى نادراً جداً
      expect(lunch2.where(lunch1.contains).length, lessThanOrEqualTo(1), reason: 'seed $seed');
    }
  });
}
