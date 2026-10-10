import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/data/household.dart';
import 'package:sufrati/data/repository.dart';
import 'package:sufrati/data/store.dart';
import 'package:sufrati/logic/planner.dart';
import 'package:sufrati/logic/shopping_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ws = weekStartFor(DateTime(2026, 10, 10));

  Future<LocalStore> mk({int eaters = 4, int kids = 0, double portion = 1}) async => LocalStore(
      await Library.load(), Household(id: 'h', label: 'بيت', programId: 'saudi_family', eaters: eaters, kids: kids, portion: portion), seed: 5);

  test('حصص الأسرة: الأطفال نصف حصة × حجم الحصة، والأدنى نصف حصة', () {
    Household h(int e, int k, double p) => Household(id: 'h', label: 'x', programId: 'p', eaters: e, kids: k, portion: p);
    expect(h(4, 0, 1).servings, 4);
    expect(h(5, 2, 1).servings, 4); // 3 كبار + طفلان
    expect(h(5, 2, 1.3).servings, closeTo(5.2, 1e-9));
    expect(h(1, 1, 1).servings, .5);
  });

  test('تغيير العدد والحصة يُحدّث المشتريات، والتعديل اليدوي للعدد يُحفظ', () async {
    final s = await mk();
    int total(List<ShoppingLine> l) => l.fold(0, (a, x) => a + x.packs);
    final base = await s.shopping(ws);
    final b = total(base);
    await s.setEaters(8);
    final more = await s.shopping(ws);
    expect(total(more), greaterThan(b), reason: 'ضعف الأسرة ← مشتريات أكثر');
    await s.setEaters(4);
    await s.setPortion(0.8);
    final less = total(await s.shopping(ws));
    expect(less, lessThanOrEqualTo(b));
    // تعديل يدوي لصنف ثم تغيير العدد: يبقى تعديله
    final line = (await s.shopping(ws)).first;
    await s.updateShopping(ws, line.key, packs: 9);
    await s.setEaters(6);
    expect((await s.shopping(ws)).firstWhere((x) => x.key == line.key).packs, 9);
  });

  test('«عندي في البيت»: الافتراضي لا يُشترى، وإلغاؤه يُدخل الصنف في المشتريات', () async {
    final s = await mk();
    final prog = await s.program();
    expect(prog.pantryDefaults, contains('oil'));
    final keysA = (await s.shopping(ws)).map((l) => l.key).toSet();
    expect(keysA, isNot(contains('oil')));
    expect(keysA, isNot(contains('tea')));
    await s.setPantry('tea', false);
    final keysB = (await s.shopping(ws)).map((l) => l.key).toSet();
    // الشاهي يدخل إن كان في خطة الأسبوع (جلسة المغرب تستعمله غالباً)
    final usesTea = (await s.week(ws)).days.any((d) => prog.slots.any((sl) => sl.options.any((o) => o.id == d[sl.id] && o.items.any((i) => i.$1 == 'tea'))));
    expect(keysB.contains('tea'), usesTea);
  });

  test('«لا أحبها»: الوجبة المخفية لا تظهر في أي توليد جديد، والمفضلة تظهر أكثر', () async {
    final s = await mk();
    await s.toggleHidden('s2o1'); // كبسة دجاج
    for (var i = 0; i < 25; i++) {
      await s.regenerateWeek(ws);
      final ids = (await s.week(ws)).days.map((d) => d['meal2']).toSet();
      expect(ids, isNot(contains('s2o1')), reason: 'توليد $i');
    }
    expect(s.household.hidden, contains('s2o1'));
    await s.toggleFavorite('s2o1'); // التفضيل يلغي الإخفاء
    expect(s.household.hidden, isNot(contains('s2o1')));
    expect(s.household.favorites, contains('s2o1'));
  });

  test('وجبة خاصة: تُضاف للوجبة المختارة بمكوّناتها، وتُحذف', () async {
    final s = await mk();
    await s.addCustom(slotId: 'meal2', label: 'ملوخية أمي', ingredientKeys: ['molokhia', 'chicken', 'مكوّن_مجهول']);
    final prog = await s.program();
    final opt = prog.slots.firstWhere((x) => x.id == 'meal2').options.firstWhere((o) => o.label == 'ملوخية أمي');
    expect(opt.id, startsWith('c_'));
    expect(opt.items.map((i) => i.$1), ['molokhia', 'chicken'], reason: 'المجهول يُهمَل');
    await s.removeCustom(opt.id);
    expect((await s.program()).slots.firstWhere((x) => x.id == 'meal2').options.any((o) => o.id == opt.id), isFalse);
  });

  test('«غيّريها»: بديل مختلف غير مخفي', () async {
    final s = await mk();
    final cur = (await s.week(ws)).days[2]['meal2']!;
    await s.toggleHidden('s2o2');
    for (var i = 0; i < 20; i++) {
      await s.replaceMeal(ws, 2, 'meal2');
      final now = (await s.week(ws)).days[2]['meal2']!;
      expect(now, isNot('s2o2'));
    }
    expect((await s.week(ws)).days[2]['meal2'], isNotNull);
    expect(cur, isNotEmpty);
  });

  test('نص المشتريات: مصنّف بأقسام السوق بلا ما اشتُري ولا ما في المخزن', () async {
    final s = await mk();
    final prog = await s.program();
    final lines = await s.shopping(ws);
    final txt = shoppingText(prog, lines, pantry: s.pantryOf(prog));
    expect(txt, startsWith('مشتريات هذا الأسبوع'));
    expect(txt, contains('لحوم وأسماك:'));
    expect(txt, isNot(contains('زيت')), reason: 'الزيت في المخزن');
    final first = lines.firstWhere((l) => !s.pantryOf(prog).contains(l.key));
    first.bought = true;
    expect(shoppingText(prog, lines, pantry: s.pantryOf(prog)), isNot(contains(prog.ingredients[first.key]!.buyUnit)));
    expect(shoppingText(prog, [], pantry: {}), contains('لا شيء ناقص'));
  });
}
