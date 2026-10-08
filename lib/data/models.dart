// نماذج الأنظمة الغذائية — تُقرأ من assets/data (مُصدَّرة آلياً من maeda بـ tools/export_programs.py).

/// كمية: رقم صحيح أو كسر نصي "1/2" (الكسور تبقى دقيقة كما في بايثون Fraction).
double parseQty(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String && v.contains('/')) {
    final p = v.split('/');
    return double.parse(p[0]) / double.parse(p[1]);
  }
  return double.parse('$v');
}

class Ingredient {
  final String key, label, icon, unit, buyUnit;
  final double buyQty, buyPrice;
  Ingredient(this.key, Map<String, dynamic> j)
      : label = j['label'] ?? key,
        icon = j['icon'] ?? '•',
        unit = j['unit'] ?? '',
        buyUnit = j['buy_unit'] ?? '',
        buyQty = parseQty(j['buy_qty'] ?? 1),
        buyPrice = parseQty(j['buy_price'] ?? 0);
}

class MealOption {
  final String id, label;
  final List<String> tags;
  final List<(String, double)> items;
  final String? recipe, dayType;
  MealOption(Map<String, dynamic> j)
      : id = j['id'],
        label = j['label'],
        tags = List<String>.from(j['tags'] ?? const []),
        items = [for (final it in (j['items'] as List? ?? const [])) (it[0] as String, parseQty(it[1]))],
        recipe = j['recipe'],
        dayType = j['day_type'];
}

class MealSlot {
  final String id, name, icon, defaultTime;
  final List<MealOption> options;
  MealSlot(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        icon = j['icon'] ?? '🍽️',
        defaultTime = j['default_time'] ?? '',
        options = [for (final o in j['options'] as List) MealOption(o)];
}

class WeeklyLimit {
  final int? maxMeals, minMeals;
  WeeklyLimit(Map<String, dynamic> j)
      : maxMeals = j['max_meals'],
        minMeals = j['min_meals'];
}

class ProgramMeta {
  final String id, label, icon, blurb, status, category;
  ProgramMeta(Map<String, dynamic> j)
      : id = j['id'],
        label = j['label'],
        icon = j['icon'],
        blurb = j['blurb'],
        status = j['status'],
        category = j['category'];
  bool get active => status == 'active';
}

class Program {
  final ProgramMeta meta;
  final List<MealSlot> slots;
  final Map<String, Ingredient> ingredients;
  final Map<String, dynamic> recipes;
  final Map<String, WeeklyLimit> limits;
  final List<String>? dayTypePattern;
  final List<Map<String, dynamic>> cookInstructions, userTips, cookTips;

  Program(this.meta, Map<String, dynamic> j)
      : slots = [for (final s in j['MEAL_SLOTS'] as List) MealSlot(s)],
        ingredients = {
          for (final e in (j['INGREDIENTS'] as Map<String, dynamic>).entries) e.key: Ingredient(e.key, e.value)
        },
        recipes = Map<String, dynamic>.from(j['RECIPES'] ?? const {}),
        limits = {
          for (final e in (j['WEEKLY_LIMITS'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: WeeklyLimit(e.value)
        },
        dayTypePattern = (j['DAY_TYPE_PATTERN'] as List?)?.cast<String>(),
        cookInstructions = _maps(j['COOK_INSTRUCTIONS']),
        userTips = _maps(j['USER_TIPS']),
        cookTips = _maps(j['COOK_TIPS']);

  static List<Map<String, dynamic>> _maps(Object? v) =>
      v is List ? [for (final x in v) Map<String, dynamic>.from(x)] : const [];
}
