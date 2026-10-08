import '../data/household.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'planner.dart';
import 'prayer.dart';

class SlotView {
  final MealSlot slot;
  final MealOption? option;
  final String time;
  final bool prepared;
  SlotView(this.slot, this.option, this.time, this.prepared);
}

class DayView {
  final DateTime date, weekStart;
  final int dayIndex;
  final List<SlotView> slots;
  DayView(this.date, this.weekStart, this.dayIndex, this.slots);
}

/// يوم كامل للعرض: خيار كل وجبة + وقتها (من الصلاة) + «جاهز».
Future<DayView> dayView(HouseholdStore store, Program program, DateTime date) async {
  final ws = weekStartFor(date);
  final idx = DateTime(date.year, date.month, date.day).difference(ws).inDays;
  final WeekPlan plan = await store.week(ws);
  final times = resolveMealTimes(date, store.household.city, store.household.mealLinks);
  return DayView(date, ws, idx, [
    for (final slot in program.slots)
      SlotView(
        slot,
        slot.options.where((o) => o.id == plan.days[idx][slot.id]).firstOrNull,
        times[slot.id] ?? slot.defaultTime,
        plan.isPrepared(idx, slot.id),
      ),
  ]);
}

/// الوقت المحلي في السعودية (UTC+3) مهما كان توقيت الجهاز.
DateTime saudiNow() => DateTime.now().toUtc().add(const Duration(hours: 3));
