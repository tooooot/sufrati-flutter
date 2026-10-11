// حاسبة السعرات والماكروز. الأرقام تقديرية (±10%) وليست وصفة طبية؛ تُراجَع مع أخصائي تغذية.
import '../data/models.dart';

enum Sex { male, female }

/// lose: تنحيف · cut: تنشيف (تنحيف مع بروتين أعلى) · gain: بناء عضل بفائض سعرات.
enum Mode { lose, cut, gain }

enum Activity { sedentary, light, moderate, high, athlete }

const activityFactor = {
  Activity.sedentary: 1.2,
  Activity.light: 1.375,
  Activity.moderate: 1.55,
  Activity.high: 1.725,
  Activity.athlete: 1.9,
};

class Profile {
  final Sex sex;
  final int age;
  final double heightCm, weightKg;
  final Activity activity;
  /// الوزن المستهدف (للتنحيف) وعدد الكيلوات أسبوعياً.
  final double? goalKg;
  final double paceKgWeek;
  /// حالات تُحوَّل للأخصائي بلا حساب: حمل/رضاعة، سكري، كلى، اضطراب أكل.
  final bool needsSpecialist;
  final Mode mode;
  const Profile({required this.sex, required this.age, required this.heightCm, required this.weightKg, required this.activity,
      this.goalKg, this.paceKgWeek = 0.5, this.needsSpecialist = false, this.mode = Mode.lose});
}

class Plan {
  final double bmr, tdee, kcal, proteinG, fatG, carbG;
  final int? weeks;
  final double bmi;
  final String? note;
  const Plan({required this.bmr, required this.tdee, required this.kcal, required this.proteinG, required this.fatG, required this.carbG,
      required this.bmi, this.weeks, this.note});
}

double bmi(double kg, double cm) => kg / ((cm / 100) * (cm / 100));

double bmr(Profile p) => 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age + (p.sex == Sex.male ? 5 : -161);

/// null = لا حساب آلي (قاصر أو حالة تحتاج أخصائي). النتيجة تُقرَّب لأقرب 50 سعرة.
Plan? planFor(Profile p) {
  if (p.age < 18 || p.needsSpecialist) return null;
  if (p.heightCm < 120 || p.heightCm > 230 || p.weightKg < 30 || p.weightKg > 300) return null;
  final b = bmr(p), t = b * activityFactor[p.activity]!;
  final goal = p.goalKg;
  double target = t;
  int? weeks;
  String? note;
  if (p.mode == Mode.gain) {
    // فائض 5/10/15% من الاحتياج بحسب السرعة: بناء نظيف بلا تراكم دهون كثير
    final surplus = t * (p.paceKgWeek.clamp(0.25, 0.75) / 5);
    target = t + surplus;
    if (goal != null && goal > p.weightKg) weeks = ((goal - p.weightKg) * 5500 / (surplus * 7)).ceil();
  } else if (goal != null && goal < p.weightKg) {
    final pace = p.paceKgWeek.clamp(0.25, 1.0);
    // 1 كغ دهون ≈ 7700 سعرة
    var deficit = pace * 7700 / 7;
    // لا يتجاوز العجز 25% من الاحتياج حتى لا يتهدّم العضل
    if (deficit > t * 0.25) {
      deficit = t * 0.25;
      note = 'خفّضنا السرعة لتبقى آمنة.';
    }
    target = t - deficit;
    final floor = p.sex == Sex.male ? 1500.0 : 1200.0;
    if (target < floor) {
      target = floor;
      note = 'هذا أدنى حدّ آمن للسعرات دون إشراف طبي.';
    }
    final realDeficit = (t - target).clamp(1, 5000);
    weeks = ((p.weightKg - goal) * 7700 / (realDeficit * 7)).ceil();
  }
  target = (target / 50).round() * 50.0;
  final perKg = switch (p.mode) { Mode.gain => 1.8, Mode.cut => 2.2, Mode.lose => (goal != null && goal < p.weightKg) ? 2.0 : 1.6 };
  final protein = perKg * p.weightKg;
  final fat = target * 0.27 / 9;
  final carb = (target - protein * 4 - fat * 9) / 4;
  return Plan(bmr: b, tdee: t, kcal: target, proteinG: protein, fatG: fat, carbG: carb < 0 ? 0 : carb, bmi: bmi(p.weightKg, p.heightCm), weeks: weeks, note: note);
}

/// مجموع تغذية خيار وجبة لكل «حصة بالغ» × [portion]. المكوّنات غير المقدَّرة تُحصى في [missing].
({Nutri total, int missing}) optionNutri(Program prog, MealOption o, {double portion = 1}) {
  var t = Nutri.zero;
  var missing = 0;
  for (final (k, q) in o.items) {
    final n = prog.ingredients[k]?.nutri;
    if (n == null) {
      missing++;
    } else {
      t = t + n * (q * portion);
    }
  }
  return (total: t, missing: missing);
}

/// متوسط تغذية يوم كامل (وجبة واحدة من كل خانة، لحصة بالغ واحدة). يُستعمل لمعايرة حجم الحصة نحو هدف السعرات.
Nutri avgDayNutri(Program prog) {
  var t = Nutri.zero;
  for (final s in prog.slots) {
    if (s.options.isEmpty) continue;
    var sum = Nutri.zero;
    for (final o in s.options) {
      sum = sum + optionNutri(prog, o).total;
    }
    t = t + sum * (1 / s.options.length);
  }
  return t;
}

/// حجم الحصة الذي يقرّب اليوم من [targetKcal] (محصور بين 0.6 و1.5 حتى لا تصبح الأطباق غير واقعية).
double portionFor(Program prog, double targetKcal) {
  final base = avgDayNutri(prog).kcal;
  if (base <= 0) return 1;
  return double.parse((targetKcal / base).clamp(0.6, 1.5).toStringAsFixed(2));
}

/// يعيد بناء Profile من خريطة البيت (مفاتيح journey.dart)، وnull إن نقصت بياناته.
Profile? profileFromMap(Map<String, dynamic>? m) {
  if (m == null) return null;
  try {
    return Profile(
      sex: Sex.values.byName(m['sex'] as String),
      age: (m['age'] as num).toInt(),
      heightCm: (m['heightCm'] as num).toDouble(),
      weightKg: (m['weightKg'] as num).toDouble(),
      activity: Activity.values.byName(m['activity'] as String),
      goalKg: (m['goalKg'] as num?)?.toDouble(),
      paceKgWeek: (m['paceKgWeek'] as num?)?.toDouble() ?? 0.5,
      mode: Mode.values.asNameMap()[m['mode']] ?? Mode.lose,
    );
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> targetMapOf(Plan p, {String status = 'estimate', String? by}) => {
      'kcal': p.kcal, 'proteinG': p.proteinG.round(), 'fatG': p.fatG.round(), 'carbG': p.carbG.round(), 'weeks': p.weeks,
      'status': status, 'reviewedBy': ?by,
    };

/// ماكروز لهدف سعرات يدوي: يبقى البروتين كما هو، الدهون 27%، والباقي كربوهيدرات.
Map<String, dynamic> targetForKcal(double kcal, int proteinG, {int? weeks, String status = 'custom', String? by}) {
  final fat = kcal * 0.27 / 9;
  final carb = (kcal - proteinG * 4 - fat * 9) / 4;
  return {'kcal': kcal, 'proteinG': proteinG, 'fatG': fat.round(), 'carbG': (carb < 0 ? 0 : carb).round(), 'weeks': weeks, 'status': status, 'reviewedBy': ?by};
}
