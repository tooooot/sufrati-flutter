import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// تصفّح الأنظمة — نقل لـ start.html.
class StartScreen extends StatelessWidget {
  final Library library;
  const StartScreen({super.key, required this.library});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        const GreenHeader(icon: '🍽️', title: 'سفرتي',
            subtitle: 'تصفّح كل نظام قبل ما تختار — شوف وجباته وجدوله الأسبوعي أول'),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 512),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final p in library.active) ...[
                  CardBox(
                    onTap: () => context.push('/programs/${p.id}'),
                    child: Row(children: [
                      Text(p.icon, style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.label, style: const TextStyle(fontWeight: black, fontSize: 18)),
                          Text(p.blurb, style: const TextStyle(fontSize: 12, color: Brand.grey)),
                        ]),
                      ),
                      const Text('‹', style: TextStyle(fontSize: 22, color: Colors.grey)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                CardBox(
                  color: Brand.amber50,
                  border: Border.all(color: Brand.honey, width: 2),
                  onTap: () => context.push('/signup/custom'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Text('📄', style: TextStyle(fontSize: 36)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('عندي نظام خاص من طبيبي', style: TextStyle(fontWeight: black, fontSize: 18)),
                          Text('ارفع ملف نظامك (PDF/صورة) ويجهّزه فريقنا لك بنفس التطبيق',
                              style: TextStyle(fontSize: 12, color: Brand.grey)),
                        ]),
                      ),
                      Text('‹', style: TextStyle(fontSize: 22, color: Colors.grey)),
                    ]),
                    const Divider(color: Color(0xFFFDE68A)),
                    Text('👨‍⚕️ يراجعه فريقنا ويحوّله لجدول أسبوعي بالصور — يصلك جاهزاً عادةً خلال يوم',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                  ]),
                ),
                if (library.comingSoon.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('قريباً', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  for (final p in library.comingSoon)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Opacity(
                        opacity: .6,
                        child: CardBox(
                          color: Brand.cream,
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Text(p.icon, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p.label, style: const TextStyle(fontWeight: black)),
                                Text(p.blurb, style: const TextStyle(fontSize: 12, color: Brand.grey)),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99)),
                              child: const Text('قريباً', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
