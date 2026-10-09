// قواعد التوجيه: من يرى أي شاشة. دالة خالصة ليسهل اختبارها.
import 'auth/roles.dart';
import 'auth/session.dart';

bool isPublicPath(String p) =>
    p == '/login' || p == '/browse' || p.startsWith('/programs/');

/// الشاشة الرئيسية لكل دور بعد الدخول.
String landing(Session s) => switch (s.role) {
      Role.owner => s.links.hasHousehold ? '/me' : '/household',
      Role.cook => s.links.membershipOf(Role.cook) != null ? '/cook' : '/join/cook',
      Role.doctor => s.links.membershipOf(Role.doctor) != null ? '/me' : '/join/doctor',
      Role.admin => '/admin',
      null => '/role',
    };

/// يرجع المسار البديل أو null للبقاء.
/// وجهة صالحة بعد الدخول: مسار داخلي فقط (يمنع التحويل لمواقع خارجية).
bool _validNext(String? n) => n != null && n.startsWith('/') && !n.startsWith('//') && !n.startsWith('/login') && !n.startsWith('/loading');

/// [full] المسار مع الاستعلام (لحفظه عند التحويل للدخول)، [next] وجهة محفوظة من قبل.
String? appRedirect(Session s, String p, {String? full, String? next}) {
  if (!s.signedIn) {
    if (isPublicPath(p)) return null;
    return '/login?next=${Uri.encodeComponent(full ?? p)}';
  }
  if (!s.ready) return p == '/loading' ? null : '/loading';
  if (p == '/loading' || p == '/login' || p == '/') {
    if (!s.needsRole && _validNext(next)) return next;
    return landing(s);
  }
  if (p == '/admin' && !s.isAdmin) return landing(s);
  // الملف الشخصي متاح دائماً بعد الدخول (منه يُغيَّر الدور أو يُخرَج)، وما عداه يتطلب دوراً
  if (s.needsRole && !isPublicPath(p) && p != '/role' && p != '/profile' && p != '/doctor-pending') return '/role';
  return null;
}
