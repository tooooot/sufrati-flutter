import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// زر الملف الشخصي داخل الترويسة (يتحرك مع الصفحة، فلا يغطي المحتوى عند التمرير).
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white24,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: 'ملفي الشخصي',
          icon: const Icon(Icons.account_circle, color: Colors.white, size: 30),
          onPressed: () => context.push('/profile'),
        ),
      );
}
