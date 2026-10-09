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

  // مثل منبه الساعة: صوت على قناة المنبهات + اهتزاز + نافذة علوية، وملء الشاشة حيث يُسمح به.
  // إعدادات قناة أندرويد لا تتغير بعد إنشائها على الجهاز، فكل تغيير يلزمه معرّف جديد ('meals_v3') ونحذف القديمين.
  static const _channelId = 'meals_v3';
  static final _vibration = Int64List.fromList([0, 600, 300, 600, 300, 900]);
  static final _channel = AndroidNotificationChannel(
    _channelId, 'تنبيهات الوجبات',
    description: 'وقت تحضير وتقديم الوجبات',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: _vibration,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  Future<void> _ensureInit() async {
    if (_init) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_sufrati'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ));
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final old in const ['meals', 'meals_v2']) {
      await android?.deleteNotificationChannel(channelId: old);
    }
    await android?.createNotificationChannel(_channel);
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
      return ok;
    }
    final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await i?.requestPermissions(alert: true, sound: true, badge: false) ?? false;
  }

  NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(_channelId, 'تنبيهات الوجبات',
            channelDescription: 'وقت تحضير وتقديم الوجبات',
            importance: Importance.max, priority: Priority.high,
            playSound: true, enableVibration: true, vibrationPattern: _vibration,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            category: AndroidNotificationCategory.alarm,
            // بلا ملء الشاشة وبلا منبّهات دقيقة: كلاهما يتطلب تصريحاً خاصاً في Google Play وقد يُرفض التطبيق بسببهما
            visibility: NotificationVisibility.public,
            icon: 'ic_stat_sufrati', color: const Color(0xFF1F5A44)),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true),
      );

  /// يستبدل كل التنبيهات المجدولة بالقائمة الجديدة.
  Future<int> schedule(List<CookAlert> alerts) async {
    await _ensureInit();
    await _plugin.cancelAll();
    final riyadh = tz.getLocation('Asia/Riyadh');
    var n = 0;
    for (final al in alerts) {
      final when = tz.TZDateTime(riyadh, al.at.year, al.at.month, al.at.day, al.at.hour, al.at.minute);
      await _plugin.zonedSchedule(
        id: al.id, title: al.title, body: al.body, scheduledDate: when, notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // قد يتأخر دقائق في وضع السكون
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
