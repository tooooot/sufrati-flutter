// بيانات البيت — شكل واحد للتخزين المحلي (المعاينة) ولـFirestore (المرحلة 2).
import '../logic/prayer.dart';

class Household {
  String id, label, programId, cookName, city;
  int eaters, cutoffDay;
  String cutoffTime;
  Map<String, PrayerLink> mealLinks;
  Household({
    required this.id, required this.label, required this.programId,
    this.cookName = '', this.city = 'Jeddah', this.eaters = 1,
    this.cutoffDay = 3, this.cutoffTime = '20:00', Map<String, PrayerLink>? mealLinks,
  }) : mealLinks = mealLinks ?? Map.of(defaultMealLinks);
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
  ShoppingLine(this.key, this.packs, this.unitPrice, [this.bought = false]);
}
