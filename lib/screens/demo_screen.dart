import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// مدخل المعاينة للوحات (قبل الحسابات في المرحلة 2): بيت تجريبي في الذاكرة يُعاد عند تحديث الصفحة.
class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [
          const GreenHeader(icon: '🧪', title: 'معاينة اللوحات', subtitle: 'بيت تجريبي — نظام الكلى، شخصان، الطاهي ماريا'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (icon, title, sub, path) in [
                ('👤', 'لوحة المريض / صاحب البيت', 'الوجبات · المشتريات · تعديل الأسبوع القادم', '/demo/me'),
                ('👩‍🍳', 'لوحة الطاهي', 'الوجبة القادمة · الطريقة · «جاهز» · 3 لغات', '/demo/cook'),
              ]) ...[
                CardBox(
                  onTap: () => context.go(path),
                  child: Row(children: [
                    Text(icon, style: const TextStyle(fontSize: 40)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: black, color: Brand.green)),
                      Text(sub, style: const TextStyle(fontSize: 12, color: Brand.grey)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              const Text('التغييرات هنا تجريبية ولا تُحفظ. البيانات الحقيقية تأتي مع Firebase في المرحلة 2.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Brand.grey)),
            ]),
          ),
        ]),
      );
}
