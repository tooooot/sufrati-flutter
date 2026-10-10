// طابور الإشعارات: التطبيق يكتب «حدثاً» في notifyQueue (قواعد Firestore تتحقق من صلاحية الكاتب)،
// وعامل الخادم يفرّغه ويرسل FCM للمستلمين. بلا تهيئة (الاختبارات) كل الاستدعاءات لا تفعل شيئاً.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_service.dart';

class EventQueue {
  EventQueue._();
  static final instance = EventQueue._();

  FirebaseFirestore? _db;
  AuthService? _auth;
  final _last = <String, DateTime>{};

  void configure(FirebaseFirestore db, AuthService auth) {
    _db = db;
    _auth = auth;
  }

  /// يكتب حدثاً. [throttleKey] يمنع تكراره قبل [every] (تعديلات متتابعة ← إشعار واحد). الفشل صامت: الإشعار تحسين لا شرط.
  Future<void> emit(String type, {String? hid, String? meal, String? code, String? toUid, String? throttleKey, Duration every = Duration.zero}) async {
    final db = _db, u = _auth?.user;
    if (db == null || u == null) return;
    if (throttleKey != null) {
      final prev = _last[throttleKey];
      if (prev != null && DateTime.now().difference(prev) < every) return;
      _last[throttleKey] = DateTime.now();
    }
    try {
      await db.collection('notifyQueue').add({
        'type': type, 'from': u.uid, 'fromName': u.name, 'createdAt': FieldValue.serverTimestamp(),
        'hid': ?hid, 'meal': ?meal, 'code': ?code, 'toUid': ?toUid,
      });
    } catch (_) {}
  }
}
