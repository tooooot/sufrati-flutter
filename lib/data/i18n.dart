// ترجمات لوحة الطباخ (عربي/إنجليزي/أمهري) — من assets/data/i18n.json (مُصدَّرة من maeda/app/i18n.py).
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// ترجمات الأطباق والتعليمات مكتوبة لنظام الكلى فقط؛ الأنظمة الأخرى تبقى بالعربية حتى تُترجم
/// (التعليمات مرتبة بالفهرس — تطبيقها على نظام آخر يعرض نصاً خاطئاً).
const translatedProgram = 'kidney_salama';

class CookI18n {
  final Map<String, dynamic> _t;
  CookI18n._(this._t);

  static Future<CookI18n> load() async =>
      CookI18n._(jsonDecode(await rootBundle.loadString('assets/data/i18n.json')));

  Map<String, String> get langs => Map<String, String>.from(_t['LANGS']);

  String ui(String key, String lang) =>
      (lang == 'en' || lang == 'am') ? (_t['UI'][key]?[lang] ?? _t['_AR_UI'][key]) : _t['_AR_UI'][key];

  bool _tr(String lang) => lang == 'en' || lang == 'am';

  String dayName(int day, String lang, String ar) => _tr(lang) ? _t['DAY_NAMES_TR'][lang][day] : ar;

  String slotName(String slotId, String lang, String ar) =>
      _tr(lang) ? (_t['MEAL_SLOT_NAME_TR'][lang][slotId] ?? ar) : ar;

  String option(String programId, String optionId, String lang, String ar) =>
      _tr(lang) && programId == translatedProgram ? (_t['OPTION_LABEL_TR'][lang][optionId] ?? ar) : ar;

  String ingredient(String programId, String key, String lang, String ar) =>
      _tr(lang) && programId == translatedProgram ? (_t['INGREDIENT_LABEL_TR'][lang][key] ?? ar) : ar;

  /// {title, steps} مترجمة أو العربية كما هي.
  (String, List<String>) recipe(String programId, String recipeId, String lang, Map<String, dynamic> ar) {
    if (_tr(lang) && programId == translatedProgram) {
      final tr = _t['RECIPE_TR'][lang][recipeId];
      if (tr != null) return (tr['title'], List<String>.from(tr['steps']));
    }
    return (ar['title'] ?? '', List<String>.from(ar['steps'] ?? const []));
  }

  String listItem(String table, String programId, int index, String lang, String ar) {
    if (!_tr(lang) || programId != translatedProgram) return ar;
    final items = _t[table][lang] as List;
    return index < items.length ? items[index] : ar;
  }
}
