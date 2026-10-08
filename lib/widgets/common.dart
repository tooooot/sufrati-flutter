import 'package:flutter/material.dart';

import '../theme.dart';

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
      padding: EdgeInsets.fromLTRB(16, top + 20, 16, 20),
      child: Stack(children: [
        Column(children: [
          Text(icon, style: const TextStyle(fontSize: 46)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: black)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 13)),
          ],
        ]),
        if (leading != null) Positioned(right: 0, top: 0, child: leading!),
      ]),
    );
  }
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
