import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'models.dart';

/// مكتبة الأنظمة المحلية (داخل التطبيق — تعمل بلا إنترنت).
/// الصور في المرحلة 1 من سيرفر maeda (نفس المصدر)، وتنتقل إلى Firebase Storage في المرحلة 2.
class Library {
  final List<ProgramMeta> programs;
  final List<String> dayNames;
  final Map<String, Set<String>> _photos;
  final Map<String, Program> _cache = {};

  Library._(this.programs, this.dayNames, this._photos);

  static const photoBase = 'https://maeda.wardyat.net/dish-photos';

  static Future<Library> load() async {
    final index = jsonDecode(await rootBundle.loadString('assets/data/programs_index.json'));
    final photos = jsonDecode(await rootBundle.loadString('assets/data/photos.json')) as Map<String, dynamic>;
    final have = {for (final e in photos.entries) e.key: Set<String>.from(e.value)};
    return Library._(
      [for (final p in index['programs'] as List) ProgramMeta(p)],
      List<String>.from(index['day_names']),
      have,
    );
  }

  /// الصور التي تُرفع من مصنع الصور تظهر فور نشرها: نجلب القائمة الحية في الخلفية بعد أول شاشة
  /// (لا تُعطّل الإقلاع أبداً، وفشلها يُبقي القائمة المضمّنة).
  Future<void> refreshPhotos() async {
    try {
      final r = await http.get(Uri.parse('https://maeda.wardyat.net/api/dish-photos')).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        for (final e in (jsonDecode(r.body) as Map<String, dynamic>).entries) {
          (_photos[e.key] ??= {}).addAll(List<String>.from(e.value as List));
        }
      }
    } catch (_) {}
  }

  /// يُسقط الأنظمة المحمّلة (بعد وصول تقديرات الأخصائي) لتُبنى من جديد بها.
  void clearCache() => _cache.clear();

  List<ProgramMeta> get active => programs.where((p) => p.active).toList();
  List<ProgramMeta> get comingSoon => programs.where((p) => !p.active).toList();
  ProgramMeta? meta(String id) => programs.where((p) => p.id == id).firstOrNull;

  Future<Program> program(String id) async {
    final hit = _cache[id];
    if (hit != null) return hit;
    final j = jsonDecode(await rootBundle.loadString('assets/data/programs/$id.json'));
    return _cache[id] = Program(meta(id)!, j);
  }

  String? photoUrl(String programId, String optionId) =>
      (_photos[programId]?.contains(optionId) ?? false) ? '$photoBase/$programId/$optionId.jpg' : null;
}
