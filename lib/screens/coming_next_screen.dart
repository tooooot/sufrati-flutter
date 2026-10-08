import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// مكان التسجيل حتى المرحلة 2 (Firebase + الدخول بـ Google/Apple).
class ComingNextScreen extends StatelessWidget {
  final String title;
  const ComingNextScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [
          GreenHeader(icon: '🔐', title: title),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Text('التسجيل بحساب Google أو Apple يأتي في المرحلة 2',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: black, color: Brand.green)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => context.go('/'), child: const Text('‹ رجوع للأنظمة')),
            ]),
          ),
        ]),
      );
}
