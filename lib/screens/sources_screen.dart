import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';

/// المصادر العلمية: روابط لما تعتمد عليه حسابات سفرتي وتوصياتها (Apple 1.4.1 تشترط استشهاداً سهل الوصول).
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  static const _groups = <(String, List<(String, String, String)>)>[
    ('حاسبة السعرات', [
      ('معادلة ميفلين–سان جور لمعدل الأيض الأساسي', 'Mifflin MD وآخرون، American Journal of Clinical Nutrition، 1990',
          'https://pubmed.ncbi.nlm.nih.gov/2305711/'),
      ('معاملات النشاط البدني (1.2 – 1.9)', 'منظمة الأغذية والزراعة / منظمة الصحة / جامعة الأمم المتحدة: Human Energy Requirements، 2001',
          'https://www.fao.org/4/y5686e/y5686e00.htm'),
      ('مؤشر كتلة الجسم وتصنيفاته', 'منظمة الصحة العالمية: السمنة وزيادة الوزن', 'https://www.who.int/news-room/fact-sheets/detail/obesity-and-overweight'),
    ]),
    ('البروتين والتغذية العامة', [
      ('احتياج البروتين للرياضيين وبناء العضل (1.4 – 2.2 غ/كغ)', 'الجمعية الدولية للتغذية الرياضية، 2017',
          'https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8'),
      ('أسس الغذاء الصحي', 'منظمة الصحة العالمية: النظام الغذائي الصحي', 'https://www.who.int/news-room/fact-sheets/detail/healthy-diet'),
    ]),
    ('التغذية في أمراض الكلى', [
      ('إرشادات التغذية لمرضى الكلى المزمنة', 'KDOQI Clinical Practice Guideline for Nutrition in CKD، 2020', 'https://doi.org/10.1053/j.ajkd.2020.05.006'),
    ]),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [
          const GreenHeader(icon: '📚', title: 'المصادر العلمية'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'أرقام سفرتي تقديرية (±10%) مبنية على المراجع التالية، وليست تشخيصاً ولا وصفة علاجية. استشر طبيبك أو أخصائي التغذية قبل أي تغيير في نظامك، خاصة مع الأمراض المزمنة أو الحمل.',
                style: TextStyle(fontSize: 14, color: Brand.grey, height: 1.7),
              ),
              for (final (title, items) in _groups) ...[
                const SizedBox(height: 18),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: black, color: Brand.green)),
                const SizedBox(height: 8),
                CardBox(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final (i, s) in items.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(s.$1, style: const TextStyle(fontWeight: black, fontSize: 15)),
                        subtitle: Text('${s.$2}\n${s.$3}', style: const TextStyle(fontSize: 12.5, height: 1.6)),
                        trailing: const Icon(Icons.open_in_new, size: 20, color: Brand.green),
                        onTap: () => launchUrl(Uri.parse(s.$3), mode: LaunchMode.externalApplication),
                      ),
                    ],
                  ]),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'محتوى نظام الكلى مأخوذ من دليل تغذية علاجية صادر عن مستشفى متخصص ومنقول بحدوده دون إضافة أرقام من عندنا. الوثيقة تُقدَّم عند الطلب.',
                style: TextStyle(fontSize: 13, color: Brand.grey, height: 1.7),
              ),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: () => context.back('/'), child: const Text('‹ رجوع')),
            ]),
          ),
        ]),
      );
}
