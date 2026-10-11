import 'package:flutter/material.dart';

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
  final String who;
  const PlanTab({super.key, required this.store, required this.links, this.specialist = false, this.who = ''});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final h = store.household;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (h.personal) ...[
              GoalCard(store: store, isSpecialist: specialist, who: who),
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
                      subtitle: const Text('اختياري', style: TextStyle(fontSize: 12.5)),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [HouseholdBody(links: links, personal: true)],
                    ),
                  ),
                ),
              ],
            ] else ...[
              HouseSettingsCard(store: store),
              const SizedBox(height: 14),
              HouseholdBody(links: links),
            ],
          ]);
        },
      );
}
