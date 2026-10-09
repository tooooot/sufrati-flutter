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
String? appRedirect(Session s, String p) {
  if (!s.signedIn) return isPublicPath(p) ? null : '/login';
  if (!s.ready) return p == '/loading' ? null : '/loading';
  if (p == '/loading' || p == '/login' || p == '/') return landing(s);
  if (p == '/admin' && !s.isAdmin) return landing(s);
  // الملف الشخصي متاح دائماً بعد الدخول (منه يُغيَّر الدور أو يُخرَج)، وما عداه يتطلب دوراً
  if (s.needsRole && !isPublicPath(p) && p != '/role' && p != '/profile' && p != '/doctor-pending') return '/role';
  return null;
}
