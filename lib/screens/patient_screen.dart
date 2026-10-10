import 'package:flutter/material.dart';

import '../data/household.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/store.dart';
import '../logic/day_view.dart';
import '../logic/planner.dart';
import '../logic/prayer.dart';
import '../logic/shopping.dart';
import '../theme.dart';
import '../logic/dates.dart';
import '../widgets/common.dart';
import '../widgets/profile_button.dart';
import '../widgets/tabs_scaffold.dart';
import '../auth/roles.dart';
import '../data/links.dart';
import 'household_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// لوحة المريض/صاحب الخطة — نقل لـ user.html: الوجبات (اليوم/غداً) · المشتريات · الأسبوع القادم.
class PatientScreen extends StatefulWidget {
  final HouseholdStore store;
  final Library library;
  final LinkService links;
  final String userName;
  /// صاحب الخطة فقط يرى تبويب «بيتي» ويدعو؛ الطبيب يرى الخطة والمشتريات والأسبوع.
  final bool showHome;
  const PatientScreen({super.key, required this.store, required this.library, required this.links,
      this.userName = '', this.showHome = true});

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  final _tabs = TabsController();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final meta = widget.library.meta(store.household.programId)!;
    final now = saudiNow();
    final today = DateTime(now.year, now.month, now.day);
    final dayName = widget.library.dayNames[today.difference(weekStartFor(today)).inDays];
    final first = widget.userName.trim().split(' ').first;
    final greeting = now.hour < 12 ? 'صباح الخير' : 'مساء الخير';
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => TabsScaffold(
        controller: _tabs,
        programId: store.household.programId,
        header: GreenHeader(
          icon: meta.icon,
          title: first.isEmpty ? greeting : '$greeting، $first',
          subtitle: '$dayName · ${arDate(today)}',
          leading: Row(children: [
            const ProfileButton(),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
              child: Text(meta.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: black)),
            ),
          ]),
        ),
        tabs: [
          TabItem(Icons.restaurant_menu, 'اليوم',
              (_) => _TodayTab(store: store, library: widget.library, links: widget.links, tabs: _tabs, canInvite: widget.showHome)),
          TabItem(Icons.shopping_cart_outlined, 'المشتريات', (_) => _ShoppingTab(store: store)),
          TabItem(Icons.calendar_month_outlined, 'الأسبوع', (_) => _NextWeekTab(store: store, library: widget.library)),
          if (widget.showHome) TabItem(Icons.home_outlined, 'بيتي', (_) => HouseholdBody(links: widget.links)),
        ],
      ),
    );
  }
}

class _TodayTab extends StatefulWidget {
  final HouseholdStore store;
  final Library library;
  final LinkService links;
  final TabsController tabs;
  final bool canInvite;
  const _TodayTab({required this.store, required this.library, required this.links, required this.tabs, required this.canInvite});
  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab> {
  bool tomorrow = false;

  @override
  Widget build(BuildContext context) {
    final now = saudiNow();
    final date = DateTime(now.year, now.month, now.day).add(Duration(days: tomorrow ? 1 : 0));
    final thisWeek = weekStartFor(DateTime(now.year, now.month, now.day));
    return FutureBuilder(
      future: () async {
        final p = await widget.store.program();
        return (p, await dayView(widget.store, p, date), await widget.store.shopping(thisWeek));
      }(),
      builder: (context, snap) {
        if (snap.hasError) return Text('${snap.error}', textAlign: TextAlign.center);
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Brand.green)));
        final (Program program, DayView day, List<ShoppingLine> lines) = snap.data!;
        final next = tomorrow ? null : _nextSlot(day, now);
        final doneCount = day.slots.where((x) => x.prepared).length;
        final eaters = widget.store.household.eaters;
        final tip = program.userTips.isEmpty ? null : program.userTips[_ordinal(now) % program.userTips.length];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!tomorrow)
            next != null
                ? _NextMealHero(s: next, program: program, library: widget.library, eaters: eaters, now: now)
                : _DayDoneHero(done: doneCount, total: day.slots.length),
          const SizedBox(height: 14),
          Row(children: [
            _Quick(Icons.person_add_alt_1, 'دعوة الطاهي', widget.canInvite ? () => inviteFlow(context, widget.links, Role.cook) : null),
            const SizedBox(width: 10),
            _Quick(Icons.ios_share, 'شارك المشتريات', () => _shareShopping(program, lines)),
            const SizedBox(width: 10),
            _Quick(Icons.autorenew, 'تعديل الأسبوع', () => widget.tabs.select(2)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Text(tomorrow ? 'وجبات الغد' : 'وجبات اليوم',
                style: const TextStyle(fontSize: 19, fontWeight: black, color: Brand.green))),
            if (!tomorrow)
              Text('حُضّرت $doneCount من ${day.slots.length}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Brand.honey)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            for (final (t, label) in [(false, 'اليوم'), (true, 'غدًا')]) ...[
              Expanded(child: _BigToggle(label: label, selected: tomorrow == t, onTap: () => setState(() => tomorrow = t))),
              if (!t) const SizedBox(width: 10),
            ],
          ]),
          const SizedBox(height: 12),
          for (final s in day.slots) ...[
            _MealRow(s: s, isNext: identical(s, next), onTap: () => _showMeal(context, s, program, eaters)),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          _ShoppingSummary(lines: lines, onTap: () => widget.tabs.select(1)),
          if (tip != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Brand.green.withValues(alpha: .15))),
              child: Row(children: [
                Text(tip['icon'] ?? '💡', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(child: Text(tip['text'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151), height: 1.5))),
              ]),
            ),
          ],
        ]);
      },
    );
  }

  void _showMeal(BuildContext context, SlotView s, Program program, int eaters) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Brand.cream,
        builder: (_) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: _MealCard(s: s, program: program, library: widget.library, eaters: eaters),
        ),
      );

  Future<void> _shareShopping(Program program, List<ShoppingLine> lines) async {
    final todo = lines.where((l) => !l.bought).map((l) {
      final ing = program.ingredients[l.key]!;
      return '• ${ing.label} × ${l.packs} (${ing.buyUnit})';
    }).join('\n');
    final text = 'مشتريات هذا الأسبوع من سفرتي:\n$todo';
    await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  }
}

/// الوجبة القادمة: البطاقة الكبيرة الوحيدة في أعلى «اليوم».
class _NextMealHero extends StatelessWidget {
  final SlotView s;
  final Program program;
  final Library library;
  final int eaters;
  final DateTime now;
  const _NextMealHero({required this.s, required this.program, required this.library, required this.eaters, required this.now});

  @override
  Widget build(BuildContext context) {
    final photo = s.option == null ? null : library.photoUrl(program.meta.id, s.option!.id);
    final hm = s.time.split(':').map(int.parse).toList();
    final diff = hm[0] * 60 + hm[1] - (now.hour * 60 + now.minute);
    final when = diff <= 0 ? 'حان وقتها' : diff < 60 ? 'بعد $diff دقيقة' : 'بعد ${diff ~/ 60} ساعة';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Brand.honey, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 22, offset: Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (photo != null) DishPhoto(photo, width: double.infinity, height: 150),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(color: Brand.honey, borderRadius: BorderRadius.circular(12)),
                child: const Text('الوجبة القادمة', style: TextStyle(fontSize: 12, fontWeight: black, color: Colors.white)),
              ),
              const Spacer(),
              Text('$when · ${ar12(s.time)}', style: const TextStyle(fontSize: 15, fontWeight: black, color: Brand.honey)),
            ]),
            const SizedBox(height: 8),
            Text(s.option?.label ?? '—', style: const TextStyle(fontSize: 21, fontWeight: black)),
            const SizedBox(height: 2),
            Text('${s.slot.name} · لـ$eaters', style: const TextStyle(fontSize: 14, color: Brand.grey)),
          ]),
        ),
      ]),
    );
  }
}

class _DayDoneHero extends StatelessWidget {
  final int done, total;
  const _DayDoneHero({required this.done, required this.total});
  @override
  Widget build(BuildContext context) => CardBox(
        color: Brand.green,
        child: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('انتهت وجبات اليوم', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: black)),
            Text('حُضّرت $done من $total — نراك غدًا', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ])),
        ]),
      );
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Quick(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Opacity(
          opacity: onTap == null ? .4 : 1,
          child: CardBox(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Brand.green.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Brand.green, size: 22),
              ),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Brand.green, height: 1.3)),
            ]),
          ),
        ),
      );
}

class _MealRow extends StatelessWidget {
  final SlotView s;
  final bool isNext;
  final VoidCallback onTap;
  const _MealRow({required this.s, required this.isNext, required this.onTap});
  @override
  Widget build(BuildContext context) => CardBox(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: isNext ? Border.all(color: Brand.honey, width: 2) : null,
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: s.prepared ? Brand.green : Brand.honey.withValues(alpha: .18)),
            child: Icon(s.prepared ? Icons.check : Icons.schedule, size: 18, color: s.prepared ? Colors.white : Brand.honey),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.slot.name, style: const TextStyle(fontSize: 16, fontWeight: black)),
            Text(s.option?.label ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Brand.grey)),
          ])),
          Text(ar12(s.time), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Brand.honey)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_left, color: Colors.grey, size: 20),
        ]),
      );
}

class _ShoppingSummary extends StatelessWidget {
  final List<ShoppingLine> lines;
  final VoidCallback onTap;
  const _ShoppingSummary({required this.lines, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final done = lines.where((l) => l.bought).length;
    final total = lines.fold<double>(0, (a, l) => a + l.packs * l.unitPrice);
    return CardBox(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('مشتريات هذا الأسبوع', style: TextStyle(fontSize: 17, fontWeight: black, color: Brand.green)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: lines.isEmpty ? 0 : done / lines.length, minHeight: 10,
            color: Brand.green, backgroundColor: Brand.green.withValues(alpha: .12),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('اشتريت $done من ${lines.length}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Brand.grey)),
          const Spacer(),
          Text('التكلفة التقديرية ${total.toStringAsFixed(0)} ر.س',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Brand.grey)),
        ]),
      ]),
    );
  }
}

/// الوجبة القادمة اليوم: أول وجبة وقتها لم يحن بعد وليست محضَّرة.
SlotView? _nextSlot(DayView day, DateTime now) {
  for (final s in day.slots) {
    if (s.prepared) continue;
    final hm = s.time.split(':').map(int.parse).toList();
    if (hm[0] * 60 + hm[1] >= now.hour * 60 + now.minute) return s;
  }
  return null;
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Brand.green : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Brand.green, width: 2),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: black, color: selected ? Colors.white : Brand.green)),
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
        if (s.prepared)
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('✅ حُضّرت', style: TextStyle(fontWeight: black, color: Brand.green))),
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

/// أقسام المشتريات بترتيب عرضها (مفتاح التصنيف في بيانات الأنظمة ← الاسم).
const _shopCats = {
  'meat': 'لحوم وأسماك',
  'dairy': 'ألبان وبيض',
  'veg': 'خضار',
  'fruit': 'فواكه',
  'grain': 'حبوب ونشويات ومخبوزات',
  'fat': 'دهون ومكسرات',
  'other': 'أخرى',
};

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
          Builder(builder: (_) {
            final total = lines.fold<double>(0, (a, l) => a + l.packs * l.unitPrice);
            final done = lines.where((l) => l.bought).length;
            return Text('اشتريت $done من ${lines.length} · التكلفة التقديرية ${total.toStringAsFixed(0)} ر.س',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Brand.grey));
          }),
          const SizedBox(height: 4),
          for (final cat in _shopCats.keys) ...[
            if (lines.any((l) => program.ingredients[l.key]!.category == cat))
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 2),
                child: Text(_shopCats[cat]!, style: const TextStyle(fontWeight: FontWeight.w900, color: Brand.green, fontSize: 15)),
              ),
            for (final l in ([...lines.where((l) => program.ingredients[l.key]!.category == cat)]..sort((a, b) => a.bought == b.bought ? 0 : (a.bought ? 1 : -1))))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.cream))),
              child: Row(children: [
                Text(program.ingredients[l.key]!.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(program.ingredients[l.key]!.label, style: TextStyle(fontWeight: FontWeight.bold, decoration: l.bought ? TextDecoration.lineThrough : null, color: l.bought ? Brand.grey : null)),
                  Text(program.ingredients[l.key]!.buyUnit, style: const TextStyle(fontSize: 13, color: Brand.grey)),
                ])),
                if (locked) ...[
                  Text('× ${l.packs}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Column(children: [
                    Checkbox(value: l.bought, activeColor: Brand.green,
                        onChanged: (v) => store.updateShopping(week, l.key, bought: v ?? false)),
                    const Text('تم', style: TextStyle(fontSize: 11)),
                  ]),
                ] else ...[
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
          ],
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
            Text('اضغط على اليوم لتغيير أي وجبة. تُقفل المشتريات مساء ${const ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'][store.household.cutoffDay]} الساعة ${ar12(store.household.cutoffTime)}.',
                style: const TextStyle(fontSize: 13, color: Brand.grey, height: 1.6)),
            const SizedBox(height: 12),
            for (var d = 0; d < 7; d++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(12)),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text('${library.dayNames[d]} · ${arDate(nextWeek.add(Duration(days: d)))}',
                        style: const TextStyle(fontSize: 17, fontWeight: black, color: Brand.green)),
                    subtitle: Text([
                      for (final slot in program.slots)
                        slot.options.where((o) => o.id == plan.days[d][slot.id]).firstOrNull?.label ?? '',
                    ].where((t) => t.isNotEmpty).join(' · '),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Brand.grey)),
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
