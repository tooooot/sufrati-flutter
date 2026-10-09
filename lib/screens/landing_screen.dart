import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// الصفحة التعريفية للزائر (على الويب): قصة الفكرة قبل أي تسجيل — نفس تصميم لوحة «الصفحة التعريفية» المعتمدة.
class LandingScreen extends StatefulWidget {
  final Library library;
  const LandingScreen({super.key, required this.library});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  int _role = 0;

  static const _roles = [
    ('صاحب الخطة', 'صاحب الخطة: كل شيء بين يديك', [
      'خطة أسبوعية وقائمة مشتريات جاهزتان بنظامك',
      'تعدّل أي وجبة قبل موعد القفل مساء الخميس',
      'تدعو الطاهي والطبيب برمز واحد يُرسل بواتساب',
      'ترى كم وجبة حُضّرت اليوم دون أن تسأل',
    ], 'تدير البيت كله وتحذفه متى شئت.'),
    ('الطاهي', 'الطاهي: يعرف ماذا يطبخ ومتى', [
      'الوجبة القادمة بوقتها ومكوّناتها وطريقتها',
      'تنبيه قبل الموعد بـ45 دقيقة',
      'زر «حُضّرت» يطمئن صاحب الخطة',
      'بالعربية أو English أو አማርኛ',
    ], 'لا يرى أي بيانات صحية، وجبات اليوم فقط.'),
    ('الطبيب', 'الطبيب: يتابع مرضاه عن قرب', [
      'يُعتمد حسابه من مدير سفرتي قبل أي وصول',
      'يرى خطة من ربطوه بهم فقط',
      'يعدّل الوجبات ويصحّح الخطة',
      'لا يصل لبيانات أي أسرة غير مرضاه',
    ], 'التفعيل بموافقة المدير حمايةً للمرضى.'),
  ];

  @override
  Widget build(BuildContext context) {
    final photo = widget.library.photoUrl('kidney_salama', 'm2o2');
    final r = _roles[_role];
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          _Section(color: Brand.cream, child: Column(children: [
            // الشريط العلوي
            Row(children: [
              const Icon(Icons.restaurant, size: 30, color: Brand.green),
              const SizedBox(width: 8),
              const Text('سفرتي', style: TextStyle(fontSize: 26, fontWeight: black, color: Brand.green)),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Brand.honey, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                onPressed: () => context.go('/login'),
                child: const Text('ابدأ الآن', style: TextStyle(fontWeight: black, fontSize: 16)),
              ),
            ]),
            const SizedBox(height: 36),
            // البطل
            Wrap(spacing: 40, runSpacing: 28, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: Brand.honey.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
                    child: const Text('للبيت · للطاهي · للطبيب', style: TextStyle(color: Brand.honey, fontWeight: black, fontSize: 14)),
                  ),
                  const SizedBox(height: 14),
                  const Text('وجبات بيتك مرتّبة،\nبلا سؤال «وش نطبخ؟»',
                      style: TextStyle(fontSize: 40, height: 1.3, fontWeight: black, color: Brand.green)),
                  const SizedBox(height: 14),
                  const Text('سفرتي تجهّز لأسرتك خطة أسبوعية وقائمة مشتريات حسب نظامك الغذائي، والطاهي يعرف ماذا يطبخ ومتى، وطبيبك يتابع الخطة معك.',
                      style: TextStyle(fontSize: 18, height: 1.8, color: Brand.grey)),
                  const SizedBox(height: 22),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Brand.honey, padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16)),
                      onPressed: () => context.go('/login'),
                      child: const Text('ابدأ بحساب Google', style: TextStyle(fontWeight: black, fontSize: 17)),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Brand.green, width: 2), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
                      onPressed: () => context.go('/browse'),
                      child: const Text('تصفّح الأنظمة بلا تسجيل', style: TextStyle(fontWeight: black, fontSize: 16, color: Brand.green)),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  const Wrap(spacing: 18, runSpacing: 6, children: [
                    _Tick('دخول بنقرة واحدة'), _Tick('بلا إعلانات ولا بيع بيانات'), _Tick('تحذف حسابك متى شئت'),
                  ]),
                ]),
              ),
              if (photo != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30), color: Colors.white,
                      border: Border.all(color: Brand.honey, width: 2),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 14))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      DishPhoto(photo, width: 380, height: 220),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('الوجبة القادمة · 8:00 م', style: TextStyle(color: Brand.honey, fontWeight: black, fontSize: 13)),
                          SizedBox(height: 4),
                          Text('سمك أبيض مشوي مع أرز', style: TextStyle(fontSize: 20, fontWeight: black)),
                        ]),
                      ),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 56),
          ])),

          _Section(color: Colors.white, child: Column(children: [
            const _H('ثلاث خطوات وبيتك جاهز'),
            const SizedBox(height: 24),
            Wrap(spacing: 18, runSpacing: 18, children: const [
              _Step('١', 'سجّل دخولك', 'بحساب Google أو Apple بنقرة واحدة، بلا كلمة سر ولا نموذج.'),
              _Step('٢', 'اختر نظامك وأنشئ بيتك', 'تشاهد الأنظمة، ثم تسمّي بيتك وتحدد عدد من يأكل في شاشة واحدة.'),
              _Step('٣', 'ادعُ طاهيك وطبيبك', 'رابط قصير يصل بواتساب، فينضمّون ويرون ما يخصهم فقط.'),
            ]),
          ])),

          _Section(color: Brand.cream, child: Column(children: [
            const _H('لكل فرد في البيت شاشته'),
            const SizedBox(height: 18),
            Wrap(spacing: 10, children: [
              for (final (i, role) in _roles.indexed)
                ChoiceChip(
                  label: Text(role.$1, style: TextStyle(fontWeight: black, fontSize: 16, color: _role == i ? Colors.white : Brand.green)),
                  selected: _role == i, selectedColor: Brand.green, backgroundColor: Colors.white,
                  side: const BorderSide(color: Brand.green, width: 2),
                  onSelected: (_) => setState(() => _role = i),
                ),
            ]),
            const SizedBox(height: 22),
            CardBox(
              padding: const EdgeInsets.all(26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.$2, style: const TextStyle(fontSize: 24, fontWeight: black, color: Brand.green)),
                const SizedBox(height: 14),
                for (final pt in r.$3)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.check, color: Brand.honey, size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: Text(pt, style: const TextStyle(fontSize: 17, height: 1.6))),
                    ]),
                  ),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Brand.green.withValues(alpha: .07), borderRadius: BorderRadius.circular(14)),
                  child: Text(r.$4, style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.green)),
                ),
              ]),
            ),
          ])),

          _Section(color: Colors.white, child: Column(children: [
            const _H('اختر النظام الذي يناسبك'),
            const SizedBox(height: 8),
            const Text('شاهد وجباته وجدوله الأسبوعي قبل أن تقرر، بلا تسجيل.', style: TextStyle(fontSize: 16, color: Brand.grey)),
            const SizedBox(height: 22),
            Wrap(spacing: 14, runSpacing: 14, children: [
              for (final p in widget.library.active)
                SizedBox(
                  width: 270,
                  child: CardBox(
                    color: Brand.cream,
                    onTap: () => context.go('/programs/${p.id}'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${p.icon}  ${p.label}', style: const TextStyle(fontSize: 19, fontWeight: black, color: Brand.green)),
                      const SizedBox(height: 6),
                      Text(p.blurb, maxLines: 3, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, height: 1.6, color: Brand.grey)),
                    ]),
                  ),
                ),
            ]),
          ])),

          _Section(color: Brand.cream, child: Column(children: [
            const _H('خصوصيتك قاعدة لا ميزة'),
            const SizedBox(height: 22),
            Wrap(spacing: 16, runSpacing: 16, children: const [
              _Trust('الطاهي لا يرى بياناتك الصحية', 'يرى وجبات اليوم ومكوّناتها فقط. القيود مطبّقة على الخادم نفسه لا في الواجهة.'),
              _Trust('حذف حسابك من التطبيق', 'زر واحد في الملف الشخصي يمسح حسابك وبيتك وخططك نهائياً.'),
              _Trust('بلا إعلانات ولا تتبّع', 'لا نبيع بياناتك ولا نشاركها. التنبيهات تُجدوَل داخل جوالك.'),
            ]),
            const SizedBox(height: 20),
            const Text('سفرتي أداة لتنظيم الوجبات ولا تغني عن استشارة طبيبك أو أخصائي التغذية، خاصة لمرضى الكلى والأمراض المزمنة.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Brand.grey, height: 1.8)),
          ])),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            color: Brand.cream,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(color: Brand.green, borderRadius: BorderRadius.circular(32)),
                  child: Column(children: [
                    const Text('جاهز أن يطبخ بيتك بلا حيرة؟', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 30, fontWeight: black, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text('سجّل بنقرة واحدة وابدأ بأول وجبة اليوم.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 22),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Brand.honey, padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18)),
                      onPressed: () => context.go('/login'),
                      child: const Text('ابدأ الآن', style: TextStyle(fontWeight: black, fontSize: 18)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          Container(
            color: Brand.cream,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Wrap(spacing: 22, runSpacing: 6, alignment: WrapAlignment.center, children: [
              const Text('سفرتي · أداة لتنظيم الوجبات', style: TextStyle(color: Brand.grey, fontWeight: FontWeight.w700)),
              InkWell(onTap: () => launchUrl(Uri.parse('https://maeda.wardyat.net/privacy')),
                  child: const Text('سياسة الخصوصية', style: TextStyle(color: Brand.green, fontWeight: black))),
              InkWell(onTap: () => launchUrl(Uri.parse('https://maeda.wardyat.net/delete-account')),
                  child: const Text('حذف الحساب', style: TextStyle(color: Brand.green, fontWeight: black))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Section({required this.color, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: color,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: child)),
      );
}

class _H extends StatelessWidget {
  final String t;
  const _H(this.t);
  @override
  Widget build(BuildContext context) =>
      Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: black, color: Brand.green));
}

class _Tick extends StatelessWidget {
  final String t;
  const _Tick(this.t);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check, color: Brand.green, size: 18),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.grey, fontSize: 14)),
      ]);
}

class _Step extends StatelessWidget {
  final String n, title, body;
  const _Step(this.n, this.title, this.body);
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 320,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 22, backgroundColor: Brand.green, child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: black))),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 21, fontWeight: black, color: Brand.green)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: 15.5, height: 1.8, color: Brand.grey)),
          ]),
        ),
      );
}

class _Trust extends StatelessWidget {
  final String title, body;
  const _Trust(this.title, this.body);
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 340,
        child: CardBox(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: black, color: Brand.green)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: 15, height: 1.8, color: Brand.grey)),
          ]),
        ),
      );
}
