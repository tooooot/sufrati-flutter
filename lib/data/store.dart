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

  /// نظام المكتبة كما هو (بلا وجبات البيت الخاصة).
  Future<Program> baseProgram();

  Program? _eff;
  int _effSig = -1;

  /// النظام الفعلي لهذا البيت = نظام المكتبة + وجباته الخاصة.
  Future<Program> program() async {
    final base = await baseProgram();
    final sig = Object.hashAll([for (final c in household.custom) c['id']]);
    if (_eff == null || _effSig != sig || !identical(_eff!.meta, base.meta)) {
      _eff = base.withCustom(household.custom);
      _effSig = sig;
    }
    return _eff!;
  }

  Future<WeekPlan> week(DateTime weekStart);
  Future<void> setOption(DateTime weekStart, int day, String slot, String optionId);
  Future<void> setPrepared(DateTime weekStart, int day, String slot, bool value);
  Future<List<ShoppingLine>> shopping(DateTime weekStart);
  Future<void> updateShopping(DateTime weekStart, String key, {int? packs, bool? bought});

  /// يحفظ حقولاً على وثيقة البيت (Firestore) — محلياً لا شيء.
  Future<void> persistHousehold(Map<String, Object?> fields);

  /// يعيد حساب مشتريات الأسبوعين المعروضين مع إبقاء ما اشتُري (بعد تغيير العدد/الحصة/المخزن).
  Future<void> reflowShopping();

  /// يعيد بناء خطة أسبوع بقرعة جديدة تحترم المخفي والمفضلة وتتجنب تكرار الماضي.
  Future<void> regenerateWeek(DateTime weekStart);

  /// رابط مشتريات للمتسوّق (الزوج/السائق) يُفتح بلا تسجيل ويعلّم «اشتريتُ». null ← غير مدعوم (محلي).
  Future<String?> createShopLink(DateTime weekStart) async => null;

  /// يجلب ما علّمه المتسوّق «اشتُري» من الرابط ويدمجه في القائمة.
  Future<void> syncShopLink(DateTime weekStart) async {}

  Set<String> pantryOf(Program p) => household.pantry ?? p.pantryDefaults;

  Future<void> _household(Map<String, Object?> fields, {bool reflow = false}) async {
    notifyListeners();
    await persistHousehold(fields);
    if (reflow) await reflowShopping();
    notifyListeners();
  }

  /// عدد من يأكل (الكبار والأطفال معاً): الكميات والمشتريات تتغير فوراً.
  Future<void> setEaters(int n) {
    household.eaters = n.clamp(1, 20);
    if (household.kids > household.eaters) household.kids = household.eaters;
    return _household({'eaters': household.eaters, 'kids': household.kids}, reflow: true);
  }

  /// كم من الآكلين أطفال (نصف حصة).
  Future<void> setKids(int n) {
    household.kids = n.clamp(0, household.eaters);
    return _household({'kids': household.kids}, reflow: true);
  }

  /// حجم الحصة: صغيرة 0.8 · عادية 1 · كبيرة 1.3 (ضبط الأسرة لتقديراتنا).
  Future<void> setPortion(double p) {
    household.portion = p;
    return _household({'portion': p}, reflow: true);
  }

  /// هدف السعرات (وبياناته) بعد تعديل صاحبه أو الأخصائي؛ [portion] الحصة المعايَرة الجديدة.
  Future<void> setTarget(Map<String, dynamic> target, {double? portion, Map<String, dynamic>? profile}) {
    household.target = target;
    if (portion != null) household.portion = portion;
    if (profile != null) household.profile = profile;
    return _household({'target': target, 'portion': ?portion, 'profile': ?profile}, reflow: portion != null);
  }

  /// «عندي في البيت»: لا يدخل المشتريات.
  Future<void> setPantry(String key, bool atHome) async {
    final cur = {...pantryOf(await program())};
    atHome ? cur.add(key) : cur.remove(key);
    household.pantry = cur;
    await _household({'pantry': cur.toList()}, reflow: true);
  }

  Future<void> toggleHidden(String optionId) {
    household.hidden.contains(optionId) ? household.hidden.remove(optionId) : household.hidden.add(optionId);
    if (household.hidden.contains(optionId)) household.favorites.remove(optionId);
    return _household({'hidden': household.hidden.toList(), 'favorites': household.favorites.toList()});
  }

  Future<void> toggleFavorite(String optionId) {
    household.favorites.contains(optionId) ? household.favorites.remove(optionId) : household.favorites.add(optionId);
    household.hidden.remove(optionId);
    return _household({'hidden': household.hidden.toList(), 'favorites': household.favorites.toList()});
  }

  /// وجبة خاصة من عندها: اسم + وجبة + مكوّنات اختيارية (كمية الفرد 1 لكل مكوّن). تُخزَّن المكوّنات كخرائط (Firestore لا يقبل مصفوفات متداخلة).
  Future<void> addCustom({required String slotId, required String label, List<String> ingredientKeys = const []}) {
    household.custom.add({
      'id': 'c_${DateTime.now().millisecondsSinceEpoch}', 'slot': slotId, 'label': label.trim(),
      'items': [for (final k in ingredientKeys) {'k': k, 'q': 1}],
    });
    return _household({'custom': household.custom});
  }

  Future<void> removeCustom(String optionId) {
    household.custom.removeWhere((c) => c['id'] == optionId);
    household.hidden.remove(optionId);
    household.favorites.remove(optionId);
    return _household({'custom': household.custom, 'hidden': household.hidden.toList(), 'favorites': household.favorites.toList()});
  }

  /// «غيّريها»: بديل عشوائي لوجبة واحدة (من غير المخفي ولا الحالي).
  Future<void> replaceMeal(DateTime weekStart, int day, String slotId) async {
    final p = await program();
    final slot = p.slots.firstWhere((s) => s.id == slotId);
    final cur = (await week(weekStart)).days[day][slotId];
    final pool = slot.options.where((o) => o.id != cur && !household.hidden.contains(o.id)).toList();
    if (pool.isEmpty) return;
    final weighted = [...pool, ...pool.where((o) => household.favorites.contains(o.id))];
    await setOption(weekStart, day, slotId, weighted[Random().nextInt(weighted.length)].id);
  }
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
  Future<Program> baseProgram() => library.program(household.programId);

  @override
  Future<void> persistHousehold(Map<String, Object?> fields) async {}

  @override
  Future<void> reflowShopping() async => _shopping.clear();

  @override
  Future<void> regenerateWeek(DateTime weekStart) async {
    _weeks.remove(weekStart);
    _shopping.remove(weekStart);
    await week(weekStart);
  }

  @override
  Future<WeekPlan> week(DateTime weekStart) async {
    final hit = _weeks[weekStart];
    if (hit != null) return hit;
    final p = await program();
    final picks = pickWeekOptions(p, random: _rnd, hidden: household.hidden, favorites: household.favorites);
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
    final prog = await program();
    final lines = buildShopping(prog, await week(weekStart), household.servings,
        previous: _previousShopping[weekStart], pantry: pantryOf(prog));
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
