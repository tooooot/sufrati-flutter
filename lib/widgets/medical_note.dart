import 'package:flutter/material.dart';

import '../theme.dart';

/// إخلاء طبي ظاهر: سفرتي تنظيم غذائي وليست استشارة (شرط متاجر التطبيقات الصحية).
class MedicalNote extends StatelessWidget {
  const MedicalNote({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(8, 20, 8, 4),
        child: Text(
          'سفرتي أداة لتنظيم الوجبات ولا تغني عن استشارة طبيبك أو أخصائي التغذية، '
          'خاصة لمرضى الكلى والأمراض المزمنة. استشر طبيبك قبل أي تغيير في نظامك الغذائي.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: Brand.grey, height: 1.7),
        ),
      );
}
