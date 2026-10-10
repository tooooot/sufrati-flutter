// قواعد التوجيه: من يرى أي شاشة. دالة خالصة ليسهل اختبارها.
import 'auth/roles.dart';
import 'auth/session.dart';

bool isPublicPath(String p) =>
    p == '/login' || p == '/browse' || p == '/intro' || p.startsWith('/programs/') || p.startsWith('/p/') || p.startsWith('/pitch/') ||
    (p.startsWith('/dr/') && !p.endsWith('/join'));

/// الشاشة الرئيسية لكل دور بعد الدخول.
String landing(Session s) => switch (s.role) {
      Role.owner => s.links.hasHousehold ? '/me' : '/new-house',
      Role.cook => s.links.membershipOf(Role.cook) != null ? '/cook' : '/join/cook',
      Role.doctor => s.links.membershipOf(Role.doctor) != null ? '/me' : '/join/doctor',
      Role.admin => '/admin',
      null => '/role',
    };

/// يرجع المسار البديل أو null للبقاء.
/// وجهة صالحة بعد الدخول: مسار داخلي فقط (يمنع التحويل لمواقع خارجية).
bool _validNext(String? n) => n != null && n.startsWith('/') && !n.startsWith('//') && !n.startsWith('/login') && !n.startsWith('/loading');

/// وجهات تُقبَل حتى لمن لم يختر دوراً بعد: روابط الدعوة (/i) وطبيب المتابعين (/dr) وختم التسويق (/r)
/// وطلب الطبيب (/doctor/apply) والانضمام (/join). غيرها ← شاشة اختيار الدور أولاً.
bool _roleless(String n) =>
    n.startsWith('/i/') || n.startsWith('/dr/') || n.startsWith('/r/') || n.startsWith('/doctor/apply') || n.startsWith('/join/');

/// [full] المسار مع الاستعلام (لحفظه عند التحويل للدخول)، [next] وجهة محفوظة من قبل.
String? appRedirect(Session s, String p, {String? full, String? next, bool landingForGuests = false}) {
  if (!s.signedIn) {
    if (isPublicPath(p)) return null;
    if (landingForGuests && p == '/') return null; // الصفحة التعريفية للزائر (الويب)
    return '/login?next=${Uri.encodeComponent(full ?? p)}';
  }
  // نحفظ الوجهة أثناء التحميل أيضاً (وإلا ضاع الرابط العميق وتحديث الصفحة)
  if (!s.ready) return p == '/loading' ? null : '/loading?next=${Uri.encodeComponent(full ?? p)}';
  if (p == '/loading' || p == '/login' || p == '/') {
    if (_validNext(next) && (!s.needsRole || _roleless(next!))) return next;
    return landing(s);
  }
  if (p == '/admin' && !s.isAdmin) return landing(s);
  // الملف الشخصي متاح دائماً بعد الدخول (منه يُغيَّر الدور أو يُخرَج)، وما عداه يتطلب دوراً
  if (s.needsRole && !isPublicPath(p) && p != '/role' && p != '/profile' && p != '/doctor-pending' && p != '/doctor/apply' && !p.startsWith('/i/') && !p.startsWith('/dr/') && !p.startsWith('/r/')) return '/role';
  return null;
}
