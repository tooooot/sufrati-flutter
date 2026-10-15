import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/roles.dart';
import '../auth/session.dart';
import '../routing.dart';
import '../widgets/medical_note.dart';
import '../widgets/profile_button.dart';
import '../platform_flags.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// بعد الدخول: «من أنت؟» — بطاقتان (أدير بيتي / أنا طاهٍ) ورابط صغير للطبيب والأخصائي.
class RoleScreen extends StatelessWidget {
  final Session session;
  const RoleScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final name = session.user?.name ?? '';
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        GreenHeader(leading: const ProfileButton(), icon: '👋', title: name.isEmpty ? 'أهلاً بك' : 'أهلاً $name', subtitle: 'من أنت في سفرتي؟'),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (role, icon, title, sub) in const [
                  (Role.owner, '🏠', 'أدير بيتي وأطبخ لأسرتي', 'أرتّب وجباتنا ومشترياتنا، وأطبخ بنفسي أو أدعو طاهيتي'),
                  (Role.cook, '👩‍🍳', 'أنا طاهٍ دعاني أحد', 'عندي رابط أو رمز دعوة من صاحب البيت'),
                ]) ...[
                  CardBox(
                    onTap: () {
                      session.chooseRole(role);
                      context.go(landing(session)); // من له ارتباط يذهب للوحته، وغيره لإنشاء البيت/إدخال الرمز
                    },
                    child: Row(children: [
                      Text(icon, style: const TextStyle(fontSize: 42)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: const TextStyle(fontSize: 19, fontWeight: black, color: Brand.green)),
                          const SizedBox(height: 2),
                          Text(sub, style: const TextStyle(fontSize: 13.5, color: Brand.grey, height: 1.5)),
                        ]),
                      ),
                      const Text('‹', style: TextStyle(fontSize: 22, color: Colors.grey)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                // الطبيب والأخصائي مسار مهني منفصل: لا يزاحم اختيار الأسرة
                if (doctorFeaturesEnabled) Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.medical_services_outlined, size: 20),
                    label: const Text('أنا طبيب أو أخصائي تغذية ←', style: TextStyle(fontWeight: black, fontSize: 15)),
                    onPressed: () {
                      if (session.links.isDoctor) {
                        session.chooseRole(Role.doctor);
                        context.go(landing(session));
                      } else {
                        context.push(session.links.doctorRequested ? '/doctor-pending' : '/doctor/apply'); // مراجعة واحدة من الإدارة
                      }
                    },
                  ),
                ),
                const SizedBox(height: 6),
                const MedicalNote(),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => session.auth.signOut(),
                  child: const Text('تسجيل الخروج'),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
