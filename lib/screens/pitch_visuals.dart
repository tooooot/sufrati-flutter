import 'package:flutter/material.dart';

import '../theme.dart';

/// مقطع من الزمن (0..1) إلى تقدّم محلي بمنحنى ناعم.
double seg(double t, double from, double to) => Curves.easeOutCubic.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

Widget pitchCard({required Widget child, double? w, Color color = Colors.white}) => Container(
      width: w,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6))]),
      child: child,
    );

/// 1) أربع وجبات تدخل واحدة بعد الأخرى وتُضاء علامة الإنجاز.
class MealsVisual extends StatelessWidget {
  final double t;
  const MealsVisual(this.t, {super.key});
  static const _m = [('الفطور', '7:00 ص', Icons.wb_twilight), ('الغداء', '1:00 م', Icons.wb_sunny), ('السناك', '4:30 م', Icons.local_cafe), ('العشاء', '8:00 م', Icons.nights_stay)];
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var k = 0; k < 4; k++)
            Opacity(
              opacity: seg(t, k * .15, k * .15 + .2),
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - seg(t, k * .15, k * .15 + .2))),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: pitchCard(
                    child: Row(children: [
                      Icon(_m[k].$3, color: Brand.honey, size: 26),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_m[k].$1, style: const TextStyle(fontWeight: black, fontSize: 17))),
                      Text(_m[k].$2, style: const TextStyle(color: Brand.honey, fontWeight: black)),
                      const SizedBox(width: 10),
                      Transform.scale(
                        scale: seg(t, .55 + k * .09, .7 + k * .09),
                        child: const CircleAvatar(radius: 12, backgroundColor: Brand.green, child: Icon(Icons.check, size: 16, color: Colors.white)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// 2) أصناف تنزلق وتُشطب والتكلفة تعدّ تصاعدياً.
class ShoppingVisual extends StatelessWidget {
  final double t;
  const ShoppingVisual(this.t, {super.key});
  static const _i = [('صدور دجاج', Icons.set_meal), ('خضار طازجة', Icons.eco), ('أرز', Icons.grain), ('زبادي', Icons.icecream)];
  @override
  Widget build(BuildContext context) {
    final total = (474 * seg(t, .1, .85)).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var k = 0; k < 4; k++)
          Opacity(
            opacity: seg(t, k * .13, k * .13 + .18),
            child: Transform.translate(
              offset: Offset(40 * (1 - seg(t, k * .13, k * .13 + .18)), 0),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: pitchCard(
                  child: Row(children: [
                    Icon(_i[k].$2, color: Brand.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_i[k].$1,
                          style: TextStyle(fontWeight: black, fontSize: 16,
                              decoration: seg(t, .5 + k * .1, .6 + k * .1) > .9 ? TextDecoration.lineThrough : null,
                              color: seg(t, .5 + k * .1, .6 + k * .1) > .9 ? Colors.grey : null)),
                    ),
                    Icon(seg(t, .5 + k * .1, .6 + k * .1) > .9 ? Icons.check_box : Icons.check_box_outline_blank, color: Brand.green),
                  ]),
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text('$total ر.س', style: const TextStyle(color: Brand.cream, fontSize: 30, fontWeight: black)),
        const Text('التكلفة التقديرية', style: TextStyle(color: Color(0xFFDCEBE3), fontSize: 13)),
      ]),
    );
  }
}

/// 3) تنبيه ينزل من الأعلى، وزر «حُضّرت» يُضغط، فتصل علامة الاطمئنان لصاحب الخطة.
class CookVisual extends StatelessWidget {
  final double t;
  const CookVisual(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final drop = seg(t, .05, .3);
    final press = seg(t, .55, .65);
    final ok = seg(t, .7, .9);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Stack(alignment: Alignment.center, children: [
        Transform.translate(
          offset: Offset(0, -60 * (1 - drop)),
          child: Opacity(
            opacity: drop,
            child: Align(
              alignment: Alignment.topCenter,
              child: pitchCard(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const CircleAvatar(radius: 18, backgroundColor: Brand.honey, child: Icon(Icons.notifications_active, color: Colors.white, size: 20)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('العشاء بعد 45 دقيقة', style: TextStyle(fontWeight: black, fontSize: 16)),
                        Text('سمك مشوي مع أرز وخضار', style: TextStyle(color: Brand.grey, fontSize: 13)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Transform.scale(
                    scale: 1 - .06 * (press < 1 ? press : 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: press > .5 ? Brand.green : Brand.honey, borderRadius: BorderRadius.circular(12)),
                      child: Text(press > .5 ? 'حُضّرت ✓' : 'حُضّرت', textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: black, fontSize: 16)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: ok,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - ok)),
              child: pitchCard(
                color: Brand.cream,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified, color: Brand.green),
                  SizedBox(width: 8),
                  Text('وصلك: العشاء جاهز', style: TextStyle(fontWeight: black, color: Brand.green, fontSize: 16)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// 4) ثلاث دوائر (صاحب الخطة/الطاهي/الطبيب) تتصل بخطوط تنبض.
class HouseVisual extends StatelessWidget {
  final double t;
  const HouseVisual(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final pulse = (1 + (t * 6).remainder(1.0)) * .5 + .5;
    Widget node(IconData i, String label, double from, {bool main = false}) => Opacity(
          opacity: seg(t, from, from + .2),
          child: Transform.scale(
            scale: .6 + .4 * seg(t, from, from + .2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: main ? 84 : 68, height: main ? 84 : 68,
                decoration: BoxDecoration(shape: BoxShape.circle, color: main ? Brand.honey : Brand.cream,
                    boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 14, offset: Offset(0, 6))]),
                child: Icon(i, size: main ? 44 : 34, color: main ? Colors.white : Brand.green),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: black, fontSize: 15)),
            ]),
          ),
        );
    return Stack(alignment: Alignment.center, children: [
      CustomPaint(size: const Size(300, 270), painter: LinesPainter(seg(t, .3, .6), pulse)),
      Positioned(top: 8, child: node(Icons.home, 'صاحب الخطة', 0, main: true)),
      Positioned(bottom: 6, right: 40, child: node(Icons.restaurant, 'الطاهي', .2)),
      Positioned(bottom: 6, left: 40, child: node(Icons.medical_services, 'الطبيب', .35)),
    ]);
  }
}

class LinesPainter extends CustomPainter {
  final double grow, pulse;
  LinesPainter(this.grow, this.pulse);
  @override
  void paint(Canvas canvas, Size s) {
    final top = Offset(s.width / 2, 122), r = Offset(s.width - 74, s.height - 50), l = Offset(74, s.height - 50);
    final p = Paint()..color = Colors.white.withValues(alpha: .55 * grow)..strokeWidth = 3 * pulse..strokeCap = StrokeCap.round;
    canvas.drawLine(top, Offset.lerp(top, r, grow)!, p);
    canvas.drawLine(top, Offset.lerp(top, l, grow)!, p);
  }

  @override
  bool shouldRepaint(LinesPainter o) => o.grow != grow || o.pulse != pulse;
}

/// بطاقة بروفايل الطبيب: الصورة الرمزية والاسم والتخصص، ثم شارة «موثَّق» تظهر.
class DoctorProfileVisual extends StatelessWidget {
  final double t;
  final String name;
  const DoctorProfileVisual(this.t, {super.key, this.name = ''});
  @override
  Widget build(BuildContext context) {
    final n = name.isEmpty ? 'د. اسمك' : name;
    final badge = seg(t, .45, .6);
    return Center(
      child: Opacity(
        opacity: seg(t, 0, .2),
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - seg(t, 0, .2))),
          child: SizedBox(
            width: 290,
            child: pitchCard(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 6),
                CircleAvatar(radius: 38, backgroundColor: Brand.green, child: Text(n.characters.last == '.' ? 'د' : n.trim().characters.first,
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: black))),
                const SizedBox(height: 10),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(n, style: const TextStyle(fontSize: 21, fontWeight: black)),
                  const SizedBox(width: 6),
                  Transform.scale(scale: badge, child: const Icon(Icons.verified, color: Brand.honey, size: 24)),
                ]),
                Opacity(opacity: seg(t, .25, .4),
                    child: const Text('أخصائي تغذية علاجية · جدة', style: TextStyle(color: Brand.grey, fontSize: 14))),
                const SizedBox(height: 8),
                Opacity(opacity: badge,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: Brand.green.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
                      child: const Text('معتمد من إدارة سفرتي', style: TextStyle(color: Brand.green, fontWeight: black, fontSize: 13)),
                    )),
                const SizedBox(height: 6),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// رابط الطبيب يُكتب أمامك ثم يتحول إلى رسالة واتساب يتجمّع حولها المتابعون.
class LinkShareVisual extends StatelessWidget {
  final double t;
  const LinkShareVisual(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    const link = 'maeda.wardyat.net/dr/AB12CD34';
    final n = (link.length * seg(t, .05, .4)).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        pitchCard(
          child: Row(children: [
            const Icon(Icons.link, color: Brand.green),
            const SizedBox(width: 10),
            Expanded(child: Text(link.substring(0, n), textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: black, fontSize: 15))),
          ]),
        ),
        const SizedBox(height: 18),
        Opacity(
          opacity: seg(t, .45, .6),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - seg(t, .45, .6))),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFDCF8C6), borderRadius: BorderRadius.circular(16)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat, color: Color(0xFF128C7E)),
                SizedBox(width: 8),
                Text('جرّبوا نظامي الغذائي بالتطبيق', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1F2937))),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var k = 0; k < 5; k++)
            Opacity(
              opacity: seg(t, .6 + k * .06, .72 + k * .06),
              child: Transform.scale(
                scale: seg(t, .6 + k * .06, .72 + k * .06),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: CircleAvatar(radius: 20, backgroundColor: k.isEven ? Brand.honey : Brand.cream,
                      child: Icon(Icons.person, color: k.isEven ? Colors.white : Brand.green)),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// طلبات الربط تصل الطبيب فيقبلها بنقرة وتظهر العلامة.
class PatientsVisual extends StatelessWidget {
  final double t;
  const PatientsVisual(this.t, {super.key});
  static const _n = ['سارة', 'عبدالله', 'نورة'];
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var k = 0; k < 3; k++)
            Opacity(
              opacity: seg(t, k * .14, k * .14 + .2),
              child: Transform.translate(
                offset: Offset(40 * (1 - seg(t, k * .14, k * .14 + .2)), 0),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: pitchCard(
                    child: Row(children: [
                      const CircleAvatar(radius: 18, backgroundColor: Brand.green, child: Icon(Icons.person, color: Colors.white)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_n[k], style: const TextStyle(fontWeight: black, fontSize: 17))),
                      seg(t, .5 + k * .12, .62 + k * .12) > .9
                          ? const Icon(Icons.check_circle, color: Brand.green)
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(color: Brand.honey, borderRadius: BorderRadius.circular(12)),
                              child: const Text('قبول', style: TextStyle(color: Colors.white, fontWeight: black)),
                            ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// وجبة تتبدّل بنقرة فيصل التغيير للمريض والطاهي.
class EditPlanVisual extends StatelessWidget {
  final double t;
  const EditPlanVisual(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final swapped = t > .45;
    final sent = seg(t, .65, .8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        pitchCard(
          child: Row(children: [
            const Icon(Icons.nights_stay, color: Brand.honey),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(swapped ? 'سمك مشوي مع خضار' : 'دجاج بالفرن مع أرز', key: ValueKey(swapped),
                    style: const TextStyle(fontWeight: black, fontSize: 17)),
              ),
            ),
            Transform.rotate(angle: seg(t, .3, .5) * 6.283, child: const Icon(Icons.autorenew, color: Brand.green)),
          ]),
        ),
        const SizedBox(height: 18),
        Opacity(
          opacity: sent,
          child: pitchCard(
            color: Brand.cream,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.done_all, color: Brand.green),
              SizedBox(width: 8),
              Text('وصل التعديل للمريض والطاهي', style: TextStyle(fontWeight: black, color: Brand.green, fontSize: 15)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// جروب: رسالة صورة قديمة تُشطب وتحلّ محلها رسالة برابط.
class GroupChatVisual extends StatelessWidget {
  final double t;
  const GroupChatVisual(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final strike = seg(t, .3, .45);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Opacity(
          opacity: (seg(t, 0, .15) * (1 - .6 * strike)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.image, color: Colors.grey),
              const SizedBox(width: 8),
              Text('جدول الوجبات (صورة)',
                  style: TextStyle(fontWeight: black, fontSize: 15, decoration: strike > .5 ? TextDecoration.lineThrough : null)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Opacity(
          opacity: seg(t, .5, .65),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - seg(t, .5, .65))),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFDCF8C6), borderRadius: BorderRadius.circular(16)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.link, color: Color(0xFF128C7E)),
                SizedBox(width: 8),
                Text('رابط واحد يرتّب كل شيء', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1F2937))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// عدّاد أعضاء ينضمون واحداً بعد الآخر.
class MembersJoinVisual extends StatelessWidget {
  final double t;
  const MembersJoinVisual(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final n = (24 * seg(t, .1, .9)).round();
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('$n', style: const TextStyle(color: Brand.cream, fontSize: 64, fontWeight: black)),
      const Text('عضو انضم من رابطك', style: TextStyle(color: Color(0xFFDCEBE3), fontSize: 15)),
      const SizedBox(height: 18),
      Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
        for (var k = 0; k < 12; k++)
          Opacity(
            opacity: seg(t, k * .06, k * .06 + .12),
            child: Transform.scale(
              scale: seg(t, k * .06, k * .06 + .12),
              child: CircleAvatar(radius: 18, backgroundColor: k.isEven ? Brand.honey : Brand.cream,
                  child: Icon(Icons.person, size: 20, color: k.isEven ? Colors.white : Brand.green)),
            ),
          ),
      ]),
    ]);
  }
}

/// نصوص رسوم الطاهي بثلاث لغات (ar/en/am): ما يراه الطاهي يطابق لغته.
const cookText = <String, Map<String, String>>{
  'ar': {
    'meal': 'العشاء', 'time': '8:00 م', 'dish': 'سمك مشوي مع أرز وخضار', 'i1': 'سمك', 'i2': 'أرز', 'i3': 'خضار',
    'n1': 'بعد 45 دقيقة', 'n2': 'حان موعد العشاء', 'btn': 'حُضّرت', 'ok': 'وصل صاحب الخطة: الوجبة جاهزة',
  },
  'en': {
    'meal': 'Dinner', 'time': '8:00 PM', 'dish': 'Grilled fish with rice and vegetables', 'i1': 'Fish', 'i2': 'Rice', 'i3': 'Vegetables',
    'n1': 'In 45 minutes', 'n2': 'Dinner time', 'btn': 'Prepared', 'ok': 'Owner notified: meal is ready',
  },
  'am': {
    'meal': 'እራት', 'time': '8:00 PM', 'dish': 'የተጠበሰ ዓሳ ከሩዝና አትክልት ጋር', 'i1': 'ዓሳ', 'i2': 'ሩዝ', 'i3': 'አትክልት',
    'n1': 'ከ45 ደቂቃ በኋላ', 'n2': 'የእራት ሰዓት ደርሷል', 'btn': 'ተዘጋጅቷል', 'ok': 'ለባለቤቱ ተላከ፡ ምግቡ ዝግጁ ነው',
  },
};

/// 1) بطاقة وجبة اليوم للطاهي: الاسم والوقت ثم مكوّناتها تظهر واحداً بعد الآخر.
class CookTodayVisual extends StatelessWidget {
  final double t;
  final String lang;
  const CookTodayVisual(this.t, {super.key, required this.lang});
  @override
  Widget build(BuildContext context) {
    final x = cookText[lang]!;
    return Center(
      child: Opacity(
        opacity: seg(t, 0, .2),
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - seg(t, 0, .2))),
          child: SizedBox(
            width: 300,
            child: pitchCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Icon(Icons.nights_stay, color: Brand.honey),
                  const SizedBox(width: 8),
                  Text(x['meal']!, style: const TextStyle(fontWeight: black, fontSize: 20)),
                  const Spacer(),
                  Text(x['time']!, style: const TextStyle(color: Brand.honey, fontWeight: black, fontSize: 16)),
                ]),
                const SizedBox(height: 8),
                Text(x['dish']!, style: const TextStyle(fontSize: 16, height: 1.5, color: Brand.grey)),
                const SizedBox(height: 12),
                for (var k = 1; k <= 3; k++)
                  Opacity(
                    opacity: seg(t, .25 + k * .12, .4 + k * .12),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Icon(Icons.check_circle, size: 20, color: Brand.green.withValues(alpha: .85)),
                        const SizedBox(width: 8),
                        Text(x['i$k']!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2) تنبيهان ينزلان من الأعلى: قبل الموعد بـ45 دقيقة، ثم عند الموعد.
class NotifyVisual extends StatelessWidget {
  final double t;
  final String lang;
  const NotifyVisual(this.t, {super.key, required this.lang});
  @override
  Widget build(BuildContext context) {
    final x = cookText[lang]!;
    Widget card(String title, String sub, double from, {bool strong = false}) => Opacity(
          opacity: seg(t, from, from + .18),
          child: Transform.translate(
            offset: Offset(0, -40 * (1 - seg(t, from, from + .18))),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SizedBox(
                width: 300,
                child: pitchCard(
                  child: Row(children: [
                    CircleAvatar(radius: 20, backgroundColor: strong ? Brand.green : Brand.honey, child: const Icon(Icons.notifications_active, color: Colors.white, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontWeight: black, fontSize: 16)),
                      Text(sub, style: const TextStyle(color: Brand.grey, fontSize: 13)),
                    ])),
                  ]),
                ),
              ),
            ),
          ),
        );
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      card('${x['meal']} · ${x['n1']}', x['dish']!, .05),
      card('${x['n2']} · ${x['time']}', x['dish']!, .45, strong: true),
    ]);
  }
}

/// 3) اللغة: اسم الوجبة نفسه يتبدّل بين العربية والإنجليزية والأمهرية.
class LanguageVisual extends StatelessWidget {
  final double t;
  const LanguageVisual(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    const order = ['ar', 'en', 'am'];
    const names = {'ar': 'العربية', 'en': 'English', 'am': 'አማርኛ'};
    final i = (t * 3).floor().clamp(0, 2);
    final x = cookText[order[i]]!;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var k = 0; k < 3; k++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: k == i ? Brand.honey : Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Text(names[order[k]]!, style: const TextStyle(color: Colors.white, fontWeight: black, fontSize: 15)),
          ),
      ]),
      const SizedBox(height: 18),
      SizedBox(
        width: 300,
        child: pitchCard(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(key: ValueKey(i), crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(x['meal']!, style: const TextStyle(fontWeight: black, fontSize: 20)),
              const SizedBox(height: 6),
              Text(x['dish']!, style: const TextStyle(fontSize: 16, height: 1.5, color: Brand.grey)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Brand.green, borderRadius: BorderRadius.circular(12)),
                child: Text(x['btn']!, style: const TextStyle(color: Colors.white, fontWeight: black)),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// 4) زر «حُضّرت» يُضغط فتصل علامة الاطمئنان لصاحب الخطة (بلغة الطاهي).
class CookDoneVisual extends StatelessWidget {
  final double t;
  final String lang;
  const CookDoneVisual(this.t, {super.key, required this.lang});
  @override
  Widget build(BuildContext context) {
    final x = cookText[lang]!;
    final press = seg(t, .25, .4);
    final ok = seg(t, .55, .8);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 300,
        child: pitchCard(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${x['meal']} · ${x['time']}', style: const TextStyle(fontWeight: black, fontSize: 18)),
            const SizedBox(height: 10),
            Transform.scale(
              scale: 1 - .06 * (press < 1 ? press : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: press > .5 ? Brand.green : Brand.honey, borderRadius: BorderRadius.circular(12)),
                child: Text(press > .5 ? '${x['btn']} ✓' : x['btn']!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: black, fontSize: 17)),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Opacity(
        opacity: ok,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - ok)),
          child: pitchCard(
            color: Brand.cream,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified, color: Brand.green),
              const SizedBox(width: 8),
              Flexible(child: Text(x['ok']!, style: const TextStyle(fontWeight: black, color: Brand.green, fontSize: 15))),
            ]),
          ),
        ),
      ),
    ]);
  }
}
