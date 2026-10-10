import 'package:flutter/material.dart';

import '../data/growth.dart';
import '../theme.dart';
import 'intro_screen.dart';
import 'pitch_content.dart';

/// صفحة التسويق: `/p/<رمز>` (باسم الشخص ونوعه) و`/pitch/<نوع>` (معاينة بلا اسم) — عرض حركي ثم تسجيل.
class PitchScreen extends StatelessWidget {
  final GrowthService growth;
  final String? token, kind;
  const PitchScreen({super.key, required this.growth, this.token, this.kind});

  static const _cta = {'doctor': 'ابدأ بملفي المهني', 'group': 'ابدأ وانشر رابطي'};

  @override
  Widget build(BuildContext context) {
    if (token == null) return _show(kind ?? 'user', '');
    return FutureBuilder<PitchLink?>(
      future: growth.pitch(token!),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(backgroundColor: Brand.green, body: Center(child: CircularProgressIndicator(color: Brand.cream)));
        }
        final l = snap.data;
        return _show(l?.kind ?? 'user', l?.name ?? ''); // رابط غير صالح: العرض العام بلا اسم
      },
    );
  }

  Widget _show(String kind, String name) => IntroScreen(
        beats: beatsFor(kind, name: name),
        greeting: name.isEmpty ? null : 'أهلاً $name',
        ctaLabel: _cta[kind] ?? 'ابدأ الآن',
      );
}
