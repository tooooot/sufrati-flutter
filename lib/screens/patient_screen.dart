import 'package:flutter/material.dart';

import '../data/household.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/store.dart';
import '../logic/calories.dart';
import '../logic/day_view.dart';
import '../logic/planner.dart';
import '../logic/prayer.dart';
import '../logic/shopping.dart';
import '../theme.dart';
import '../logic/dates.dart';
import '../widgets/common.dart';
import '../logic/names.dart';
import '../widgets/meal_extras.dart';
import 'home_controls.dart';
import '../widgets/tabs_scaffold.dart';
import 'plan_tab.dart';
import '../data/links.dart';

/// لوحة المريض/مدير البيت — نقل لـ user.html: الوجبات (اليوم/غداً) · المشتريات · الأسبوع القادم.
class PatientScreen extends StatefulWidget {
  final HouseholdStore store;
  final Library library;
  final LinkService links;
  final String userName;
  /// مدير البيت فقط يرى تبويب «بيتي» ويدعو؛ الطبيب يرى الخطة والمشتريات والأسبوع.
  final bool showHome;
  const PatientScreen({super.key, required this.store, required this.library, required this.links,
      this.userName = '', this.showHome = true});

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  final _tabs = TabsController();

  @override
  void initState() {
    super.initState();
    // أول فتح لخطة شخصية: نعاير الحصة على أسبوعه الفعلي ليوافق مجموع يومه هدفه (مرة واحدة)
    final h = widget.store.household;
    if (widget.showHome && h.personal && h.target != null && h.target!['calibrated'] != true) {
      widget.store.calibrateToTarget().catchError((_) {});
    }
  }

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
    final first = firstName(widget.userName);
    final greeting = now.hour < 12 ? 'صباح الخير' : 'مساء الخير';
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final h = store.household;
        final personal = h.personal;
        final chip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
          child: Text(meta.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        );
        final planLabel = personal ? 'خطتي' : 'بيتي';
        return TabsScaffold(
          controller: _tabs,
          programId: h.programId,
          tabHeader: (i, label) => CompactHeader(
            title: i == 0 ? (first.isEmpty ? greeting : '$greeting، $first') : label,
            subtitle: i == 0 ? '$dayName · ${arDate(today)}' : null,
            trailing: i == 0 ? chip : null,
          ),
          tabs: [
            TabItem(Icons.restaurant_menu, 'اليوم',
                (_) => _TodayTab(store: store, library: widget.library, links: widget.links, tabs: _tabs, canInvite: widget.showHome, specialist: !widget.showHome)),
            TabItem(Icons.shopping_cart_outlined, 'المشتريات', (_) => _ShoppingTab(store: store)),
            TabItem(Icons.calendar_month_outlined, 'الأسبوع', (_) => _NextWeekTab(store: store, library: widget.library)),
            if (widget.showHome || personal)
              TabItem(personal ? Icons.flag_outlined : Icons.home_outlined, planLabel,
                  (_) => PlanTab(store: store, links: widget.links, specialist: !widget.showHome, who: widget.userName, programLabel: meta.label)),
          ],
        );
      },
    );
  }
}

class _TodayTab extends StatefulWidget {
  final HouseholdStore store;
  final Library library;
  final LinkService links;
  final TabsController tabs;
  final bool canInvite, specialist;
  const _TodayTab({required this.store, required this.library, required this.links, required this.tabs, required this.canInvite, this.specialist = false});
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
        final personal = widget.store.household.personal;
        final eaters = widget.store.household.eaters;
        final servings = widget.store.household.servings;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (personal && widget.store.household.targetKcal > 0) ...[
            _DayRing(program: program, day: day, portion: widget.store.household.portion, target: widget.store.household.target!, tomorrow: tomorrow),
            const SizedBox(height: 14),
          ],
          Row(children: [
            for (final (t, label) in [(false, 'اليوم'), (true, 'غدًا')]) ...[
              Expanded(child: _BigToggle(label: label, selected: tomorrow == t, onTap: () => setState(() => tomorrow = t))),
              if (!t) const SizedBox(width: 10),
            ],
          ]),
          const SizedBox(height: 14),
          for (final s in day.slots) ...[
            _MealTile(
              s: s, program: program, library: widget.library, isNext: identical(s, next), people: eaters,
              onTap: () => _showMeal(context, s, program, servings, day),
              kcal: personal && s.option != null ? optionNutri(program, s.option!, portion: widget.store.household.portion).total.kcal : null,
              onToggle: personal && !tomorrow ? () => widget.store.setPrepared(day.weekStart, day.dayIndex, s.slot.id, !s.prepared) : null,
            ),
            const SizedBox(height: 12),
          ],
        ]);
      },
    );
  }

  /// الوجبة بصفحة كاملة: صورة كبيرة، المقادير، التذكيرات، طريقة التحضير، الفيديو.
  void _showMeal(BuildContext context, SlotView s, Program program, double servings, DayView day) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Brand.cream,
          appBar: AppBar(
            backgroundColor: Brand.green, foregroundColor: Colors.white,
            title: Text('${s.slot.icon} ${s.slot.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: _MealCard(s: s, program: program, library: widget.library, servings: servings, portion: widget.store.household.portion, photoHeight: 240,
                    actions: widget.canInvite && s.option != null
                        ? MealActions(store: widget.store, weekStart: day.weekStart, day: day.dayIndex, slotId: s.slot.id, option: s.option!)
                        : null),
              ),
            ),
          ),
        ),
      ));

}

/// الوجبة القادمة: البطاقة الكبيرة الوحيدة في أعلى «اليوم».
String forPeople(int n) => n == 1 ? 'لشخص واحد' : n == 2 ? 'لشخصين' : n <= 10 ? 'لـ$n أشخاص' : 'لـ$n شخصاً';

/// حلقة السعرات: ما أُكل (الوجبات المعلَّمة) من هدف اليوم، وتحتها البروتين والكربوهيدرات والدهون.
class _DayRing extends StatelessWidget {
  final Program program;
  final DayView day;
  final double portion;
  final Map<String, dynamic> target;
  final bool tomorrow;
  const _DayRing({required this.program, required this.day, required this.portion, required this.target, required this.tomorrow});

  @override
  Widget build(BuildContext context) {
    var eaten = Nutri.zero, planned = Nutri.zero;
    for (final s in day.slots) {
      if (s.option == null) continue;
      final n = optionNutri(program, s.option!, portion: portion).total;
      planned = planned + n;
      if (s.prepared) eaten = eaten + n;
    }
    final goal = (target['kcal'] as num).toDouble();
    final shown = tomorrow ? planned : eaten;
    final left = goal - shown.kcal;
    final bars = [
      ('بروتين', shown.p, (target['proteinG'] as num?)?.toDouble() ?? 0),
      ('كارب', shown.c, (target['carbG'] as num?)?.toDouble() ?? 0),
      ('دهون', shown.f, (target['fatG'] as num?)?.toDouble() ?? 0),
    ];
    return CardBox(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          SizedBox(
            width: 68, height: 68,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 68, height: 68,
                child: CircularProgressIndicator(value: (shown.kcal / goal).clamp(0, 1).toDouble(), strokeWidth: 8,
                    backgroundColor: Brand.green.withValues(alpha: .1), color: left < 0 ? Brand.honey : Brand.green),
              ),
              Text('${shown.kcal.round()}', style: const TextStyle(fontSize: 16, fontWeight: black)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tomorrow ? 'خطة الغد ≈ ${planned.kcal.round()} سعرة' : (left >= 0 ? 'متبقٍّ ${left.round()} من ${goal.round()} سعرة' : 'تجاوزتَ بـ${(-left).round()} سعرة'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Brand.green)),
              if (!tomorrow) Text('مخطط اليوم كله ≈ ${planned.kcal.round()}', style: const TextStyle(fontSize: 13, color: Brand.grey)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          for (final (l, v, g) in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(children: [
                  Text('$l ${v.round()}/${g.round()}', style: const TextStyle(fontSize: 13, color: Brand.grey)),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: g <= 0 ? 0 : (v / g).clamp(0, 1).toDouble(), minHeight: 6,
                        backgroundColor: Brand.green.withValues(alpha: .1), color: Brand.honey),
                  ),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// تقدير سعرات الفرد البالغ لهذه الوجبة بحصة بيته (تقدير حتى يعتمده الأخصائي).
class _NutriLine extends StatelessWidget {
  final Program program;
  final MealOption option;
  final double portion;
  const _NutriLine({required this.program, required this.option, required this.portion});
  @override
  Widget build(BuildContext context) {
    final r = optionNutri(program, option, portion: portion);
    if (r.total.kcal <= 0 || r.missing > 0) return const SizedBox.shrink();
    final n = r.total;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text('≈ ${n.kcal.round()} سعرة للفرد · بروتين ${n.p.round()} غ · كربوهيدرات ${n.c.round()} غ · دهون ${n.f.round()} غ${n.reviewed ? ' ✓' : ' (تقدير)'}',
          style: const TextStyle(fontSize: 13, color: Brand.grey, height: 1.5)),
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

/// بطاقة وجبة في «اليوم»: صورة كبيرة واسم الوجبة ووقتها، وللشخصي سعراتها وزر «أكلتها».
class _MealTile extends StatelessWidget {
  final SlotView s;
  final Program program;
  final Library library;
  final bool isNext;
  final int people;
  final VoidCallback onTap;
  final double? kcal;
  final VoidCallback? onToggle;
  const _MealTile({required this.s, required this.program, required this.library, required this.isNext, required this.people, required this.onTap, this.kcal, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final photo = s.option == null ? null : library.photoUrl(program.meta.id, s.option!.id);
    return CardBox(
      onTap: onTap,
      padding: EdgeInsets.zero,
      border: isNext ? Border.all(color: Brand.honey, width: 2) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (photo != null) DishPhoto(photo, width: double.infinity, height: 150, radius: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Row(children: [
            if (photo == null) ...[
              // بلا صورة: أيقونة الوجبة بدل مستطيل فارغ
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: Brand.green.withValues(alpha: .1), shape: BoxShape.circle),
                child: Icon(switch (s.slot.id) { 'meal1' => Icons.wb_twilight, 'meal2' => Icons.wb_sunny_outlined, 'meal3' => Icons.coffee_outlined, _ => Icons.nights_stay_outlined }, color: Brand.green),
              ),
              const SizedBox(width: 12),
            ],
            if (onToggle != null) ...[
              GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Icon(s.prepared ? Icons.check_circle : Icons.radio_button_unchecked, size: 34, color: s.prepared ? Brand.green : Colors.black38),
              ),
              const SizedBox(width: 12),
            ] else if (s.prepared) ...[
              const Icon(Icons.check_circle, size: 28, color: Brand.green),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('${s.slot.icon} ${s.slot.name}', style: const TextStyle(fontSize: 13.5, color: Brand.grey, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text(ar12(s.time), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Brand.honey)),
                  if (isNext) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Brand.honey, borderRadius: BorderRadius.circular(10)),
                      child: const Text('التالية', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(s.option?.label ?? '—', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.35)),
                if (kcal != null && kcal! > 0) Text('${kcal!.round()} سعرة', style: const TextStyle(fontSize: 13, color: Brand.grey)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MealCard extends StatelessWidget {
  final SlotView s;
  final Program program;
  final Library library;
  final double servings, portion, photoHeight;
  final Widget? actions;
  const _MealCard({required this.s, required this.program, required this.library, required this.servings, this.portion = 1, this.photoHeight = 160, this.actions});

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
        if (photo != null) ...[DishPhoto(photo, width: double.infinity, height: photoHeight), const SizedBox(height: 12)],
        Text(s.option?.label ?? '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (s.option != null) _NutriLine(program: program, option: s.option!, portion: portion),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final it in scaledItems(s.option, servings, program.ingredients)) _Chip(it.icon, it.qtyLabel, it.label),
        ]),
        if (s.option != null) ...[
          MealReminders(option: s.option!),
          if (s.option!.recipe != null && program.recipes[s.option!.recipe] is Map) ...[
            const SizedBox(height: 12),
            const Text('طريقة التحضير', style: TextStyle(fontWeight: black, fontSize: 16, color: Brand.green)),
            const SizedBox(height: 4),
            for (final (i, st) in ((program.recipes[s.option!.recipe] as Map)['steps'] as List).indexed)
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${i + 1}. $st', style: const TextStyle(fontSize: 14.5, height: 1.6))),
          ],
          MealVideoButton(option: s.option!),
        ],
        ?actions,
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
        await store.syncShopLink(thisWeek); // ما علّمه المتسوّق من الرابط
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
          OutlinedButton.icon(
            icon: const Icon(Icons.ios_share),
            label: const Text('أرسل القائمة للزوج أو السائق'),
            onPressed: () => showShopShare(context, store, thisWeek, program, linesThis, store.pantryOf(program)),
          ),
          const SizedBox(height: 10),
          _ShoppingCard(title: 'هذا الأسبوع', week: thisWeek, lines: linesThis, locked: locked,
              program: program, store: store),
          const SizedBox(height: 24),
          _ShoppingCard(title: 'الأسبوع القادم', week: nextWeek, lines: linesNext, locked: false,
              program: program, store: store),
          const SizedBox(height: 14),
          CardBox(
            onTap: () => showPantrySheet(context, store),
            child: Row(children: [
              const Icon(Icons.kitchen, color: Brand.green),
              const SizedBox(width: 10),
              Expanded(child: Text('عندك في البيت ${store.pantryOf(program).length} صنفاً (لا تُشترى) — اضغط للتعديل',
                  style: const TextStyle(fontWeight: black, fontSize: 14))),
              const Icon(Icons.chevron_left, color: Brand.grey),
            ]),
          ),
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
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: black, color: Brand.green)),
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
            return Text('اشتريت $done من ${lines.length} · ≈ ${total.toStringAsFixed(0)} ر.س (أسعار تقريبية)',
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
            InkWell(
              onTap: () => store.updateShopping(week, l.key, bought: !l.bought),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.cream))),
                child: Row(children: [
                  Icon(l.bought ? Icons.check_circle : Icons.radio_button_unchecked, size: 30, color: l.bought ? Brand.green : Colors.black38),
                  const SizedBox(width: 10),
                  Text(program.ingredients[l.key]!.icon, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(program.ingredients[l.key]!.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, decoration: l.bought ? TextDecoration.lineThrough : null, color: l.bought ? Brand.grey : null)),
                    Text(program.ingredients[l.key]!.buyUnit, style: const TextStyle(fontSize: 13, color: Brand.grey)),
                  ])),
                  if (locked)
                    Text('× ${l.packs}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))
                  else ...[
                    _Step('−', l.packs > 0 ? () => store.updateShopping(week, l.key, packs: l.packs - 1) : null),
                    SizedBox(width: 30, child: Text('${l.packs}', textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    _Step('+', () => store.updateShopping(week, l.key, packs: l.packs + 1)),
                  ],
                ]),
              ),
            ),
          ],
        ]),
      );
}

class _NextWeekTab extends StatefulWidget {
  final HouseholdStore store;
  final Library library;
  const _NextWeekTab({required this.store, required this.library});

  @override
  State<_NextWeekTab> createState() => _NextWeekTabState();
}

class _NextWeekTabState extends State<_NextWeekTab> {
  bool _next = false; // يبدأ بأسبوعه الحالي ليراه كاملاً
  HouseholdStore get store => widget.store;
  Library get library => widget.library;

  @override
  Widget build(BuildContext context) {
    final thisWeekStart = weekStartFor(saudiNow());
    final nextWeek = _next ? thisWeekStart.add(const Duration(days: 7)) : thisWeekStart;
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
            Row(children: [
              for (final (n, l) in [(false, 'هذا الأسبوع'), (true, 'الأسبوع القادم')]) ...[
                Expanded(child: _BigToggle(label: l, selected: _next == n, onTap: () => setState(() => _next = n))),
                if (!n) const SizedBox(width: 10),
              ],
            ]),
            const SizedBox(height: 14),
            Text(_next ? 'خطة الأسبوع القادم' : 'خطة هذا الأسبوع', style: const TextStyle(fontSize: 22, fontWeight: black, color: Brand.green)),
            Text('اضغط على اليوم لتغيير أي وجبة.${_next ? ' تُقفل المشتريات مساء ${const ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'][store.household.cutoffDay]} الساعة ${ar12(store.household.cutoffTime)}.' : ''}',
                style: const TextStyle(fontSize: 13, color: Brand.grey, height: 1.6)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('أعد توليد الأسبوع'),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(_next ? 'إعادة توليد الأسبوع القادم؟' : 'إعادة توليد هذا الأسبوع؟'),
                        content: const Text('تُستبدل كل وجبات الأسبوع القادم بوجبات جديدة تتجنب ما قُدّم هذا الأسبوع وتحترم ما أخفيتِه وما فضّلتِه. المشتريات تُحسب من جديد.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('أعد التوليد')),
                        ],
                      ),
                    );
                    if (ok == true) await store.regenerateWeek(nextWeek);
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(icon: const Icon(Icons.restaurant_menu), label: const Text('وجباتي'), onPressed: () => showMealsManager(context, store)),
            ]),
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
                        style: const TextStyle(fontSize: 13, color: Brand.grey)),
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
