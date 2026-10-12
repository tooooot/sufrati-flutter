import '../logic/calories.dart';

/// مسودة رحلة الاستكشاف: تبقى في الذاكرة بين النتيجة والدخول، ثم تتحول إلى بيت حقيقي في /journey/finish.
class JourneyDraft {
  static JourneyDraft? current;

  final String track; // family | weight
  final String programId;
  final int eaters, kids;
  final Profile? profile;
  final Plan? plan;
  final double portion;
  /// من يطبخ في البيت: me | cook | other (للأسرة).
  final String? cooker;
  const JourneyDraft({required this.track, required this.programId, this.eaters = 1, this.kids = 0, this.profile, this.plan, this.portion = 1, this.cooker});

  /// حقول تُخزَّن في وثيقة البيت (للأخصائي والتحكم لاحقاً).
  Map<String, dynamic> toHousehold() => {
        'kids': kids,
        'portion': portion,
        'track': track,
        'cooker': ?cooker,
        if (profile != null && plan != null)
          'profile': {
            'sex': profile!.sex.name, 'age': profile!.age, 'heightCm': profile!.heightCm, 'weightKg': profile!.weightKg,
            'approx': true, 'activity': profile!.activity.name, 'mode': profile!.mode.name, 'goalKg': profile!.goalKg, 'paceKgWeek': profile!.paceKgWeek,
          },
        if (plan != null)
          'target': {
            'kcal': plan!.kcal, 'proteinG': plan!.proteinG.round(), 'fatG': plan!.fatG.round(), 'carbG': plan!.carbG.round(),
            'weeks': plan!.weeks, 'status': 'estimate', // estimate → reviewed (الأخصائي)
          },
      };
}
