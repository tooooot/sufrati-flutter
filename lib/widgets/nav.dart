// التنقل: التفاصيل تُفتح فوق الصفحة (push) فيعيدك الرجوع إليها، و«go» لإعادة الضبط فقط (بعد دخول/خروج/تبديل دور).
// عند جذر التطبيق لا يخرج زر الرجوع فوراً: ضغطتان متتاليتان للخروج (وعلى التبويبات الأولى يرجع للرئيسية أولاً).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

extension AppNav on BuildContext {
  /// رجوع حقيقي إن كان فوق صفحة سابقة، وإلا إلى [fallback] (فتح مباشر لرابط عميق مثلاً).
  void back(String fallback) => canPop() ? pop() : go(fallback);
}

/// حارس الجذر: إن وُجدت صفحة سابقة رجع إليها، وإلا يعالج [onBack] أولاً (مثل العودة لتبويب «اليوم»)، ثم ضغطتان للخروج.
class ExitGuard extends StatefulWidget {
  final Widget child;
  final bool Function()? onBack;
  const ExitGuard({super.key, required this.child, this.onBack});

  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard> {
  DateTime? _last;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (context.canPop()) return context.pop();
          if (widget.onBack?.call() ?? false) return;
          final now = DateTime.now();
          if (_last != null && now.difference(_last!) < const Duration(seconds: 2)) {
            SystemNavigator.pop();
            return;
          }
          _last = now;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('اضغط الرجوع مرة أخرى للخروج'), duration: Duration(seconds: 2)));
        },
        child: widget.child,
      );
}
