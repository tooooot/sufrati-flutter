// فيديو قصير لكل دور يُرفق مع أي دعوة يرسلها أي طرف: owner (صاحب الخطة/المريض) · cook (الطاهي) · specialist (طبيب/أخصائي/صاحب جروب).
// الفيديوهات تولّدها في جيمناي ويرفعها محمد من مصنع دهاء، وops/ingest_role_videos.py ينشرها على الخادم؛ لا فيديو منشور ← الرسالة نص فقط.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class RoleVideos {
  RoleVideos._();
  static const base = 'https://maeda.wardyat.net';
  static Map<String, bool>? _cache;
  static DateTime? _at;

  static String pageUrl(String role) => '$base/v/$role';
  static String fileUrl(String role) => '$base/media/sufrati/$role.mp4';

  /// هل نُشر فيديو لهذا الدور؟ (يُخزَّن 10 دقائق؛ أي فشل شبكة ← لا فيديو، فلا تتعطل الدعوة.)
  static Future<bool> has(String role) async {
    if (_cache == null || DateTime.now().difference(_at!) > const Duration(minutes: 10)) {
      try {
        final r = await http.get(Uri.parse('$base/api/role-videos')).timeout(const Duration(seconds: 6));
        _cache = r.statusCode == 200 ? Map<String, bool>.from(jsonDecode(r.body) as Map) : <String, bool>{};
      } catch (_) {
        _cache = <String, bool>{};
      }
      _at = DateTime.now();
    }
    return _cache![role] == true;
  }

  /// نص الرسالة مع رابط صفحة الفيديو (يظهر بمعاينة في واتساب) إن وُجد فيديو للدور.
  static Future<String> withLink(String text, String role) async =>
      await has(role) ? '$text\n\nشاهد الفيديو القصير: ${pageUrl(role)}' : text;

  /// يرسل الرسالة مع الفيديو. على الجوال: يُرفق الملف نفسه عبر قائمة المشاركة (واتساب يعرضه مع النص كتعليق).
  /// على الويب أو عند فشل التنزيل: واتساب برسالة فيها رابط الفيديو. بلا فيديو منشور: النص وحده.
  static Future<void> share(String text, String role) async {
    if (!await has(role)) return _wa(text);
    if (!kIsWeb) {
      try {
        final r = await http.get(Uri.parse(fileUrl(role))).timeout(const Duration(seconds: 45));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
          final dir = await getTemporaryDirectory();
          final f = File('${dir.path}/sufrati_$role.mp4');
          await f.writeAsBytes(r.bodyBytes);
          await SharePlus.instance.share(ShareParams(text: text, files: [XFile(f.path, mimeType: 'video/mp4')]));
          return;
        }
      } catch (_) {/* نرجع للرابط */}
    }
    return _wa('$text\n\nشاهد الفيديو القصير: ${pageUrl(role)}');
  }

  static Future<void> _wa(String text) =>
      launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
}
