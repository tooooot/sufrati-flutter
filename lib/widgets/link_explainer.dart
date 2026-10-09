import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// شرح الربط بثلاث خطوات — يظهر في «بيتي» وعند إدخال الرمز.
class LinkExplainer extends StatelessWidget {
  const LinkExplainer({super.key});

  @override
  Widget build(BuildContext context) => CardBox(
        color: Brand.amber50,
        border: Border.all(color: Brand.honey.withValues(alpha: .5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('كيف يتم الربط؟', style: TextStyle(fontWeight: black, fontSize: 16, color: Brand.green)),
          const SizedBox(height: 8),
          for (final (n, t) in const [
            ('١', 'صاحب البيت يضغط «دعوة» أمام الطاهي أو الطبيب، فيظهر رمز من 6 خانات.'),
            ('٢', 'يرسل الرمز لهم بواتساب (زر المشاركة).'),
            ('٣', 'يسجّل الطاهي أو الطبيب دخوله ويختار دوره ثم يكتب الرمز، فيرتبط بالبيت فوراً.'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 11, backgroundColor: Brand.green,
                    child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: black))),
                const SizedBox(width: 8),
                Expanded(child: Text(t, style: const TextStyle(fontSize: 13, height: 1.5))),
              ]),
            ),
          const Divider(height: 20),
          const Text('الطاهي يرى وجبات اليوم ومكوّناتها فقط، ولا يرى أي بيانات صحية. '
              'الطبيب يتابع مرضاه الذين ربطهم بحسابه. الرمز يعمل مرة واحدة وينتهي بعد 7 أيام.',
              style: TextStyle(fontSize: 12, color: Brand.grey, height: 1.6)),
        ]),
      );
}
