import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

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
    return Library._(
      [for (final p in index['programs'] as List) ProgramMeta(p)],
      List<String>.from(index['day_names']),
      {for (final e in photos.entries) e.key: Set<String>.from(e.value)},
    );
  }

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
