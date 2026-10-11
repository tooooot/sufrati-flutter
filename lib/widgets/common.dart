import 'package:flutter/material.dart';

import '../theme.dart';
import 'profile_button.dart';

/// الشريط الأخضر أعلى كل صفحة (مثل bg-brand-green في الموقع).
class GreenHeader extends StatelessWidget {
  final String icon, title;
  final String? subtitle;
  final Widget? leading;
  const GreenHeader({super.key, required this.icon, required this.title, this.subtitle, this.leading});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Brand.green, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)]),
      padding: EdgeInsets.fromLTRB(16, top + (leading == null ? 20 : 8), 16, 20),
      // الأزرار (رجوع/ملف شخصي/لغات) في صف مستقل أعلى الترويسة: لا تراكب مع الأيقونة مهما ضاقت الشاشة
      child: Column(children: [
        if (leading != null) Align(alignment: AlignmentDirectional.centerStart, child: leading!),
        Text(icon, style: const TextStyle(fontSize: 46)),
        const SizedBox(height: 4),
        Text(title, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: title.length > 18 ? 21 : 26, fontWeight: black)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 13)),
        ],
      ]),
    );
  }
}

/// ترويسة مدمجة (نحو 76 بكسل): عنوان التبويب الحالي وزر الحساب، بدل الترويسة الكبيرة المكررة.
class CompactHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const CompactHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Brand.green, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)]),
        padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 8, 12, 12),
        child: Row(children: [
          const ProfileButton(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: black)),
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 13)),
            ]),
          ),
          ?trailing,
        ]),
      );
}

class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Border? border;
  final VoidCallback? onTap;
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(16),
      this.color = Colors.white, this.border, this.onTap});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: child,
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

/// صورة طبق من الشبكة مع بديل هادئ أثناء التحميل/الفشل.
class DishPhoto extends StatelessWidget {
  final String url;
  final double? width, height;
  final double radius;
  const DishPhoto(this.url, {super.key, this.width, this.height, this.radius = 16});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(url, width: width, height: height, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(width: width, height: height, color: Brand.cream),
            loadingBuilder: (c, child, p) =>
                p == null ? child : Container(width: width, height: height, color: Brand.cream)),
      );
}
