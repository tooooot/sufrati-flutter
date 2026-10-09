import 'dart:async';

import 'package:flutter/material.dart';

import '../data/i18n.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/store.dart';
import '../notify/cook_alerts.dart';
import '../notify/notification_service.dart';
import '../logic/day_view.dart';
import '../logic/planner.dart';
import '../logic/prayer.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tabs_scaffold.dart';

/// لوحة الطاهي — نقل لـ cook.html: الوجبة القادمة الآن · وجبات اليوم بالصور والطريقة · «جاهز» · 3 لغات.
/// (تنبيهات الجوال المحلية تُضاف في بناء الأندرويد/الآيفون — لا تعمل في معاينة المتصفح.)
class CookScreen extends StatefulWidget {
  final HouseholdStore store;
  final Library library;
  final CookI18n i18n;
  const CookScreen({super.key, required this.store, required this.library, required this.i18n});

  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen> {
  String lang = 'ar';
  Timer? _tick;
  bool _alertsOn = false, _alertsDenied = false, _testSent = false;

  @override
  void initState() {
    super.initState();
    // الوجبة القادمة تتحدّث كل 30 ثانية، واليوم يتغيّر تلقائياً بعد منتصف الليل
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
    _syncAlerts(ask: false);
  }

  /// يجدول تنبيهات 7 أيام (تعمل والتطبيق مغلق). عند كل فتح يُعاد الجدول فتتجدد الأيام.
  Future<void> _syncAlerts({required bool ask}) async {
    if (!NotificationService.supported) return;
    final svc = NotificationService.instance;
    var ok = await svc.enabled();
    if (!ok && ask) ok = await svc.requestPermission();
    if (!mounted) return;
    if (!ok) {
      setState(() { _alertsOn = false; _alertsDenied = ask; });
      return;
    }
    final alerts = await buildCookAlerts(widget.store, widget.i18n, nowSaudi: saudiNow(), lang: lang);
    await svc.schedule(alerts);
    if (mounted) setState(() { _alertsOn = true; _alertsDenied = false; });
  }

  Widget _alertsCard() {
    if (!NotificationService.supported) return const SizedBox.shrink();
    if (_alertsOn) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CardBox(
          color: const Color(0xFFECFDF5),
          child: Row(children: [
            Expanded(child: Text(ui('alerts_on'), style: const TextStyle(fontWeight: black, color: Brand.green))),
            TextButton(
              onPressed: _testSent ? null : () async {
                await NotificationService.instance.test('🍽️ ${ui('test_alert')}', ui('test_alert_body'));
                setState(() => _testSent = true);
              },
              child: Text(ui('test_alert')),
            ),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CardBox(
        color: Brand.amber50,
        border: Border.all(color: Brand.honey),
        onTap: () => _syncAlerts(ask: true),
        child: Text(_alertsDenied ? ui('alerts_denied') : ui('enable_alerts'),
            textAlign: TextAlign.center, style: const TextStyle(fontWeight: black, color: Brand.green, height: 1.5)),
      ),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String ui(String k) => widget.i18n.ui(k, lang);

  @override
  Widget build(BuildContext context) {
    final ltr = lang == 'en' || lang == 'am';
    final h = widget.store.household;
    final now = saudiNow();
    final today = DateTime(now.year, now.month, now.day);
    return Directionality(
      textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => FutureBuilder(
          future: () async {
            final p = await widget.store.program();
            return (p, await dayView(widget.store, p, today),
                await widget.store.shopping(weekStartFor(today).add(const Duration(days: 7))));
          }(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Brand.green)));
            }
            final (Program program, DayView day, shoppingNext) = snap.data!;
            final pid = program.meta.id;
            final dayName = widget.i18n.dayName(day.dayIndex, lang, widget.library.dayNames[day.dayIndex]);
            return TabsScaffold(
              header: _header(h.cookName, dayName, h.eaters),
              tabs: [
                TabItem('🍽️', ui('nav_today'), (_) => _today(program, day, now)),
                TabItem('⚠️', ui('nav_info'), (_) => _info(program, now)),
                TabItem('🛒', ui('nav_next'), (_) => _next(program, shoppingNext, pid)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(String cookName, String dayName, int eaters) => Stack(children: [
        GreenHeader(
          icon: '👩‍🍳',
          title: cookName.isNotEmpty ? '${ui('hello')} $cookName 👋' : ui('kitchen_default'),
          subtitle: '$dayName — ${ui('cooking_for')} $eaters 👤',
        ),
        PositionedDirectional(
          end: 12,
          top: MediaQuery.paddingOf(context).top + 12,
          child: Row(children: [
            for (final code in widget.i18n.langs.keys)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() => lang = code);
                    if (_alertsOn) _syncAlerts(ask: false); // عناوين التنبيهات تتبع اللغة
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: lang == code ? Colors.white : Colors.white24,
                    child: Text(code.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: black,
                        color: lang == code ? Brand.green : Colors.white)),
                  ),
                ),
              ),
          ]),
        ),
      ]);

  /// الوجبة «الآن»: من قبل وقتها بربع ساعة إلى ساعة ونصف بعده — نفس checkNextMeal.
  SlotView? _active(DayView day, DateTime now) {
    final nowMin = now.hour * 60 + now.minute;
    SlotView? active;
    for (final s in day.slots) {
      final p = s.time.split(':').map(int.parse).toList();
      final t = p[0] * 60 + p[1];
      if (nowMin >= t - 15 && nowMin <= t + 90) active = s;
    }
    return active;
  }

  Widget _today(Program program, DayView day, DateTime now) {
    final active = _active(day, now);
    final pid = program.meta.id;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _alertsCard(),
      if (active != null) ...[
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Brand.honey, borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16)]),
          child: Column(children: [
            Text(active.slot.icon, style: const TextStyle(fontSize: 56)),
            Text(ui('time_for'), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: black)),
            Text(widget.i18n.slotName(active.slot.id, lang, active.slot.name),
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: black)),
            if (active.option != null)
              Text(widget.i18n.option(pid, active.option!.id, lang, active.option!.label), textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      for (final s in day.slots) ...[
        _mealCard(program, day, s, highlighted: identical(s, active)),
        const SizedBox(height: 16),
      ],
    ]);
  }

  Widget _mealCard(Program program, DayView day, SlotView s, {required bool highlighted}) {
    final pid = program.meta.id;
    final photo = s.option == null ? null : widget.library.photoUrl(pid, s.option!.id);
    final recipeId = s.option?.recipe;
    final recipe = recipeId == null ? null : program.recipes[recipeId] as Map<String, dynamic>?;
    return CardBox(
      padding: const EdgeInsets.all(20),
      border: Border.all(
          color: highlighted ? Brand.honey : (s.prepared ? Colors.green.shade400 : Brand.honey.withValues(alpha: .3)),
          width: highlighted ? 4 : 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(s.slot.icon, style: const TextStyle(fontSize: 46)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.i18n.slotName(s.slot.id, lang, s.slot.name),
                style: const TextStyle(fontSize: 22, fontWeight: black, color: Brand.green)),
            Text('🕐 ${ar12(s.time, lang)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Brand.grey)),
          ])),
          if (s.prepared) const Text('✅', style: TextStyle(fontSize: 34)),
        ]),
        const SizedBox(height: 12),
        if (photo != null) ...[DishPhoto(photo, width: double.infinity, height: 176), const SizedBox(height: 12)],
        Text(s.option == null ? '—' : widget.i18n.option(pid, s.option!.id, lang, s.option!.label),
            style: const TextStyle(fontSize: 22, fontWeight: black)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final it in scaledItems(s.option, widget.store.household.eaters, program.ingredients))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(12)),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${it.icon} ', style: const TextStyle(fontSize: 24)),
                TextSpan(text: '${it.qtyLabel} ', style: const TextStyle(fontSize: 18, fontWeight: black)),
                TextSpan(text: widget.i18n.ingredient(pid, it.key, lang, it.label),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
              ])),
            ),
        ]),
        if (recipe != null) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Brand.green.withValues(alpha: .05), borderRadius: BorderRadius.circular(12)),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(ui('how_to_prepare'), style: const TextStyle(fontSize: 18, fontWeight: black, color: Brand.green)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  for (final (i, step) in widget.i18n.recipe(pid, recipeId!, lang, recipe).$2.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${i + 1}. $step', style: const TextStyle(fontSize: 18)),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: s.prepared ? Colors.green.shade100 : Brand.green,
            foregroundColor: s.prepared ? Colors.green.shade800 : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => widget.store.setPrepared(day.weekStart, day.dayIndex, s.slot.id, !s.prepared),
          child: Text(s.prepared ? ui('marked_ready') : ui('mark_ready'),
              style: const TextStyle(fontSize: 22, fontWeight: black, fontFamily: 'Tajawal')),
        ),
      ]),
    );
  }

  Widget _info(Program program, DateTime now) {
    final pid = program.meta.id;
    final tips = program.cookTips;
    final tipIdx = tips.isEmpty ? 0 : (DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(1)).inDays + 1) % tips.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardBox(
        padding: const EdgeInsets.all(20),
        border: Border.all(color: Colors.red.shade200, width: 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ui('important'), style: TextStyle(fontSize: 20, fontWeight: black, color: Colors.red.shade600)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.3,
            children: [
              for (final (i, ins) in program.cookInstructions.indexed)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(ins['icon'] ?? '', style: const TextStyle(fontSize: 28)),
                    Text(widget.i18n.listItem('COOK_INSTRUCTIONS_TR', pid, i, lang, ins['text'] ?? ''),
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ]),
                ),
            ],
          ),
        ]),
      ),
      if (tips.isNotEmpty) ...[
        const SizedBox(height: 12),
        CardBox(
          border: Border.all(color: Brand.green.withValues(alpha: .15), width: 2),
          child: Row(children: [
            Text(tips[tipIdx]['icon'] ?? '💡', style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ui('tip_of_day'), style: const TextStyle(fontSize: 12, fontWeight: black, color: Brand.honey)),
              Text(widget.i18n.listItem('MAID_TIPS_TR', pid, tipIdx, lang, tips[tipIdx]['text'] ?? ''),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ])),
          ]),
        ),
      ],
    ]);
  }

  Widget _next(Program program, List lines, String pid) => CardBox(
        padding: const EdgeInsets.all(20),
        border: Border.all(color: Brand.honey.withValues(alpha: .3), width: 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ui('next_shopping'), style: const TextStyle(fontSize: 20, fontWeight: black, color: Brand.green)),
          Text(ui('shopping_note'), style: const TextStyle(fontSize: 13, color: Brand.grey)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final l in lines)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(12)),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${program.ingredients[l.key]!.icon} ', style: const TextStyle(fontSize: 22)),
                  TextSpan(text: '${l.packs}× ', style: const TextStyle(fontSize: 17, fontWeight: black)),
                  TextSpan(text: widget.i18n.ingredient(pid, l.key, lang, program.ingredients[l.key]!.label),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ])),
              ),
          ]),
        ]),
      );
}
