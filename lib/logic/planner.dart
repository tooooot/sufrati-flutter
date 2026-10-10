// منطق الخطة الأسبوعية — نقل حرفي لـ maeda/app/planner.py (لا تغيير في القواعد).
import 'dart:math';

import '../data/models.dart';

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

List<ScaledItem> scaledItems(MealOption? option, int eaters, Map<String, Ingredient> ingredients) {
  if (option == null) return const [];
  return [
    for (final (key, qty) in option.items)
      ScaledItem(key, ingredients[key]!.icon, ingredients[key]!.label, ingredients[key]!.unit,
          formatQty(qty * eaters)),
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
List<Pick> pickWeekOptions(Program program, {Random? random, Map<String, Set<String>>? avoid}) {
  final rnd = random ?? Random();
  final pattern = program.dayTypePattern;
  final tagCounts = {for (final t in program.limits.keys) t: 0};
  final last = <String, String?>{for (final s in program.slots) s.id: null};
  final picks = <Pick>[];

  for (var day = 0; day < 7; day++) {
    final dayType = pattern?[day];
    for (final slot in program.slots) {
      final options = [...slot.options]..shuffle(rnd);
      bool ok(MealOption o) {
        for (final tag in o.tags) {
          final limit = program.limits[tag]?.maxMeals;
          if (limit != null && tagCounts[tag]! >= limit) return false;
        }
        if (dayType != null && o.dayType != null && o.dayType != dayType) return false;
        return true;
      }

      var candidates = options.where((o) => ok(o) && o.id != last[slot.id] && !(avoid?[slot.id]?.contains(o.id) ?? false)).toList();
      if (candidates.isEmpty) candidates = options.where((o) => ok(o) && o.id != last[slot.id]).toList();
      if (candidates.isEmpty) candidates = options.where(ok).toList();
      if (candidates.isEmpty) candidates = options;
      final chosen = candidates[rnd.nextInt(candidates.length)];
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
