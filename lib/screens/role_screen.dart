import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/roles.dart';
import '../auth/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// بعد الدخول: «كيف ستستخدم سفرتي؟» — صاحب بيت، أو الطاهي، أو الطبيب.
class RoleScreen extends StatelessWidget {
  final Session session;
  const RoleScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final name = session.user?.name ?? '';
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        GreenHeader(icon: '👋', title: name.isEmpty ? 'أهلاً بك' : 'أهلاً $name', subtitle: 'كيف ستستخدم سفرتي؟'),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (role, icon, title, sub, next) in const [
                  (Role.owner, '🏠', 'صاحب البيت', 'أتابع نظامي الغذائي أو نظام أحد أفراد بيتي', '/'),
                  (Role.cook, '👨‍🍳', 'الطاهي', 'دعاني صاحب البيت وعندي رمز الدعوة', '/join'),
                  (Role.doctor, '🩺', 'الطبيب', 'أتابع مرضاي وأجهّز أنظمتهم', '/doctor-request'),
                ]) ...[
                  CardBox(
                    onTap: () {
                      session.chooseRole(role);
                      context.go(next);
                    },
                    child: Row(children: [
                      Text(icon, style: const TextStyle(fontSize: 40)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: const TextStyle(fontSize: 19, fontWeight: black, color: Brand.green)),
                          const SizedBox(height: 2),
                          Text(sub, style: const TextStyle(fontSize: 13, color: Brand.grey, height: 1.5)),
                        ]),
                      ),
                      const Text('‹', style: TextStyle(fontSize: 22, color: Colors.grey)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
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
