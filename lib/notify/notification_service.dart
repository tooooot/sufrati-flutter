// تنبيهات الطاهي المحلية (تعمل والتطبيق مغلق): قناة «meals» بأهمية قصوى ← شريط علوي خفيف فوق أي تطبيق مع صوت واهتزاز.
// التوقيت بتوقيت السعودية صراحةً مهما كان توقيت الجوال.
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'cook_alerts.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _init = false;

  /// الجوال فقط (الويب بلا تنبيهات محلية).
  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static const _channel = AndroidNotificationChannel(
    'meals', 'تنبيهات الوجبات',
    description: 'وقت تحضير وتقديم الوجبات',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> _ensureInit() async {
    if (_init) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_sufrati'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ));
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);
    _init = true;
  }

  /// هل الإذن ممنوح الآن؟
  Future<bool> enabled() async {
    if (!supported) return false;
    await _ensureInit();
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (a != null) return await a.areNotificationsEnabled() ?? false;
    final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final p = await i?.checkPermissions();
    return p?.isEnabled ?? false;
  }

  /// يطلب الإذن (إشعارات + على أندرويد 12+ «المنبهات والتذكيرات» لدقة التوقيت).
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await _ensureInit();
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (a != null) {
      final ok = await a.requestNotificationsPermission() ?? false;
      if (ok && !(await a.canScheduleExactNotifications() ?? true)) await a.requestExactAlarmsPermission();
      return ok;
    }
    final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await i?.requestPermissions(alert: true, sound: true, badge: false) ?? false;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails('meals', 'تنبيهات الوجبات',
            channelDescription: 'وقت تحضير وتقديم الوجبات',
            importance: Importance.max, priority: Priority.high,
            icon: 'ic_stat_sufrati', color: Color(0xFF1F5A44), category: AndroidNotificationCategory.reminder),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true),
      );

  /// يستبدل كل التنبيهات المجدولة بالقائمة الجديدة.
  Future<int> schedule(List<CookAlert> alerts) async {
    await _ensureInit();
    await _plugin.cancelAll();
    final riyadh = tz.getLocation('Asia/Riyadh');
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact = a == null ? true : (await a.canScheduleExactNotifications() ?? false);
    var n = 0;
    for (final al in alerts) {
      final when = tz.TZDateTime(riyadh, al.at.year, al.at.month, al.at.day, al.at.hour, al.at.minute);
      await _plugin.zonedSchedule(
        id: al.id, title: al.title, body: al.body, scheduledDate: when, notificationDetails: _details,
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      );
      n++;
    }
    return n;
  }

  /// تنبيه تجريبي بعد 10 ثوانٍ ليتأكد الطاهي أن الإشعار يصل.
  Future<void> test(String title, String body) async {
    await _ensureInit();
    final when = tz.TZDateTime.now(tz.getLocation('Asia/Riyadh')).add(const Duration(seconds: 10));
    await _plugin.zonedSchedule(
        id: 999999, title: title, body: body, scheduledDate: when, notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
  }

  Future<void> cancelAll() async {
    if (!supported) return;
    await _ensureInit();
    await _plugin.cancelAll();
  }
}
