// بيانات البيت — شكل واحد للتخزين المحلي (المعاينة) ولـFirestore (المرحلة 2).
import '../logic/prayer.dart';

class Household {
  String id, label, programId, cookName, city;
  int eaters, cutoffDay;
  String cutoffTime;
  Map<String, PrayerLink> mealLinks;
  /// أطفال من إجمالي [eaters]: يُحسبون بنصف حصة. [portion]: حجم الحصة (0.8 صغيرة · 1 عادية · 1.3 كبيرة) تضبطه الأسرة بنفسها.
  int kids;
  double portion;
  /// «عندي في البيت» (لا يدخل المشتريات): null ← افتراضي النظام. [hidden]: وجبات لا تحبها الأسرة. [favorites]: تظهر أكثر.
  Set<String>? pantry;
  Set<String> hidden, favorites;
  /// وجبات خاصة أضافتها ربّة البيت: [{id, slot, label, items:[[key,qty]]}].
  List<Map<String, dynamic>> custom;
  Household({
    required this.id, required this.label, required this.programId,
    this.cookName = '', this.city = 'Jeddah', this.eaters = 1, this.kids = 0, this.portion = 1.0,
    this.pantry, Set<String>? hidden, Set<String>? favorites, List<Map<String, dynamic>>? custom,
    this.cutoffDay = 5, this.cutoffTime = '20:00', Map<String, PrayerLink>? mealLinks,
  })  : mealLinks = mealLinks ?? Map.of(defaultMealLinks),
        hidden = hidden ?? {},
        favorites = favorites ?? {},
        custom = custom ?? [];

  /// عدد الحصص الفعلي للكميات: الكبار حصة، والأطفال نصف، × حجم الحصة. (الأدنى نصف حصة.)
  double get servings => (((eaters - kids).clamp(0, 99)) + kids * 0.5).clamp(0.5, 99) * portion;
}

/// خطة أسبوع: [يوم][وجبة] ← معرّف الخيار، و«جاهز» لكل (يوم، وجبة).
class WeekPlan {
  final DateTime weekStart;
  final List<Map<String, String>> days; // 7 × {slotId: optionId}
  final Set<String> prepared; // "day:slotId"
  WeekPlan(this.weekStart, this.days, [Set<String>? prepared]) : prepared = prepared ?? {};
  bool isPrepared(int day, String slot) => prepared.contains('$day:$slot');
}

class ShoppingLine {
  final String key;
  int packs;
  double unitPrice;
  bool bought;
  /// العدد المحسوب آلياً آخر مرة: إن اختلف packs عنه فقد عدّله المستخدم يدوياً فنحفظ تعديله، وإلا نعيد الحساب عند تغيّر الخطة/العدد.
  int? auto;
  ShoppingLine(this.key, this.packs, this.unitPrice, [this.bought = false, this.auto]);
}
