// قواعد التوجيه: من يرى أي شاشة. دالة خالصة ليسهل اختبارها.
import 'auth/session.dart';

bool isPublicPath(String p) =>
    p == '/login' || p == '/browse' || p.startsWith('/programs/');

/// يرجع المسار البديل أو null للبقاء.
String? appRedirect(Session s, String p) {
  if (!s.signedIn) return isPublicPath(p) ? null : '/login';
  if (p == '/login') return s.needsRole ? '/role' : '/';
  // الملف الشخصي متاح دائماً بعد الدخول (منه يُغيَّر الدور أو يُخرَج)، وما عداه يتطلب دوراً
  if (s.needsRole && !isPublicPath(p) && p != '/role' && p != '/profile') return '/role';
  return null;
}
