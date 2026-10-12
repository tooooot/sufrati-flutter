// منطق الخطة الأسبوعية — نقل حرفي لـ maeda/app/planner.py (لا تغيير في القواعد).
import 'dart:math';

import '../data/models.dart';
import 'calories.dart';

const _glyphs = {(1, 4): '¼', (1, 3): '⅓', (1, 2): '½', (2, 3): '⅔', (3, 4): '¾'};

/// أقرب كسر بمقام ≤ max (مثل Fraction.limit_denominator).
(int, int) _limitDenominator(double x, int max) {
  var best = (x.round(), 1);
  var bestErr = (x - best.$1).abs();
  for (var d = 2; d <= max; d++) {
    final n = (x * d).round();
    final err = (x - n / d).abs();
    if (err < bestErr - 1e-12) {
      best = (n, d);
      bestErr = err;
    }
  }
  final g = _gcd(best.$1.abs(), best.$2);
  return (best.$1 ~/ g, best.$2 ~/ g);
}

int _gcd(int a, int b) => b == 0 ? (a == 0 ? 1 : a) : _gcd(b, a % b);

/// 1½ بدل 1.5، ⅓ بدل 0.33 — نفس _format_qty.
String formatQty(double total) {
  var (n, d) = _limitDenominator(total, 12);
  var whole = n ~/ d;
  var rn = n - whole * d;
  if (rn == 0) return '$whole';
  final g = _gcd(rn, d);
  var glyph = _glyphs[(rn ~/ g, d ~/ g)];
  if (glyph == null) {
    var q = (rn / d * 4).round();
    whole += q ~/ 4;
    q %= 4;
    final gg = _gcd(q, 4);
    glyph = q == 0 ? '' : (_glyphs[(q ~/ gg, 4 ~/ gg)] ?? '');
  }
  return whole > 0 ? '$whole$glyph' : glyph;
}

class ScaledItem {
  final String key, icon, label, unit, qtyLabel;
  ScaledItem(this.key, this.icon, this.label, this.unit, this.qtyLabel);
}

List<ScaledItem> scaledItems(MealOption? option, double servings, Map<String, Ingredient> ingredients) {
  if (option == null) return const [];
  return [
    for (final (key, qty) in option.items)
      ScaledItem(key, ingredients[key]!.icon, ingredients[key]!.label, ingredients[key]!.unit,
          formatQty(qty * servings)),
  ];
}

/// الأسبوع يبدأ السبت (نمط سعودي).
DateTime weekStartFor(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  final offset = (day.weekday - DateTime.saturday) % 7;
  return day.subtract(Duration(days: offset));
}

class Pick {
  final int day;
  final String slotId;
  MealOption option;
  Pick(this.day, this.slotId, this.option);
}

/// خيار لكل وجبة × 7 أيام، مع الحدود الأسبوعية وتناوب نوع اليوم وعدم التكرار المتتالي — نفس _pick_week_options.
/// [avoid]: خيارات الأسبوع السابق لكل وجبة (slotId ← معرّفات) — تُستبعد ما دام فيه بديل، فلا يتكرر الأسبوع الجديد حرفياً.
/// [hidden]: وجبات تستبعدها الأسرة، [favorites]: تُضاعَف فرصتها في القرعة.
List<Pick> pickWeekOptions(Program program, {Random? random, Map<String, Set<String>>? avoid, Set<String> hidden = const {}, Set<String> favorites = const {}}) {
  final rnd = random ?? Random();
  final pattern = program.dayTypePattern;
  final tagCounts = {for (final t in program.limits.keys) t: 0};
  final last = <String, String?>{for (final s in program.slots) s.id: null};
  final picks = <Pick>[];
  final use = {for (final s in program.slots) s.id: <String, int>{}}; // كم مرة استُعمل كل خيار هذا الأسبوع

  for (var day = 0; day < 7; day++) {
    final dayType = pattern?[day];
    final dayMain = <String>{}; // المكوّنات الرئيسية المختارة اليوم
    for (final slot in program.slots) {
      var pool = slot.options.where((o) => !hidden.contains(o.id) && !o.isOut).toList();
      if (pool.isEmpty) pool = [...slot.options]; // لا نترك وجبة بلا خيارات مهما أخفت
      final options = [...pool, ...pool.where((o) => favorites.contains(o.id))]..shuffle(rnd); // المفضلة مرتان
      bool ok(MealOption o) {
        for (final tag in o.tags) {
          final limit = program.limits[tag]?.maxMeals;
          if (limit != null && tagCounts[tag]! >= limit) return false;
        }
        if (dayType != null && o.dayType != null && o.dayType != dayType) return false;
        return true;
      }

      // ترتيب بالنقاط (الأقل أفضل): استعمال هذا الأسبوع ثم «قُدِّم الأسبوع الماضي» (تفضيل لا شرط، وإلا لم يبقَ بديل مع ٨ خيارات)
      // ثم تكرار المكوّن الرئيسي في اليوم نفسه (زبادي في الفطور والسناك). المخالف للحدود أو المتتالي يُستبعد ما أمكن.
      double score(MealOption o) {
        var v = (use[slot.id]![o.id] ?? 0) * 2.0;
        if (avoid?[slot.id]?.contains(o.id) ?? false) v += 1.0;
        if (o.id == last[slot.id]) v += 100;
        if (!ok(o)) v += 1000;
        final main = o.items.isEmpty ? null : o.items.first.$1;
        if (main != null && dayMain.contains(main)) v += 0.6;
        if (favorites.contains(o.id)) v -= 0.3;
        return v;
      }
      final uniq = {for (final o in options) o.id: o}.values.toList();
      var best = double.infinity;
      var tied = <MealOption>[];
      for (final o in uniq) {
        final v = score(o);
        if (v < best - 1e-9) {
          best = v;
          tied = [o];
        } else if ((v - best).abs() < 1e-9) {
          tied.add(o);
        }
      }
      final chosen = tied[rnd.nextInt(tied.length)];
      use[slot.id]![chosen.id] = (use[slot.id]![chosen.id] ?? 0) + 1;
      if (chosen.items.isNotEmpty) dayMain.add(chosen.items.first.$1);
      last[slot.id] = chosen.id;
      for (final tag in chosen.tags) {
        if (tagCounts.containsKey(tag)) tagCounts[tag] = tagCounts[tag]! + 1;
      }
      picks.add(Pick(day, slot.id, chosen));
    }
  }

  // ضمان الحد الأدنى لأي وسم min_meals (سمك...) لو لم يتحقق عشوائياً
  for (final MapEntry(key: tag, value: rule) in program.limits.entries) {
    final minNeeded = rule.minMeals;
    if (minNeeded == null || minNeeded == 0) continue;
    final have = picks.where((p) => p.option.tags.contains(tag)).length;
    if (have >= minNeeded) continue;
    final host = program.slots.where((s) => s.options.any((o) => o.tags.contains(tag))).firstOrNull;
    if (host == null) continue;
    final tagged = host.options.where((o) => o.tags.contains(tag)).toList();
    final idxs = [for (var i = 0; i < picks.length; i++) if (picks[i].slotId == host.id) i]..shuffle(rnd);
    var need = minNeeded - have;
    for (final i in idxs) {
      if (need <= 0) break;
      final p = picks[i];
      if (p.option.tags.contains(tag)) continue;
      final dayType = pattern?[p.day];
      final okOpts = tagged.where((o) => dayType == null || o.dayType == null || o.dayType == dayType).toList();
      if (okOpts.isNotEmpty) {
        // نفضّل بديلاً لم يُقدَّم الأسبوع الماضي إن وُجد
        final fresh = okOpts.where((o) => !(avoid?[host.id]?.contains(o.id) ?? false)).toList();
        final pool = fresh.isNotEmpty ? fresh : okOpts;
        p.option = pool[rnd.nextInt(pool.length)];
        need--;
      }
    }
  }
  return picks;
}

/// أسبوع متوازن السعرات للخطة الشخصية: نولّد [tries] أسابيع قانونية (حدود/تنويع) ونختار الأقل تفاوتاً بين مجاميع الأيام،
/// فإذا عُوير حجم الحصة على متوسطها اقترب كل يوم من هدف السعرات (±10٪ غالباً).
List<Pick> pickBalancedWeek(Program program,
    {int tries = 300, Random? random, Map<String, Set<String>>? avoid, Set<String> hidden = const {}, Set<String> favorites = const {}}) {
  final rnd = random ?? Random();
  // كارب سايكل: تفاوت الأيام مقصود (منخفض/عالٍ) والهدف متوسط الأسبوع
  if (program.dayTypePattern != null) return pickWeekOptions(program, random: rnd, avoid: avoid, hidden: hidden, favorites: favorites);
  List<Pick>? best;
  var bestScore = double.infinity;
  for (var i = 0; i < tries; i++) {
    final picks = pickWeekOptions(program, random: rnd, avoid: avoid, hidden: hidden, favorites: favorites);
    final days = List<double>.filled(7, 0);
    for (final p in picks) {
      days[p.day] += optionNutri(program, p.option).total.kcal;
    }
    final mean = days.reduce((a, b) => a + b) / 7;
    if (mean <= 0) return picks; // بلا تغذية مقدَّرة: لا موازنة
    final score = days.map((d) => (d - mean).abs() / mean).reduce(max);
    if (score < bestScore) {
      bestScore = score;
      best = picks;
    }
  }
  return best!;
}

class PlannedSlot {
  final MealSlot slot;
  final MealOption option;
  PlannedSlot(this.slot, this.option);
}

class PlannedDay {
  final String name;
  final List<PlannedSlot> slots;
  PlannedDay(this.name, this.slots);
}

/// أسبوع تجريبي للمعاينة قبل التسجيل — نفس preview_week.
List<PlannedDay> previewWeek(Program program, List<String> dayNames, {Random? random}) {
  final picks = pickWeekOptions(program, random: random);
  return [
    for (var day = 0; day < 7; day++)
      PlannedDay(dayNames[day], [
        for (final slot in program.slots)
          PlannedSlot(slot, picks.firstWhere((p) => p.day == day && p.slotId == slot.id).option),
      ]),
  ];
}
