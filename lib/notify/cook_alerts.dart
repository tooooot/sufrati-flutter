// جدول تنبيهات الطاهي: لكل وجبة تنبيهان — «ابدأ التحضير» قبلها بـ45 دقيقة و«وقت التقديم» عند موعدها.
// نفس منطق /cook/<token>/alerts.json في السيرفر القديم (معرّفات ثابتة فإعادة الجدولة تستبدل ولا تكرّر).
import '../data/i18n.dart';
import '../data/store.dart';
import '../logic/day_view.dart';
import '../logic/prayer.dart';

const alertDays = 7; // 7 أيام × 4 وجبات × تنبيهان = 56 (حد iOS 64 تنبيهاً معلّقاً)
const prepLeadMinutes = 45;

class CookAlert {
  final int id;
  final DateTime at; // توقيت السعودية (ساعة الحائط)
  final String title, body;
  const CookAlert(this.id, this.at, this.title, this.body);
}

/// [nowSaudi] بتوقيت السعودية. الأيام التي لم تُجهَّز خطتها بعد تُتخطّى بصمت.
Future<List<CookAlert>> buildCookAlerts(HouseholdStore store, CookI18n i18n,
    {required DateTime nowSaudi, String lang = 'ar', int days = alertDays}) async {
  final program = await store.program();
  final out = <CookAlert>[];
  for (var d = 0; d < days; d++) {
    final date = DateTime(nowSaudi.year, nowSaudi.month, nowSaudi.day).add(Duration(days: d));
    final DayView day;
    try {
      day = await dayView(store, program, date);
    } catch (_) {
      continue;
    }
    for (final (idx, s) in day.slots.indexed) {
      final opt = s.option;
      final hm = s.time;
      if (opt == null || hm.isEmpty) continue;
      final parts = hm.split(':').map(int.parse).toList();
      final at = DateTime(date.year, date.month, date.day, parts[0], parts[1]);
      final name = i18n.slotName(s.slot.id, lang, s.slot.name);
      final dish = i18n.option(program.meta.id, opt.id, lang, opt.label);
      final body = dish.isEmpty ? ar12(hm, lang) : '$dish · ${ar12(hm, lang)}';
      // تذكيرات التحضير المبكر الخاصة بالوجبة (فك الدجاج الليلة قبل الغداء مثلاً): معرّفاتها 3..9 بعد معرّف الوجبة
      for (final (ri, r) in opt.remind.indexed) {
        final fireAt = at.subtract(Duration(minutes: (r.hoursBefore * 60).round()));
        if (!fireAt.isAfter(nowSaudi) || ri > 6) continue;
        out.add(CookAlert(
          int.parse('${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}') * 100 + idx * 10 + 3 + ri,
          fireAt,
          '⏰ $name — ${dish.isEmpty ? '' : dish}',
          r.text,
        ));
      }
      for (final (kind, fireAt) in [('prep', at.subtract(const Duration(minutes: prepLeadMinutes))), ('serve', at)]) {
        if (!fireAt.isAfter(nowSaudi)) continue;
        out.add(CookAlert(
          int.parse('${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}') * 100 + idx * 10 + (kind == 'prep' ? 1 : 2),
          fireAt,
          '${s.slot.icon} ${i18n.ui('notif_$kind', lang)} — $name',
          body,
        ));
      }
    }
  }
  return out;
}
