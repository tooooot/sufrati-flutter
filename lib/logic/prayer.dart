// مواقيت الصلاة محلياً (بلا إنترنت) — تحل محل خدمة Aladhan في maeda/app/prayer.py.
// نفس الطريقة: أم القرى (method=4)، ووقت الوجبة = وقت الصلاة المرتبطة + الإزاحة بالدقائق.
import 'package:adhan/adhan.dart';

const prayerNames = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
const prayerLabelsAr = {
  'Fajr': 'الفجر', 'Sunrise': 'الشروق', 'Dhuhr': 'الظهر',
  'Asr': 'العصر', 'Maghrib': 'المغرب', 'Isha': 'العشاء',
};

/// إحداثيات المدن (الاسم كما يُخزَّن في إعدادات البيت). غير المعروفة ← جدة.
const cityCoords = <String, (double, double)>{
  'Jeddah': (21.4858, 39.1925), 'Makkah': (21.3891, 39.8579), 'Mecca': (21.3891, 39.8579),
  'Madinah': (24.5247, 39.5692), 'Medina': (24.5247, 39.5692), 'Riyadh': (24.7136, 46.6753),
  'Dammam': (26.4207, 50.0888), 'Khobar': (26.2172, 50.1971), 'Taif': (21.2703, 40.4158),
  'Rabigh': (22.7986, 39.0349), 'Yanbu': (24.0895, 38.0618), 'Tabuk': (28.3838, 36.5550),
  'Abha': (18.2164, 42.5053), 'Buraidah': (26.3260, 43.9750), 'Hail': (27.5114, 41.7208),
  'Jazan': (16.8892, 42.5511), 'Najran': (17.5656, 44.2289), 'Al Kharj': (24.1556, 47.3340),
};

const _saudiOffset = Duration(hours: 3);

/// {'Fajr': '05:01', ...} بتوقيت السعودية مهما كان توقيت الجهاز.
Map<String, String> prayerTimes(DateTime date, String city) {
  final (lat, lng) = cityCoords[city] ?? cityCoords['Jeddah']!;
  final params = CalculationMethod.umm_al_qura.getParameters();
  final t = PrayerTimes(Coordinates(lat, lng), DateComponents(date.year, date.month, date.day), params,
      utcOffset: _saudiOffset);
  String f(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return {
    'Fajr': f(t.fajr), 'Sunrise': f(t.sunrise), 'Dhuhr': f(t.dhuhr),
    'Asr': f(t.asr), 'Maghrib': f(t.maghrib), 'Isha': f(t.isha),
  };
}

class PrayerLink {
  final String prayer;
  final int offset;
  const PrayerLink(this.prayer, this.offset);
}

/// الافتراضي نفسه في maeda (DEFAULT_SETTINGS.meal_prayer_links).
const defaultMealLinks = {
  'meal1': PrayerLink('Sunrise', 30),
  'meal2': PrayerLink('Dhuhr', 60),
  'meal3': PrayerLink('Asr', 45),
  'meal4': PrayerLink('Maghrib', 90),
};

/// وقت كل وجبة = الصلاة + الإزاحة — نفس resolve_meal_times.
Map<String, String> resolveMealTimes(DateTime date, String city, Map<String, PrayerLink> links) {
  final times = prayerTimes(date, city);
  return {
    for (final MapEntry(key: slot, value: link) in links.entries)
      slot: () {
        final p = (times[link.prayer] ?? '12:00').split(':').map(int.parse).toList();
        final total = (p[0] * 60 + p[1] + link.offset) % (24 * 60);
        return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
      }(),
  };
}

/// '20:00' ← '08:00 م' (أو PM بالإنجليزية/الأمهرية) — نفس to_ar12.
String ar12(String hhmm, [String lang = 'ar']) {
  if (!hhmm.contains(':')) return hhmm;
  final p = hhmm.split(':').map(int.parse).toList();
  final period = (lang == 'en' || lang == 'am') ? (p[0] < 12 ? 'AM' : 'PM') : (p[0] < 12 ? 'ص' : 'م');
  final h12 = p[0] % 12 == 0 ? 12 : p[0] % 12;
  return '${h12.toString().padLeft(2, '0')}:${p[1].toString().padLeft(2, '0')} $period';
}
