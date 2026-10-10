import 'package:flutter/material.dart';

import '../data/growth.dart';
import '../theme.dart';
import 'intro_screen.dart';
import 'pitch_content.dart';

/// صفحة التسويق: `/p/<رمز>` (باسم الشخص ونوعه) و`/pitch/<نوع>?lang=` (معاينة) — عرض حركي ثم تسجيل.
/// عرض الطاهي يأتي بثلاث لغات (ar/en/am) مع أزرار لتبديلها.
class PitchScreen extends StatefulWidget {
  final GrowthService growth;
  final String? token, kind, lang;
  const PitchScreen({super.key, required this.growth, this.token, this.kind, this.lang});

  @override
  State<PitchScreen> createState() => _PitchScreenState();
}

class _PitchScreenState extends State<PitchScreen> {
  static const _cta = {'doctor': 'ابدأ بملفي المهني', 'group': 'ابدأ بملفي المهني'};
  late String _lang = pitchLangs.containsKey(widget.lang) ? widget.lang! : 'ar';

  @override
  Widget build(BuildContext context) {
    if (widget.token == null) return _show(widget.kind ?? 'user', '');
    return FutureBuilder<PitchLink?>(
      future: widget.growth.pitch(widget.token!),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(backgroundColor: Brand.green, body: Center(child: CircularProgressIndicator(color: Brand.cream)));
        }
        final l = snap.data;
        return _show(l?.kind ?? 'user', l?.name ?? ''); // رابط غير صالح: العرض العام بلا اسم
      },
    );
  }

  Widget _show(String kind, String name) {
    final cook = kind == 'cook';
    final c = chromeFor(cook ? _lang : 'ar');
    final screen = IntroScreen(
      key: ValueKey('$kind-$_lang'), // تبديل اللغة يعيد العرض من أوله
      beats: beatsFor(kind, name: name, lang: _lang),
      greeting: name.isEmpty ? null : 'أهلاً $name',
      ctaLabel: cook ? c.cta : (_cta[kind] ?? 'ابدأ الآن'),
      // الرابط الشخصي يُختم «سجّل» بعد الدخول عبر /r/<رمز>؛ الطاهي بعد الدخول يدخل رمز دعوته
      ctaRoute: cook ? '/login?next=${Uri.encodeComponent('/join/cook')}'
          : (widget.token == null ? '/login' : '/login?next=${Uri.encodeComponent('/r/${widget.token}')}'),
      skipLabel: c.skip,
      tapHint: c.tap,
      showBrowse: !cook,
      beatDuration: cook ? const Duration(milliseconds: 7000) : const Duration(milliseconds: 5200), // لغة ثانية ← وقت قراءة أطول
      header: cook
          ? Wrap(spacing: 8, children: [
              for (final e in pitchLangs.entries)
                GestureDetector(
                  onTap: () => setState(() => _lang = e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(color: _lang == e.key ? Brand.cream : const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(20)),
                    child: Text(e.value, style: TextStyle(fontWeight: black, fontSize: 15, color: _lang == e.key ? Brand.green : Colors.white)),
                  ),
                ),
            ])
          : null,
    );
    return cook ? Directionality(textDirection: c.rtl ? TextDirection.rtl : TextDirection.ltr, child: screen) : screen;
  }
}
