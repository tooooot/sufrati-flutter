// طبقة التخزين: الشاشات تتعامل مع HouseholdStore فقط. المعاينة تستخدم LocalStore (بيت تجريبي في الذاكرة)،
// والمرحلة 2 تضيف FirestoreStore بنفس الواجهة — لا تتغير الشاشات.
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../logic/planner.dart';
import '../logic/shopping.dart';
import 'household.dart';
import 'models.dart';
import 'repository.dart';

abstract class HouseholdStore extends ChangeNotifier {
  Household get household;
  Future<Program> program();
  Future<WeekPlan> week(DateTime weekStart);
  Future<void> setOption(DateTime weekStart, int day, String slot, String optionId);
  Future<void> setPrepared(DateTime weekStart, int day, String slot, bool value);
  Future<List<ShoppingLine>> shopping(DateTime weekStart);
  Future<void> updateShopping(DateTime weekStart, String key, {int? packs, bool? bought});
}

class LocalStore extends HouseholdStore {
  final Library library;
  @override
  final Household household;
  final _weeks = <DateTime, WeekPlan>{};
  final _shopping = <DateTime, List<ShoppingLine>>{};
  final Random _rnd;

  LocalStore(this.library, this.household, {int? seed}) : _rnd = Random(seed);

  @override
  Future<Program> program() => library.program(household.programId);

  @override
  Future<WeekPlan> week(DateTime weekStart) async {
    final hit = _weeks[weekStart];
    if (hit != null) return hit;
    final p = await program();
    final picks = pickWeekOptions(p, random: _rnd);
    final days = List.generate(7, (_) => <String, String>{});
    for (final pick in picks) {
      days[pick.day][pick.slotId] = pick.option.id;
    }
    return _weeks[weekStart] = WeekPlan(weekStart, days);
  }

  @override
  Future<void> setOption(DateTime weekStart, int day, String slot, String optionId) async {
    (await week(weekStart)).days[day][slot] = optionId;
    _shopping.remove(weekStart); // يُعاد حسابها مع الحفاظ على تعديلات المستخدم
    await shopping(weekStart);
    notifyListeners();
  }

  @override
  Future<void> setPrepared(DateTime weekStart, int day, String slot, bool value) async {
    final w = await week(weekStart);
    value ? w.prepared.add('$day:$slot') : w.prepared.remove('$day:$slot');
    notifyListeners();
  }

  final _previousShopping = <DateTime, List<ShoppingLine>>{};

  @override
  Future<List<ShoppingLine>> shopping(DateTime weekStart) async {
    final hit = _shopping[weekStart];
    if (hit != null) return hit;
    final lines = buildShopping(await program(), await week(weekStart), household.eaters,
        previous: _previousShopping[weekStart]);
    _previousShopping[weekStart] = lines;
    return _shopping[weekStart] = lines;
  }

  @override
  Future<void> updateShopping(DateTime weekStart, String key, {int? packs, bool? bought}) async {
    final line = (await shopping(weekStart)).where((l) => l.key == key).firstOrNull;
    if (line == null) return;
    if (packs != null) line.packs = packs;
    if (bought != null) line.bought = bought;
    notifyListeners();
  }
}
