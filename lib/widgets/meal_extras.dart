import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../theme.dart';

/// زر «شاهدي طريقة الطبخة»: يفتح بحث تيك توك عن الوجبة (رابط بحث لا يموت، فلا نعتمد على فيديو بعينه).
class MealVideoButton extends StatelessWidget {
  final MealOption option;
  final String lang;
  const MealVideoButton({super.key, required this.option, this.lang = 'ar'});

  static const _label = {'ar': 'شاهدي طريقة الطبخة', 'en': 'Watch how to cook it', 'am': 'አሰራሩን ይመልከቱ'};

  @override
  Widget build(BuildContext context) {
    final u = option.videoUrl;
    if (u == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: const BorderSide(color: Brand.honey, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        icon: const Icon(Icons.play_circle_fill, color: Brand.honey),
        label: Text(_label[lang] ?? _label['ar']!, style: const TextStyle(color: Brand.honey, fontWeight: black, fontSize: 16)),
        onPressed: () => launchUrl(u, mode: LaunchMode.externalApplication),
      ),
    );
  }
}

/// تذكيرات الوجبة بصيغة مقروءة: «قبل 14 ساعة: أخرجي الدجاج…» (التنبيهات الفعلية تصل الطاهية من شاشتها).
class MealReminders extends StatelessWidget {
  final MealOption option;
  const MealReminders({super.key, required this.option});

  static String _when(double h) => h >= 24 ? 'قبل ${(h / 24).round()} يوم' : (h == h.roundToDouble() ? 'قبل ${h.round()} ساعة' : 'قبل ${h.toStringAsFixed(1)} ساعة');

  @override
  Widget build(BuildContext context) {
    if (option.remind.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Brand.amber50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Brand.honey.withValues(alpha: .6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('⏰ تذكيرات هذه الوجبة', style: TextStyle(fontWeight: black, color: Brand.green)),
        const SizedBox(height: 6),
        for (final r in option.remind)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${_when(r.hoursBefore)}: ${r.text}', style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}
