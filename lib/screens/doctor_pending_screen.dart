import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/roles.dart';
import '../auth/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// الطبيب لا يُفعَّل بالاختيار: يبقى هنا حتى يوافق المدير ثم يتابع.
class DoctorPendingScreen extends StatelessWidget {
  final Session session;
  const DoctorPendingScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final approved = session.links.isDoctor;
          return Scaffold(
            body: ListView(padding: EdgeInsets.zero, children: [
              GreenHeader(icon: approved ? '✅' : '⏳', title: approved ? 'تم تفعيل حساب الطبيب' : 'طلبك قيد المراجعة',
                  subtitle: approved ? 'يمكنك الآن ربط مرضاك' : 'يراجعه مدير سفرتي ويفعّل حسابك'),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(approved
                      ? 'اضغط متابعة وأدخل رمز الدعوة الذي يصلك من مريضك.'
                      : 'نتحقق من حسابات الأطباء قبل السماح بالاطلاع على خطط المرضى. ستتفعّل هذه الصفحة تلقائياً عند الموافقة.',
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Brand.grey, height: 1.8)),
                  const SizedBox(height: 20),
                  if (approved)
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(50)),
                      onPressed: () {
                        session.chooseRole(Role.doctor);
                        context.go('/join/doctor');
                      },
                      child: const Text('متابعة', style: TextStyle(fontSize: 17, fontWeight: black)),
                    ),
                  TextButton(onPressed: () => context.go('/role'), child: const Text('‹ اختيار دور آخر')),
                ]),
              ),
            ]),
          );
        },
      );
}
