import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/calories.dart';
import '../theme.dart';
import 'common.dart';

/// «هدفي»: سعرات وماكروز اليوم، يعدّلها صاحبها أو الأخصائي، وتحديث الوزن يعيد الحساب والحصص.
class GoalCard extends StatefulWidget {
  final HouseholdStore store;
  /// الأخصائي المعتمد: تعديله يصير «معتمداً» باسمه.
  final bool isSpecialist;
  final String who;
  /// أخصائي مرتبط بهذا البيت (فتصير الشارة «بانتظار مراجعته» بدل «لم يُراجع»).
  final bool hasSpecialist;
  const GoalCard({super.key, required this.store, this.isSpecialist = false, this.who = '', this.hasSpecialist = false});

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  double? _kcal; // قيد التعديل
  bool _busy = false;

  Map<String, dynamic> get _t => widget.store.household.target ?? const {};

  Future<void> _save() async {
    final k = _kcal!;
    setState(() => _busy = true);
    final t = targetForKcal(k, (_t['proteinG'] as num?)?.toInt() ?? 100, weeks: (_t['weeks'] as num?)?.toInt(),
        status: widget.isSpecialist ? 'reviewed' : 'custom', by: widget.isSpecialist ? widget.who : null);
    await widget.store.setTarget(t);
    await widget.store.calibrateToTarget();
    if (mounted) setState(() { _kcal = null; _busy = false; });
  }

  Future<void> _updateWeight() async {
    final prof = profileFromMap(widget.store.household.profile);
    if (prof == null) return;
    final c = TextEditingController(text: prof.weightKg.toStringAsFixed(prof.weightKg == prof.weightKg.roundToDouble() ? 0 : 1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('وزني اليوم'),
        content: TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(suffixText: 'كجم', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('احسب من جديد')),
        ],
      ),
    );
    final w = double.tryParse(c.text.trim().replaceAll(',', '.'));
    if (ok != true || w == null) return;
    final np = Profile(sex: prof.sex, age: prof.age, heightCm: prof.heightCm, weightKg: w, activity: prof.activity,
        goalKg: prof.goalKg, paceKgWeek: prof.paceKgWeek, mode: prof.mode);
    final plan = planFor(np);
    if (plan == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تحقق من الوزن المدخل')));
      return;
    }
    await widget.store.setTarget(targetMapOf(plan), profile: {...?widget.store.household.profile, 'weightKg': w, 'approx': false});
    await widget.store.calibrateToTarget();
    if (mounted) setState(() => _kcal = null);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final t = _t;
          if (t.isEmpty) return const SizedBox.shrink();
          final kcal = _kcal ?? (t['kcal'] as num).toDouble();
          final status = t['status'] as String? ?? 'estimate';
          final chip = switch (status) {
            'reviewed' => ('اعتمده ${t['reviewedBy'] ?? 'الأخصائي'} ✓', Brand.green),
            'custom' => ('عدّلتَه بنفسك', Brand.honey),
            _ => (widget.hasSpecialist ? 'بانتظار مراجعة أخصائيك' : 'تقدير آلي — لم يُراجع بعد', Brand.grey),
          };
          final prot = (t['proteinG'] as num?)?.toInt() ?? 0;
          final f = _kcal == null ? (t['fatG'] as num?)?.toInt() ?? 0 : (kcal * .27 / 9).round();
          final c = _kcal == null ? (t['carbG'] as num?)?.toInt() ?? 0 : ((kcal - prot * 4 - f * 9) / 4).round().clamp(0, 9999);
          final prof = profileFromMap(widget.store.household.profile);
          return CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('هدفي اليومي', style: TextStyle(fontSize: 17, fontWeight: black, color: Brand.green))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: chip.$2.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                  child: Text(chip.$1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: chip.$2)),
                ),
              ]),
              const SizedBox(height: 6),
              // في الواجهة العربية الصف يبدأ من اليمين: نضع «−» أولاً ليظهر على اليسار و«+» أخيراً على اليمين كما في الأرقام
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(onPressed: () => setState(() => _kcal = (kcal + 50).clamp(1000, 5000)), icon: const Icon(Icons.add_circle_outline, color: Brand.green, size: 34)),
                Column(children: [
                  Text('${kcal.round()}', style: const TextStyle(fontSize: 44, fontWeight: black, color: Brand.green, height: 1.1)),
                  const Text('سعرة في اليوم', style: TextStyle(fontSize: 13, color: Brand.grey)),
                ]),
                IconButton(onPressed: () => setState(() => _kcal = (kcal - 50).clamp(1000, 5000)), icon: const Icon(Icons.remove_circle_outline, color: Brand.green, size: 34)),
              ]),
              Row(children: [
                for (final (l, v) in [('بروتين', prot), ('كربوهيدرات', c), ('دهون', f)])
                  Expanded(child: Column(children: [
                    Text('$v غ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(l, style: const TextStyle(fontSize: 13, color: Brand.grey)),
                  ])),
              ]),
              if (t['weeks'] != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text('نحو ${t['weeks']} أسبوعاً للوصول لهدفك', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Brand.grey))),
              if (_kcal != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _busy ? null : () => setState(() => _kcal = null), child: const Text('تراجع'))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Brand.green),
                    onPressed: _busy ? null : _save, child: const Text('احفظ الهدف'))),
                ]),
                const Padding(padding: EdgeInsets.only(top: 6), child: Text('الحصص في وجباتك تُعاد معايرتها لتناسب هدفك الجديد.', style: TextStyle(fontSize: 13, color: Brand.grey))),
              ] else if (prof != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: _updateWeight, icon: const Icon(Icons.monitor_weight_outlined), label: Text(widget.store.household.profile?['approx'] == true ? 'أدخل وزنك الفعلي (تقدير ≈${prof.weightKg.round()} كجم)' : 'تحديث وزني (الآن ${prof.weightKg.toStringAsFixed(prof.weightKg == prof.weightKg.roundToDouble() ? 0 : 1)} كجم)')),
              ],
            ]),
          );
        },
      );
}
