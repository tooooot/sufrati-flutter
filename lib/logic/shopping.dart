// قائمة المشتريات — نفس build_shopping_list: مجموع كل مكوّن × عدد الآكلين ← عدد عبوات الشراء (تقريب لأعلى)،
// مع الحفاظ على تعديلات المستخدم السابقة (العدد/السعر/تم الشراء).
import '../data/household.dart';
import '../data/models.dart';

/// [pantry]: مكوّنات في البيت فلا تُشترى. [servings]: حصص الأسرة (كبار + نصف الأطفال × حجم الحصة).
List<ShoppingLine> buildShopping(Program program, WeekPlan plan, double servings, {List<ShoppingLine>? previous, Set<String> pantry = const {}}) {
  final totals = <String, double>{};
  for (final day in plan.days) {
    for (final MapEntry(key: slotId, value: optionId) in day.entries) {
      final slot = program.slots.where((s) => s.id == slotId).firstOrNull;
      final opt = slot?.options.where((o) => o.id == optionId).firstOrNull;
      if (opt == null) continue;
      for (final (key, qty) in opt.items) {
        if (pantry.contains(key)) continue;
        totals[key] = (totals[key] ?? 0) + qty * servings;
      }
    }
  }
  final prev = {for (final l in previous ?? const <ShoppingLine>[]) l.key: l};
  final keys = totals.keys.toList()..sort();
  return [
    for (final key in keys)
      () {
        final ing = program.ingredients[key]!;
        final computed = (totals[key]! / ing.buyQty).ceil().clamp(1, 1 << 30);
        final p = prev[key];
        if (p == null) return ShoppingLine(key, computed, ing.buyPrice, false, computed);
        // عدّلها المستخدم يدوياً (packs ≠ المحسوب سابقاً) ← نحفظ تعديله؛ وإلا نحدّثها مع الخطة والعدد والحصة
        final edited = p.auto != null && p.packs != p.auto;
        return ShoppingLine(key, edited ? p.packs : computed, p.unitPrice, p.bought, computed);
      }(),
  ];
}

/// الأسبوع مقفل بعد موعد القطع (اليوم رقم cutoffDay من السبت، الساعة cutoffTime) — نفس is_locked حرفياً.
bool isLocked(DateTime weekStart, DateTime now, int cutoffDay, String cutoffTime) {
  final thisWeek = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: (now.weekday - DateTime.saturday) % 7));
  if (weekStart.isBefore(thisWeek)) return true;
  if (weekStart.isAfter(thisWeek)) return false;
  final hm = cutoffTime.split(':').map(int.parse).toList();
  final cutoff = weekStart.add(Duration(days: cutoffDay, hours: hm[0], minutes: hm[1]));
  return !now.isBefore(cutoff);
}
