import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';

/// تفضيلات الحساب (تتبع صاحبها على كل أجهزته): حجم الخط الآن، ونوع المنبّه لاحقاً. مخزّنة في users/{uid}.prefs.
class PrefsService extends ChangeNotifier {
  final FirebaseFirestore db;
  final AuthService auth;
  double fontScale = 1.0;
  String? _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  PrefsService(this.db, this.auth) {
    auth.addListener(_onAuth);
    _onAuth();
  }

  static const scales = [('صغير', 0.9), ('عادي', 1.0), ('كبير', 1.15), ('أكبر', 1.3)];

  void _onAuth() {
    final u = auth.user?.uid;
    if (u == _uid) return;
    _sub?.cancel();
    _uid = u;
    if (u == null) {
      fontScale = 1.0;
      notifyListeners();
      return;
    }
    _sub = db.doc('users/$u').snapshots().listen((s) {
      final v = ((s.data()?['prefs'] as Map?)?['fontScale'] as num?)?.toDouble();
      final next = (v ?? 1.0).clamp(0.8, 1.5).toDouble();
      if (next != fontScale) {
        fontScale = next;
        notifyListeners();
      }
    }, onError: (_) {});
  }

  Future<void> setFontScale(double v) async {
    fontScale = v;
    notifyListeners();
    final u = _uid;
    if (u == null) return;
    try {
      await db.doc('users/$u').set({'prefs': {'fontScale': v}}, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  void dispose() {
    auth.removeListener(_onAuth);
    _sub?.cancel();
    super.dispose();
  }
}
