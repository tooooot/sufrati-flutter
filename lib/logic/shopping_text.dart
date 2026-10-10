// نص قائمة المشتريات للمشاركة (واتساب للزوج/السائق، أو نسخها لتطبيق توصيل مثل مرسول): مصنّفة بأقسام السوق، بلا ما اشتُري ولا ما في المخزن.
import '../data/household.dart';
import '../data/models.dart';

const shopCategories = {
  'meat': 'لحوم وأسماك',
  'dairy': 'ألبان وبيض',
  'veg': 'خضار',
  'fruit': 'فواكه',
  'grain': 'حبوب ونشويات ومخبوزات',
  'fat': 'دهون ومكسرات',
  'other': 'أخرى',
};

String shoppingText(Program program, List<ShoppingLine> lines, {Set<String> pantry = const {}, String? title}) {
  final todo = lines.where((l) => !l.bought && !pantry.contains(l.key) && l.packs > 0 && program.ingredients.containsKey(l.key)).toList();
  if (todo.isEmpty) return 'لا شيء ناقص هذا الأسبوع ✓';
  final b = StringBuffer(title ?? 'مشتريات هذا الأسبوع (من سفرتي):');
  for (final e in shopCategories.entries) {
    final items = todo.where((l) => program.ingredients[l.key]!.category == e.key).toList();
    if (items.isEmpty) continue;
    b.write('\n\n${e.value}:');
    for (final l in items) {
      final ing = program.ingredients[l.key]!;
      b.write('\n• ${ing.buyUnit}${l.packs > 1 ? ' × ${l.packs}' : ''}');
    }
  }
  return b.toString();
}

/// وثيقة رابط المشتريات للمتسوّق: نسخة مبسّطة (بلا أي بيانات عن البيت) + ما اشتُري مسبقاً. المكوّنات خرائط (Firestore لا يقبل مصفوفات متداخلة).
Map<String, Object?> shopLinkLines(Program program, List<ShoppingLine> lines, {Set<String> pantry = const {}}) {
  final todo = lines.where((l) => !pantry.contains(l.key) && l.packs > 0 && program.ingredients.containsKey(l.key)).toList();
  return {
    'lines': [
      for (final l in todo)
        {'k': l.key, 'label': program.ingredients[l.key]!.buyUnit, 'packs': l.packs, 'cat': program.ingredients[l.key]!.category,
          'icon': program.ingredients[l.key]!.icon},
    ],
    'bought': {for (final l in todo.where((l) => l.bought)) l.key: true},
  };
}
