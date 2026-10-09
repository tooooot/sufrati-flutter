import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../data/store.dart';
import '../logic/day_view.dart';
import '../logic/planner.dart';
import '../logic/prayer.dart';
import '../logic/shopping.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tabs_scaffold.dart';

/// لوحة المريض/صاحب البيت — نقل لـ user.html: الوجبات (اليوم/غداً) · المشتريات · الأسبوع القادم.
class PatientScreen extends StatelessWidget {
  final HouseholdStore store;
  final Library library;
  const PatientScreen({super.key, required this.store, required this.library});

  @override
  Widget build(BuildContext context) {
    final meta = library.meta(store.household.programId)!;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => TabsScaffold(
        programId: store.household.programId,
        header: GreenHeader(icon: meta.icon, title: 'سفرتي', subtitle: '${store.household.label} — ${meta.label}'),
        tabs: [
          TabItem('🍽️', 'الوجبات', (_) => _MealsTab(store: store, library: library)),
          TabItem('🛒', 'المشتريات', (_) => _ShoppingTab(store: store)),
          TabItem('📝', 'الأسبوع القادم', (_) => _NextWeekTab(store: store, library: library)),
        ],
      ),
    );
  }
}

class _MealsTab extends StatefulWidget {
  final HouseholdStore store;
  final Library library;
  const _MealsTab({required this.store, required this.library});
  @override
  State<_MealsTab> createState() => _MealsTabState();
}

class _MealsTabState extends State<_MealsTab> {
  bool tomorrow = false;

  @override
  Widget build(BuildContext context) {
    final now = saudiNow();
    final date = DateTime(now.year, now.month, now.day).add(Duration(days: tomorrow ? 1 : 0));
    return FutureBuilder(
      future: () async {
        final p = await widget.store.program();
        return (p, await dayView(widget.store, p, date));
      }(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Brand.green));
        final (Program program, DayView day) = snap.data!;
        final tip = program.userTips.isEmpty ? null : program.userTips[_ordinal(now) % program.userTips.length];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (tip != null)
            CardBox(
              border: Border.all(color: Brand.green.withValues(alpha: .15), width: 2),
              child: Row(children: [
                Text(tip['icon'] ?? '💡', style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('💡 هل تعلم؟', style: TextStyle(fontSize: 12, fontWeight: black, color: Brand.honey)),
                  Text(tip['text'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ])),
              ]),
            ),
          const SizedBox(height: 20),
          Row(children: [
            for (final (t, label) in [(false, '🗓️ اليوم'), (true, '⏭️ غدًا')]) ...[
              Expanded(child: _BigToggle(label: label, selected: tomorrow == t, onTap: () => setState(() => tomorrow = t))),
              if (!t) const SizedBox(width: 12),
            ],
          ]),
          const SizedBox(height: 20),
          Text(widget.library.dayNames[day.dayIndex], textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: black, color: Brand.green)),
          const SizedBox(height: 16),
          for (final s in day.slots) ...[
            _MealCard(s: s, program: program, library: widget.library, eaters: widget.store.household.eaters),
            const SizedBox(height: 16),
          ],
        ]);
      },
    );
  }
}

int _ordinal(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1, 1, 1)).inDays + 1;

class _BigToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BigToggle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? Brand.green : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Brand.green, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6)],
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: black, color: selected ? Colors.white : Brand.green)),
        ),
      );
}

class _MealCard extends StatelessWidget {
  final SlotView s;
  final Program program;
  final Library library;
  final int eaters;
  const _MealCard({required this.s, required this.program, required this.library, required this.eaters});

  @override
  Widget build(BuildContext context) {
    final photo = s.option == null ? null : library.photoUrl(program.meta.id, s.option!.id);
    return CardBox(
      padding: const EdgeInsets.all(20),
      border: Border.all(color: Brand.honey.withValues(alpha: .3), width: 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(s.slot.icon, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 8),
          Expanded(child: Text(s.slot.name, style: const TextStyle(fontSize: 22, fontWeight: black, color: Brand.green))),
          Text('🕐 ${ar12(s.time)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Brand.honey)),
        ]),
        const SizedBox(height: 8),
        if (photo != null) ...[DishPhoto(photo, width: double.infinity, height: 160), const SizedBox(height: 12)],
        Text(s.option?.label ?? '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final it in scaledItems(s.option, eaters, program.ingredients)) _Chip(it.icon, it.qtyLabel, it.label),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String icon, qty, label;
  const _Chip(this.icon, this.qty, this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(12)),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$icon ', style: const TextStyle(fontSize: 20)),
          TextSpan(text: '$qty ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          TextSpan(text: label, style: const TextStyle(fontSize: 16, color: Color(0xFF4B5563))),
        ])),
      );
}

class _ShoppingTab extends StatelessWidget {
  final HouseholdStore store;
  const _ShoppingTab({required this.store});

  @override
  Widget build(BuildContext context) {
    final now = saudiNow();
    final thisWeek = weekStartFor(now);
    final nextWeek = thisWeek.add(const Duration(days: 7));
    final h = store.household;
    final locked = isLocked(thisWeek, now, h.cutoffDay, h.cutoffTime);
    return FutureBuilder(
      future: () async {
        return (await store.program(), await store.shopping(thisWeek), await store.shopping(nextWeek));
      }(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Brand.green));
        final (program, linesThis, linesNext) = snap.data!;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!locked)
            Text('يمكنك تعديل مشتريات هذا الأسبوع حتى مساء ${const ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'][h.cutoffDay]} الساعة ${ar12(h.cutoffTime)}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Brand.grey)),
          const SizedBox(height: 8),
          _ShoppingCard(title: '🛒 مشترياتك — هذا الأسبوع', week: thisWeek, lines: linesThis, locked: locked,
              program: program, store: store),
          const SizedBox(height: 24),
          _ShoppingCard(title: '🛒 مشترياتك — الأسبوع القادم', week: nextWeek, lines: linesNext, locked: false,
              program: program, store: store),
        ]);
      },
    );
  }
}

class _ShoppingCard extends StatelessWidget {
  final String title;
  final DateTime week;
  final List lines;
  final bool locked;
  final Program program;
  final HouseholdStore store;
  const _ShoppingCard({required this.title, required this.week, required this.lines, required this.locked,
      required this.program, required this.store});

  @override
  Widget build(BuildContext context) => CardBox(
        padding: const EdgeInsets.all(20),
        border: Border.all(color: Brand.honey.withValues(alpha: .3), width: 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: black, color: Brand.green)),
          if (locked)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Brand.honey.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
              child: const Text('🔒 القائمة مُقفلة وجاهزة للشراء',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Brand.honey)),
            ),
          const SizedBox(height: 8),
          for (final l in lines)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.cream))),
              child: Row(children: [
                Text(program.ingredients[l.key]!.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(program.ingredients[l.key]!.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(program.ingredients[l.key]!.buyUnit, style: const TextStyle(fontSize: 13, color: Brand.grey)),
                ])),
                if (locked)
                  Text('× ${l.packs}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                else ...[
                  _Step('−', l.packs > 0 ? () => store.updateShopping(week, l.key, packs: l.packs - 1) : null),
                  SizedBox(width: 32, child: Text('${l.packs}', textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  _Step('+', () => store.updateShopping(week, l.key, packs: l.packs + 1)),
                  Column(children: [
                    Checkbox(value: l.bought, activeColor: Brand.green,
                        onChanged: (v) => store.updateShopping(week, l.key, bought: v ?? false)),
                    const Text('تم', style: TextStyle(fontSize: 11)),
                  ]),
                ],
              ]),
            ),
        ]),
      );
}

class _NextWeekTab extends StatelessWidget {
  final HouseholdStore store;
  final Library library;
  const _NextWeekTab({required this.store, required this.library});

  @override
  Widget build(BuildContext context) {
    final nextWeek = weekStartFor(saudiNow()).add(const Duration(days: 7));
    return FutureBuilder(
      future: () async {
        return (await store.program(), await store.week(nextWeek));
      }(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Brand.green));
        final (program, plan) = snap.data!;
        return CardBox(
          padding: const EdgeInsets.all(20),
          border: Border.all(color: Brand.honey.withValues(alpha: .3), width: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('📝 تعديل خطة الأسبوع القادم',
                style: TextStyle(fontSize: 22, fontWeight: black, color: Brand.green)),
            const Text('اضغط على اليوم لتغيير أي وجبة قبل أن تبدأ مشتريات ذلك الأسبوع',
                style: TextStyle(fontSize: 13, color: Brand.grey)),
            const SizedBox(height: 12),
            for (var d = 0; d < 7; d++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(12)),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(library.dayNames[d],
                        style: const TextStyle(fontSize: 18, fontWeight: black, color: Brand.green)),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: [
                      for (final slot in program.slots)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Text(slot.icon, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: plan.days[d][slot.id],
                                decoration: const InputDecoration(filled: true, fillColor: Colors.white,
                                    isDense: true, border: OutlineInputBorder()),
                                items: [
                                  for (final o in slot.options)
                                    DropdownMenuItem(value: o.id, child: Text(o.label, style: const TextStyle(fontSize: 14))),
                                ],
                                onChanged: (v) => v == null ? null : store.setOption(nextWeek, d, slot.id, v),
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}


/// زر − / + نصي (لا يعتمد على خط الأيقونات).
class _Step extends StatelessWidget {
  final String sign;
  final VoidCallback? onTap;
  const _Step(this.sign, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: onTap == null ? Colors.grey.shade300 : Brand.green, width: 2)),
          child: Text(sign, style: TextStyle(fontSize: 20, fontWeight: black, height: 1,
              color: onTap == null ? Colors.grey.shade400 : Brand.green)),
        ),
      );
}
