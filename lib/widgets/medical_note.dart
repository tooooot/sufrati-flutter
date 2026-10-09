import 'package:flutter/material.dart';

import '../theme.dart';

/// إخلاء طبي ظاهر: سفرتي تنظيم غذائي وليست استشارة (شرط متاجر التطبيقات الصحية).
class MedicalNote extends StatelessWidget {
  /// معرّف النظام الغذائي إن وُجد: يظهر مصدر محتواه (Apple 1.4.1 تشترط ذكر مصدر المعلومات الطبية).
  final String? programId;
  const MedicalNote({super.key, this.programId});

  /// المصدر بلا اسم المستشفى (قرار سابق: التطبيق بلا اسم المستشفى). الوثيقة نفسها تُقدَّم للمراجع عند الطلب.
  static String sourceFor(String? programId) => switch (programId) {
        null => '',
        'kidney_salama' => 'مصدر المحتوى: دليل التغذية العلاجية لمرضى الكلى الصادر عن مستشفى متخصص، منقولاً بحدوده دون إضافة أرقام غذائية من عندنا.',
        _ => 'مصدر المحتوى: مكتبة وجبات سفرتي المركّبة من مبادئ تغذية شائعة، دون حساب طبي للسعرات ولا ادعاء علاجي.',
      };

  @override
  Widget build(BuildContext context) {
    final src = sourceFor(programId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 4),
      child: Column(children: [
        const Text(
          'سفرتي أداة لتنظيم الوجبات ولا تغني عن استشارة طبيبك أو أخصائي التغذية، '
          'خاصة لمرضى الكلى والأمراض المزمنة. استشر طبيبك قبل أي تغيير في نظامك الغذائي.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Brand.grey, height: 1.7),
        ),
        if (src.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(src, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Brand.grey, height: 1.7)),
        ],
      ]),
    );
  }
}
