import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/roles.dart';
import '../data/links.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/goal_card.dart';
import 'home_controls.dart';
import 'household_screen.dart';

/// تبويب «خطتي» (الشخصي) أو «بيتي» (الأسرة): الهدف، ثم الإعدادات، ثم الأشخاص المرتبطون.
class PlanTab extends StatelessWidget {
  final HouseholdStore store;
  final LinkService links;
  /// طبيب يعرض خطة مريضه: يرى الهدف والوجبات فقط.
  final bool specialist;
  final String who, programLabel;
  const PlanTab({super.key, required this.store, required this.links, this.specialist = false, this.who = '', this.programLabel = ''});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final h = store.household;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (h.personal) ...[
              GoalCard(store: store, isSpecialist: specialist, who: who, hasSpecialist: links.joinedBy(Role.doctor) != null),
              const SizedBox(height: 14),
              CardBox(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('وجباتي', style: TextStyle(fontSize: 17, fontWeight: black, color: Brand.green)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.restaurant_menu), label: const Text('إدارة وجباتي'), onPressed: () => showMealsManager(context, store))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.kitchen), label: const Text('عندي في البيت'), onPressed: () => showPantrySheet(context, store))),
                  ]),
                ]),
              ),
              if (!specialist) ...[
                const SizedBox(height: 14),
                // الربط (شريك/أخصائي/طاهٍ) اختياري للشخصي فلا يزاحم الهدف
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: ExpansionTile(
                      title: const Text('ربط أخصائي أو شريك أو طاهٍ', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('اختياري', style: TextStyle(fontSize: 13)),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [HouseholdBody(links: links, personal: true)],
                    ),
                  ),
                ),
              ],
            ] else ...[
              if (!specialist) ...[
                CardBox(
                  onTap: () => context.push('/cook/me'),
                  child: const Row(children: [
                    Icon(Icons.alarm, color: Brand.honey, size: 28),
                    SizedBox(width: 10),
                    Expanded(child: Text('شاشة الطبخ والتنبيهات (فك الدجاج، نقع الأرز…)', style: TextStyle(fontWeight: FontWeight.w700, height: 1.5))),
                    Icon(Icons.chevron_left, color: Brand.grey),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              HouseSettingsCard(store: store),
              const SizedBox(height: 14),
              HouseholdBody(links: links),
            ],
            const SizedBox(height: 14),
            if (!specialist) ...[
              CardBox(
                child: Row(children: [
                  const Icon(Icons.swap_horiz, color: Brand.green),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('النظام', style: TextStyle(fontSize: 13, color: Brand.grey)),
                    Text(programLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ])),
                  OutlinedButton(onPressed: () => context.push('/journey?update=1'), child: const Text('غيّر نظامي')),
                ]),
              ),
            ],
          ]);
        },
      );
}
