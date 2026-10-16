import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// إخلاء طبي ظاهر: سفرتي تنظيم غذائي وليست استشارة (شرط متاجر التطبيقات الصحية).
class MedicalNote extends StatelessWidget {
  /// معرّف النظام الغذائي إن وُجد: يظهر مصدر محتواه (Apple 1.4.1 تشترط ذكر مصدر المعلومات الطبية).
  final String? programId;
  const MedicalNote({super.key, this.programId});

  /// نص المصدر المعروض تحت الإخلاء الطبي؛ الروابط في شاشة /sources.
  static String sourceFor(String? programId) => switch (programId) {
        null => '',
        _ => 'مصدر المحتوى: مكتبة وجبات سفرتي المركّبة من مبادئ تغذية شائعة، دون حساب طبي للسعرات ولا ادعاء علاجي.',
      };

  @override
  Widget build(BuildContext context) {
    final src = sourceFor(programId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 4),
      child: Column(children: [
        const Text(
          'سفرتي أداة تنظيم ولا تغني عن استشارة طبيبك أو أخصائي التغذية، خاصة لأصحاب الأمراض المزمنة.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Brand.grey, height: 1.7),
        ),
        if (src.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(src, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Brand.grey, height: 1.7)),
        ],
        TextButton.icon(
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: const Text('المصادر العلمية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          onPressed: () => context.push('/sources'),
        ),
      ]),
    );
  }
}
