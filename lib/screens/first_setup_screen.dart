import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/roles.dart';
import '../data/links.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'household_screen.dart' show inviteFlow;
import 'patient_screen.dart' show WeekEditor;
import '../data/repository.dart';

/// بعد إنشاء البيت لأول مرة (أي نظام): مراجعة وجبات الأسبوع وتغيير ما لا يناسب ثم «موافق».
class WeekReviewScreen extends StatelessWidget {
  final HouseholdStore store;
  final Library library;
  const WeekReviewScreen({super.key, required this.store, required this.library});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          const GreenHeader(icon: '📋', title: 'راجع وجباتك', subtitle: 'غيّر أي وجبة لا تناسبك ثم اضغط «موافق»'),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [WeekEditor(store: store, library: library)]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(52)),
                onPressed: () => context.go('/cook-choice'),
                child: const Text('موافق', style: TextStyle(fontSize: 18, fontWeight: black)),
              ),
            ),
          ),
        ]),
      );
}

/// «من يطبخ؟»: بنفسي، أو دعوة طاهية برمز يُرسل بواتساب.
class CookChoiceScreen extends StatefulWidget {
  final LinkService links;
  const CookChoiceScreen({super.key, required this.links});

  @override
  State<CookChoiceScreen> createState() => _CookChoiceScreenState();
}

class _CookChoiceScreenState extends State<CookChoiceScreen> {
  bool _invited = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [
          const GreenHeader(icon: '👩‍🍳', title: 'من يطبخ؟', subtitle: 'يمكنك تغيير ذلك لاحقاً من تبويب «بيتي»'),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  CardBox(
                    onTap: () async {
                      await inviteFlow(context, widget.links, Role.cook);
                      if (mounted) setState(() => _invited = true);
                    },
                    child: const Row(children: [
                      Text('📨', style: TextStyle(fontSize: 38)),
                      SizedBox(width: 12),
                      Expanded(child: Text('أدعو طاهية أو طاهياً', style: TextStyle(fontWeight: black, fontSize: 17, color: Brand.green))),
                      Text('‹', style: TextStyle(fontSize: 22, color: Colors.grey)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  CardBox(
                    onTap: () => context.go('/me'),
                    child: const Row(children: [
                      Text('🏠', style: TextStyle(fontSize: 38)),
                      SizedBox(width: 12),
                      Expanded(child: Text('أطبخ بنفسي', style: TextStyle(fontWeight: black, fontSize: 17, color: Brand.green))),
                      Text('‹', style: TextStyle(fontSize: 22, color: Colors.grey)),
                    ]),
                  ),
                  if (_invited) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(52)),
                      onPressed: () => context.go('/me'),
                      child: const Text('متابعة', style: TextStyle(fontSize: 18, fontWeight: black)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ]),
      );
}
