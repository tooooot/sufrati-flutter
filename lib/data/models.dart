// نماذج الأنظمة الغذائية — تُقرأ من assets/data (مُصدَّرة آلياً من maeda بـ tools/export_programs.py).

import '../logic/prayer.dart';
/// كمية: رقم صحيح أو كسر نصي "1/2" (الكسور تبقى دقيقة كما في بايثون Fraction).
double parseQty(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String && v.contains('/')) {
    final p = v.split('/');
    return double.parse(p[0]) / double.parse(p[1]);
  }
  return double.parse('$v');
}

/// تقديرات اعتمدها الأخصائي (تُحمَّل من Firestore عند الإقلاع) وتغلب تقديرات الملفات: المفتاح «البرنامج__المكوّن».
Map<String, Nutri> nutriOverrides = {};

class Ingredient {
  final String key, label, name, icon, unit, buyUnit, category;
  final double buyQty, buyPrice;
  /// تقدير غذائي لوحدة واحدة (سعرات، بروتين، كربوهيدرات، دهون). null إن لم يُقدَّر.
  final Nutri? nutri;
  Ingredient(this.key, Map<String, dynamic> j, {Nutri? override})
      : label = j['label'] ?? key,
        // اسم المنتج للمشتريات والمخزن (label قد تحمل وحدة الطبخ مثل «غرام لحم غنم»)
        name = j['name'] ?? j['label'] ?? key,
        icon = j['icon'] ?? '•',
        unit = j['unit'] ?? '',
        buyUnit = j['buy_unit'] ?? '',
        category = j['category'] ?? 'other',
        buyQty = parseQty(j['buy_qty'] ?? 1),
        buyPrice = parseQty(j['buy_price'] ?? 0),
        nutri = override ?? (j['kcal'] == null ? null : Nutri(parseQty(j['kcal']), parseQty(j['p'] ?? 0), parseQty(j['c'] ?? 0), parseQty(j['f'] ?? 0), reviewed: j['nutri'] == 'reviewed'));
}

class Nutri {
  final double kcal, p, c, f;
  final bool reviewed;
  const Nutri(this.kcal, this.p, this.c, this.f, {this.reviewed = false});
  Nutri operator *(double k) => Nutri(kcal * k, p * k, c * k, f * k, reviewed: reviewed);
  Nutri operator +(Nutri o) => Nutri(kcal + o.kcal, p + o.p, c + o.c, f + o.f, reviewed: reviewed && o.reviewed);
  static const zero = Nutri(0, 0, 0, 0, reviewed: true);
}

class MealOption {
  final String id, label;
  final List<String> tags;
  final List<(String, double)> items;
  final String? recipe, dayType, videoQ, photoPrompt;
  /// تذكيرات تحضير قبل الوجبة (فك الدجاج، نقع الأرز…): نص + كم ساعة قبل موعد الوجبة.
  final List<({String text, double hoursBefore})> remind;
  MealOption(Map<String, dynamic> j)
      : id = j['id'],
        label = j['label'],
        tags = List<String>.from(j['tags'] ?? const []),
        items = [for (final it in (j['items'] as List? ?? const [])) (it[0] as String, parseQty(it[1]))],
        recipe = j['recipe'],
        dayType = j['day_type'],
        videoQ = j['video_q'],
        photoPrompt = j['photo_prompt'],
        remind = [for (final r in (j['remind'] as List? ?? const [])) (text: r['text'] as String, hoursBefore: parseQty(r['hours_before']))];

  /// بحث تيك توك عن طريقة هذه الوجبة (رابط بحث دائم الصلاحية، لا رابط فيديو بعينه قد يُحذف).
  Uri? get videoUrl => videoQ == null ? null : Uri.https('www.tiktok.com', '/search', {'q': videoQ});
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
  /// ربط وجبات هذا النظام بالصلوات (يغلب الافتراضي العام): {'meal3': PrayerLink('Maghrib', 20)}.
  final Map<String, PrayerLink> mealLinks;
  /// مكوّنات يُفترض أنها في البيت (زيت، سكر، شاهي، بهارات…): لا تدخل المشتريات حتى تُلغي ربّة البيت ذلك.
  final Set<String> pantryDefaults;
  final Map<String, dynamic> raw;

  Program(this.meta, Map<String, dynamic> j)
      : raw = j,
        pantryDefaults = {...List<String>.from(j['PANTRY_DEFAULT'] ?? const [])},
        slots = [for (final s in j['MEAL_SLOTS'] as List) MealSlot(s)],
        ingredients = {
          for (final e in (j['INGREDIENTS'] as Map<String, dynamic>).entries) e.key: Ingredient(e.key, e.value, override: nutriOverrides['${meta.id}__${e.key}'])
        },
        recipes = Map<String, dynamic>.from(j['RECIPES'] ?? const {}),
        limits = {
          for (final e in (j['WEEKLY_LIMITS'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: WeeklyLimit(e.value)
        },
        dayTypePattern = (j['DAY_TYPE_PATTERN'] as List?)?.cast<String>(),
        cookInstructions = _maps(j['COOK_INSTRUCTIONS']),
        userTips = _maps(j['USER_TIPS']),
        cookTips = _maps(j['COOK_TIPS']),
        mealLinks = {
          for (final e in (j['MEAL_LINKS'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: PrayerLink(e.value['prayer'] as String, (e.value['offset'] as num).toInt())
        };

  /// نسخة من النظام بوجبات البيت الخاصة (custom: [{id, slot, label, items:[[key,qty]]}]) مضافة إلى وجبات النظام.
  Program withCustom(List<Map<String, dynamic>> custom) {
    if (custom.isEmpty) return this;
    final j = Map<String, dynamic>.from(raw);
    j['MEAL_SLOTS'] = [
      for (final s in raw['MEAL_SLOTS'] as List)
        {
          ...Map<String, dynamic>.from(s as Map),
          'options': [
            ...(s['options'] as List),
            for (final c in custom.where((c) => c['slot'] == s['id']))
              {
                'id': c['id'], 'label': c['label'], 'tags': const <String>[],
                // Firestore يخزّن المكوّنات خرائط {k,q}؛ نحوّلها لأزواج [مفتاح، كمية] كبقية الوجبات (والمجهول يُهمَل)
                'items': [
                  for (final it in (c['items'] as List? ?? const []))
                    if (it is Map && (raw['INGREDIENTS'] as Map).containsKey(it['k'])) [it['k'], it['q']] else if (it is List) it,
                ],
              },
          ],
        }
    ];
    return Program(meta, j);
  }

  static List<Map<String, dynamic>> _maps(Object? v) =>
      v is List ? [for (final x in v) Map<String, dynamic>.from(x)] : const [];
}
