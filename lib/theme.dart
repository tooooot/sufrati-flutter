import 'package:flutter/material.dart';

/// هوية سفرتي — نفس ألوان الموقع (base.html).
class Brand {
  static const green = Color(0xFF1F5A44);
  static const honey = Color(0xFFBF8630);
  static const cream = Color(0xFFFAF4E6);
  static const amber50 = Color(0xFFFFFBEB);
  static const grey = Color(0xFF4B5563); // أغمق من السابق لتباين أفضل على الكريمي
}

ThemeData sufratiTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: Brand.cream,
      colorScheme: ColorScheme.fromSeed(seedColor: Brand.green, primary: Brand.green, secondary: Brand.honey),
      textTheme: const TextTheme().apply(bodyColor: const Color(0xFF1F2937), fontFamilyFallback: const ['NotoBengali', 'NotoDevanagari', 'NotoEthiopic']),
    );

/// الثقيل للعناوين والأرقام الكبيرة فقط؛ الأسماء والتفاصيل w700 فما دون.
const black = FontWeight.w800;
