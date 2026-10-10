// إشعارات الدفع (FCM) على أندرويد وآيفون: تسجيل رمز الجهاز في users/{uid}.fcmTokens، وعرض الإشعار والتطبيق مفتوح.
// عند الخروج يُحذف رمز الجهاز من حساب المستخدم (وإلا وصلت إشعاراته لمن يستعمل الجهاز بعده).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../auth/auth_service.dart';
import 'notification_service.dart';

class PushService {
  final FirebaseFirestore db;
  final AuthService auth;
  PushService(this.db, this.auth) {
    if (!NotificationService.supported) return;
    auth.addListener(_onAuth);
    _onAuth();
  }

  String? _uid, _token;
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _fg;

  void _onAuth() {
    final u = auth.user?.uid;
    if (u == _uid) return;
    _uid = u;
    if (u != null) _register(u);
  }

  Future<void> _register(String uid) async {
    try {
      final m = FirebaseMessaging.instance;
      final st = await m.requestPermission();
      if (st.authorizationStatus == AuthorizationStatus.denied) return;
      final t = await m.getToken();
      if (t == null || _uid != uid) return;
      _token = t;
      await _save(uid, t);
      _refresh?.cancel();
      _refresh = m.onTokenRefresh.listen((n) {
        _token = n;
        if (_uid != null) _save(_uid!, n);
      });
      _fg?.cancel();
      _fg = FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        if (n != null) NotificationService.instance.showUpdate(n.title ?? 'سفرتي', n.body ?? '');
      });
    } catch (_) {} // الإشعارات تحسين: لا تُوقف التطبيق
  }

  Future<void> _save(String uid, String t) =>
      db.doc('users/$uid').set({'fcmTokens': FieldValue.arrayUnion([t])}, SetOptions(merge: true));

  /// قبل تسجيل الخروج: أزل رمز هذا الجهاز من الحساب.
  Future<void> unregister() async {
    final uid = _uid, t = _token;
    try {
      if (uid != null && t != null) {
        await db.doc('users/$uid').set({'fcmTokens': FieldValue.arrayRemove([t])}, SetOptions(merge: true));
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
  }
}
