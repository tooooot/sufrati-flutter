import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/growth.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/medical_note.dart';

/// صفحة الطبيب العامة `/dr/<رمز>`: يفتحها متابعوه من رابطه، ثم «ابدأ» ← دخول ← إنشاء بيت ← طلب ربط بالطبيب.
class DoctorPublicScreen extends StatelessWidget {
  final GrowthService growth;
  final String code;
  const DoctorPublicScreen({super.key, required this.growth, required this.code});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FutureBuilder<DoctorProfile?>(
          future: growth.byCode(code),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: Brand.green));
            final d = snap.data;
            if (d == null) {
              return ListView(padding: EdgeInsets.zero, children: [
                const GreenHeader(icon: '🩺', title: 'الرابط غير متاح', subtitle: 'تأكد من الرابط مع طبيبك'),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: TextButton(onPressed: () => context.go('/'), child: const Text('الصفحة الرئيسية'))),
                ),
              ]);
            }
            return ListView(padding: EdgeInsets.zero, children: [
              GreenHeader(icon: '🩺', title: d.name, subtitle: [d.specialty, d.city].where((x) => x.isNotEmpty).join(' · ')),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.verified, color: Brand.honey),
                        const SizedBox(width: 6),
                        const Text('معتمد من إدارة سفرتي', style: TextStyle(fontWeight: black, color: Brand.green)),
                      ]),
                      if (d.bio.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        CardBox(child: Text(d.bio, style: const TextStyle(fontSize: 15, height: 1.8))),
                      ],
                      const SizedBox(height: 14),
                      const CardBox(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('ماذا يحدث عند البدء؟', style: TextStyle(fontWeight: black, fontSize: 16, color: Brand.green)),
                          SizedBox(height: 8),
                          _Point('تسجّل دخولك بنقرة واحدة وتنشئ بيتك.'),
                          _Point('تختار نظامك الغذائي ويصلك جدول وقائمة مشتريات.'),
                          _Point('يصل طلب ربط للطبيب؛ ولا يرى خطتك إلا إذا قبله.'),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: () => context.push('/dr/${d.code}/join'),
                        child: Text('ابدأ مع ${d.name}', style: const TextStyle(fontSize: 18, fontWeight: black)),
                      ),
                      TextButton(onPressed: () => context.push('/pitch/user'), child: const Text('شاهد فكرة التطبيق أولًا')),
                      const MedicalNote(),
                    ]),
                  ),
                ),
              ),
            ]);
          },
        ),
      );
}

class _Point extends StatelessWidget {
  final String t;
  const _Point(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check, color: Brand.honey, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 15, height: 1.6))),
        ]),
      );
}
