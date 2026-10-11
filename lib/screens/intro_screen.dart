import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import 'pitch_content.dart';

/// عرض الفكرة الحركي للزائر (على الجوال): أربع لقطات تتقدّم وحدها وبلمسة، وكل لقطة رسم متحرك بالكود. نفس روح مقدمة «مستشاري».
class IntroScreen extends StatefulWidget {
  /// لقطات العرض (الافتراضي: عرض مدير البيت)، وتحية اختيارية باسم الشخص، وزر الختام.
  final List<PitchBeat> beats;
  final String? greeting;
  final String ctaLabel;
  final String ctaRoute;
  /// نصوص الإطار (تخطَّ، المس للتالي): تتغير مع لغة العرض (عرض الطاهي بثلاث لغات).
  final String skipLabel, tapHint;
  /// تصفّح الأنظمة وروابط الخصوصية في الختام (تُخفى في عرض الطاهي).
  final bool showBrowse;
  /// شريط اختياري أعلى اللقطة (مثل أزرار اللغة).
  final Widget? header;
  /// مدة اللقطة (أطول للغة الثانية).
  final Duration beatDuration;
  IntroScreen({super.key, List<PitchBeat>? beats, this.greeting, this.ctaLabel = 'ابدأ الآن', this.ctaRoute = '/login',
      this.skipLabel = 'تخطَّ', this.tapHint = 'المس الشاشة للتالي', this.showBrowse = true, this.header, this.beatDuration = const Duration(milliseconds: 5200)})
      : beats = beats ?? beatsFor('user');

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  int get _beats => widget.beats.length;
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.beatDuration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && _i < _beats - 1) _go(_i + 1);
    });
  int _i = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // من فعّل «تقليل الحركة»: لا تقدّم تلقائي، ويتنقل بنفسه باللمس
    if (!_started) {
      _started = true;
      MediaQuery.of(context).disableAnimations ? _c.value = 1 : _c.forward();
    }
  }

  void _go(int i) {
    if (i < 0 || i >= _beats) return;
    setState(() => _i = i);
    MediaQuery.of(context).disableAnimations ? _c.value = 1 : _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Focus(
                autofocus: true,
                onKeyEvent: (_, e) {
                  if (e is! KeyDownEvent) return KeyEventResult.ignored;
                  final rtl = Directionality.of(context) == TextDirection.rtl;
                  final k = e.logicalKey;
                  if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter || k == (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight)) {
                    _go(_i + 1);
                  } else if (k == (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft)) {
                    _go(_i - 1);
                  } else {
                    return KeyEventResult.ignored;
                  }
                  return KeyEventResult.handled;
                },
                child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // اضغط مطولاً لإيقاف التقدّم (لقراءة بطيئة) وارفع إصبعك لاستئنافه
            onLongPressStart: (_) => _c.stop(),
            onLongPressEnd: (_) {
              if (!MediaQuery.of(context).disableAnimations && _i < _beats - 1) _c.forward();
            },
            onTapUp: (d) {
              final w = MediaQuery.sizeOf(context).width;
              // RTL: الجهة اليمنى = التالي، واليسرى = السابق
              final rtl = Directionality.of(context) == TextDirection.rtl;
              (rtl ? d.localPosition.dx > w / 2 : d.localPosition.dx < w / 2) ? _go(_i + 1) : _go(_i - 1);
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
                    child: Text(widget.skipLabel, style: const TextStyle(color: Brand.cream, fontWeight: black, fontSize: 15)),
                  ),
                ]),
              ),
              if (widget.header != null) Padding(padding: const EdgeInsets.only(top: 8), child: widget.header),
              if (widget.greeting != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(widget.greeting!, textAlign: TextAlign.center,
                      style: const TextStyle(color: Brand.cream, fontSize: 20, fontWeight: black)),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: KeyedSubtree(
                    key: ValueKey(_i),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(
                        height: 290,
                        child: AnimatedBuilder(animation: _c, builder: (_, _) => widget.beats[_i].visual(_c.value)),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(children: [
                          Text(widget.beats[_i].title, textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 28, height: 1.35, fontWeight: black, color: Colors.white)),
                          const SizedBox(height: 10),
                          Text(widget.beats[_i].sub, textAlign: TextAlign.center,
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
                        onPressed: () => context.go(widget.ctaRoute),
                        child: Text(widget.ctaLabel, style: TextStyle(fontSize: 18, fontWeight: black)),
                      ),
                      if (widget.showBrowse) ...[
                      TextButton(
                        onPressed: () => context.push('/browse'),
                        child: const Text('تصفّح الأنظمة بلا تسجيل', style: TextStyle(color: Brand.cream, fontWeight: black, decoration: TextDecoration.underline)),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        TextButton(
                          onPressed: () => launchUrl(Uri.parse('https://maeda.wardyat.net/privacy')),
                          child: const Text('سياسة الخصوصية', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                        TextButton(
                          onPressed: () => launchUrl(Uri.parse('https://maeda.wardyat.net/delete-account')),
                          child: const Text('حذف الحساب', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      ]),
                      ],
                    ]),
                  ),
                ),
              ),
              if (!last)
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Text(widget.tapHint, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
            ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

