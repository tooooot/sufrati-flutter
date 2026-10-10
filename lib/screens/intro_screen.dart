import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// عرض الفكرة الحركي للزائر (على الجوال): أربع لقطات تتقدّم وحدها وبلمسة، وكل لقطة رسم متحرك بالكود. نفس روح مقدمة «مستشاري».
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  static const _beats = 4;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && _i < _beats - 1) _go(_i + 1);
    })
    ..forward();
  int _i = 0;

  void _go(int i) {
    if (i < 0 || i >= _beats) return;
    setState(() => _i = i);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _titles = [
    'وجباتك كلها في مكان واحد',
    'قائمة مشتريات تُبنى وحدها',
    'الطاهي يعرف ماذا يطبخ ومتى',
    'بيتك وطبيبك على خطة واحدة',
  ];
  static const _subs = [
    'اختر نظامك الغذائي فتصلك وجبات كل يوم بأوقاتها.',
    'من وجبات الأسبوع إلى أصناف تشتريها، مع التكلفة التقديرية.',
    'تنبيه قبل الموعد وزر «حُضّرت» يطمئنك أن الوجبة جاهزة.',
    'ادعُ الطاهي والطبيب برابط واتساب، وكلٌّ يرى ما يخصه فقط.',
  ];

  @override
  Widget build(BuildContext context) {
    final last = _i == _beats - 1;
    return Scaffold(
      backgroundColor: Brand.green,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A7358), Brand.green, Color(0xFF123D2D)]),
        ),
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final w = MediaQuery.sizeOf(context).width;
              // RTL: الجهة اليمنى = التالي، واليسرى = السابق
              d.localPosition.dx > w / 2 ? _go(_i + 1) : _go(_i - 1);
            },
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(children: [
                  Expanded(
                    child: Row(children: [
                      for (var k = 0; k < _beats; k++)
                        Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                            child: AnimatedBuilder(
                              animation: _c,
                              builder: (_, _) => FractionallySizedBox(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: k < _i ? 1 : (k == _i ? _c.value : 0),
                                child: Container(decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(2))),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('تخطَّ', style: TextStyle(color: Brand.cream, fontWeight: black, fontSize: 15)),
                  ),
                ]),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: KeyedSubtree(
                    key: ValueKey(_i),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(
                        height: 290,
                        child: AnimatedBuilder(
                          animation: _c,
                          builder: (_, _) => switch (_i) {
                            0 => _MealsVisual(_c.value),
                            1 => _ShoppingVisual(_c.value),
                            2 => _CookVisual(_c.value),
                            _ => _HouseVisual(_c.value),
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(children: [
                          Text(_titles[_i], textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 28, height: 1.35, fontWeight: black, color: Colors.white)),
                          const SizedBox(height: 10),
                          Text(_subs[_i], textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, height: 1.7, color: Color(0xFFDCEBE3))),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: last ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !last,
                    child: Column(children: [
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: () => context.go('/login'),
                        child: const Text('ابدأ الآن', style: TextStyle(fontSize: 18, fontWeight: black)),
                      ),
                      TextButton(
                        onPressed: () => context.go('/browse'),
                        child: const Text('تصفّح الأنظمة بلا تسجيل', style: TextStyle(color: Brand.cream, fontWeight: black, decoration: TextDecoration.underline)),
                      ),
                    ]),
                  ),
                ),
              ),
              if (!last)
                const Padding(
                  padding: EdgeInsets.only(bottom: 22),
                  child: Text('المس الشاشة للتالي', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// مقطع من الزمن (0..1) إلى تقدّم محلي بمنحنى ناعم.
double _seg(double t, double from, double to) => Curves.easeOutCubic.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

Widget _card({required Widget child, double? w, Color color = Colors.white}) => Container(
      width: w,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6))]),
      child: child,
    );

/// 1) أربع وجبات تدخل واحدة بعد الأخرى وتُضاء علامة الإنجاز.
class _MealsVisual extends StatelessWidget {
  final double t;
  const _MealsVisual(this.t);
  static const _m = [('الفطور', '7:00 ص', Icons.wb_twilight), ('الغداء', '1:00 م', Icons.wb_sunny), ('السناك', '4:30 م', Icons.local_cafe), ('العشاء', '8:00 م', Icons.nights_stay)];
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var k = 0; k < 4; k++)
            Opacity(
              opacity: _seg(t, k * .15, k * .15 + .2),
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - _seg(t, k * .15, k * .15 + .2))),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _card(
                    child: Row(children: [
                      Icon(_m[k].$3, color: Brand.honey, size: 26),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_m[k].$1, style: const TextStyle(fontWeight: black, fontSize: 17))),
                      Text(_m[k].$2, style: const TextStyle(color: Brand.honey, fontWeight: black)),
                      const SizedBox(width: 10),
                      Transform.scale(
                        scale: _seg(t, .55 + k * .09, .7 + k * .09),
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
class _ShoppingVisual extends StatelessWidget {
  final double t;
  const _ShoppingVisual(this.t);
  static const _i = [('صدور دجاج', Icons.set_meal), ('خضار طازجة', Icons.eco), ('أرز', Icons.grain), ('زبادي', Icons.icecream)];
  @override
  Widget build(BuildContext context) {
    final total = (474 * _seg(t, .1, .85)).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var k = 0; k < 4; k++)
          Opacity(
            opacity: _seg(t, k * .13, k * .13 + .18),
            child: Transform.translate(
              offset: Offset(40 * (1 - _seg(t, k * .13, k * .13 + .18)), 0),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _card(
                  child: Row(children: [
                    Icon(_i[k].$2, color: Brand.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_i[k].$1,
                          style: TextStyle(fontWeight: black, fontSize: 16,
                              decoration: _seg(t, .5 + k * .1, .6 + k * .1) > .9 ? TextDecoration.lineThrough : null,
                              color: _seg(t, .5 + k * .1, .6 + k * .1) > .9 ? Colors.grey : null)),
                    ),
                    Icon(_seg(t, .5 + k * .1, .6 + k * .1) > .9 ? Icons.check_box : Icons.check_box_outline_blank, color: Brand.green),
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
class _CookVisual extends StatelessWidget {
  final double t;
  const _CookVisual(this.t);
  @override
  Widget build(BuildContext context) {
    final drop = _seg(t, .05, .3);
    final press = _seg(t, .55, .65);
    final ok = _seg(t, .7, .9);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Stack(alignment: Alignment.center, children: [
        Transform.translate(
          offset: Offset(0, -60 * (1 - drop)),
          child: Opacity(
            opacity: drop,
            child: Align(
              alignment: Alignment.topCenter,
              child: _card(
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
              child: _card(
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
class _HouseVisual extends StatelessWidget {
  final double t;
  const _HouseVisual(this.t);
  @override
  Widget build(BuildContext context) {
    final pulse = (1 + (t * 6).remainder(1.0)) * .5 + .5;
    Widget node(IconData i, String label, double from, {bool main = false}) => Opacity(
          opacity: _seg(t, from, from + .2),
          child: Transform.scale(
            scale: .6 + .4 * _seg(t, from, from + .2),
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
      CustomPaint(size: const Size(300, 270), painter: _LinesPainter(_seg(t, .3, .6), pulse)),
      Positioned(top: 8, child: node(Icons.home, 'صاحب الخطة', 0, main: true)),
      Positioned(bottom: 6, right: 40, child: node(Icons.restaurant, 'الطاهي', .2)),
      Positioned(bottom: 6, left: 40, child: node(Icons.medical_services, 'الطبيب', .35)),
    ]);
  }
}

class _LinesPainter extends CustomPainter {
  final double grow, pulse;
  _LinesPainter(this.grow, this.pulse);
  @override
  void paint(Canvas canvas, Size s) {
    final top = Offset(s.width / 2, 122), r = Offset(s.width - 74, s.height - 50), l = Offset(74, s.height - 50);
    final p = Paint()..color = Colors.white.withValues(alpha: .55 * grow)..strokeWidth = 3 * pulse..strokeCap = StrokeCap.round;
    canvas.drawLine(top, Offset.lerp(top, r, grow)!, p);
    canvas.drawLine(top, Offset.lerp(top, l, grow)!, p);
  }

  @override
  bool shouldRepaint(_LinesPainter o) => o.grow != grow || o.pulse != pulse;
}
