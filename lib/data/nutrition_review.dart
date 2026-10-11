import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

/// مراجعة الأخصائي لتقديرات التغذية: مستند لكل مكوّن في nutrition/{البرنامج}__{المكوّن}.
class NutritionReview {
  final FirebaseFirestore db;
  NutritionReview(this.db);

  /// يحمّل ما اعتُمد فيغلب تقديرات الملفات. فشله (بلا إنترنت) لا يمنع التطبيق.
  static Future<void> loadOverrides(FirebaseFirestore db) async {
    try {
      final qs = await db.collection('nutrition').get().timeout(const Duration(seconds: 4));
      nutriOverrides = {for (final d in qs.docs) d.id: _from(d.data())};
    } catch (_) {}
  }

  static Nutri _from(Map<String, dynamic> d) => Nutri(
      (d['kcal'] as num).toDouble(), (d['p'] as num).toDouble(), (d['c'] as num).toDouble(), (d['f'] as num).toDouble(),
      reviewed: true);

  Future<Map<String, Map<String, dynamic>>> reviewed() async {
    final qs = await db.collection('nutrition').get();
    return {for (final d in qs.docs) d.id: d.data()};
  }

  Future<void> save(String programId, String key, Nutri n, {required String by, String? note}) =>
      db.doc('nutrition/${programId}__$key').set({
        'program': programId, 'key': key, 'kcal': n.kcal, 'p': n.p, 'c': n.c, 'f': n.f,
        'status': 'reviewed', 'reviewedBy': by, 'reviewedAt': FieldValue.serverTimestamp(),
        if (note != null && note.isNotEmpty) 'note': note,
      });
}
