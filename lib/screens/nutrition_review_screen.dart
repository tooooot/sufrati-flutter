import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/nutrition_review.dart';
import '../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';

/// شاشة الأخصائي: يراجع تقديرات السعرات والماكروز لكل مكوّن (لوحدة واحدة) ويعدّلها ويعتمدها.
class NutritionReviewScreen extends StatefulWidget {
  final Library library;
  final NutritionReview review;
  final bool allowed; // مدير أو طبيب معتمد
  final String who;
  const NutritionReviewScreen({super.key, required this.library, required this.review, required this.allowed, required this.who});

  @override
  State<NutritionReviewScreen> createState() => _NutritionReviewScreenState();
}

class _NutritionReviewScreenState extends State<NutritionReviewScreen> {
  String _prog = 'saudi_family';
  Program? _p;
  Map<String, Map<String, dynamic>> _done = {};
  bool _loading = true, _onlyPending = false;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _done = await widget.review.reviewed();
    } catch (_) {}
    // البرنامج الأصلي بلا تعديلات الأخصائي: نريد قيمة الملف للمقارنة والتحرير
    final prog = await widget.library.program(_prog);
    if (mounted) setState(() { _p = prog; _loading = false; });
  }

  Future<void> _edit(Ingredient ing) async {
    final n = ing.nutri!;
    final cs = [for (final v in [n.kcal, n.p, n.c, n.f]) TextEditingController(text: v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1))];
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${ing.label}\nلكل: ${ing.unit}', style: const TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final (i, l) in ['سعرات', 'بروتين (غ)', 'كربوهيدرات (غ)', 'دهون (غ)'].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(controller: cs[i], keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l, border: const OutlineInputBorder())),
              ),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('اعتمد')),
        ],
      ),
    );
    if (ok != true) return;
    double v(int i) => double.tryParse(cs[i].text.trim().replaceAll(',', '.')) ?? -1;
    if ([for (var i = 0; i < 4; i++) v(i)].any((x) => x < 0)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أرقام غير صحيحة')));
      return;
    }
    try {
      await widget.review.save(_prog, ing.key, Nutri(v(0), v(1), v(2), v(3)), by: widget.who, note: note.text.trim());
      _done = await widget.review.reviewed();
      nutriOverrides['${_prog}__${ing.key}'] = Nutri(v(0), v(1), v(2), v(3), reviewed: true);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر الحفظ (ليس لديك صلاحية؟)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final items = p == null
        ? <Ingredient>[]
        : p.ingredients.values.where((i) => i.nutri != null && (_q.isEmpty || i.label.contains(_q)) &&
            (!_onlyPending || !_done.containsKey('${_prog}__${i.key}'))).toList();
    final doneCount = p == null ? 0 : p.ingredients.keys.where((k) => _done.containsKey('${_prog}__$k')).length;
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        GreenHeader(
          icon: '🧪', title: 'مراجعة التغذية', subtitle: 'تقديرات أولية بانتظار اعتمادك',
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.back('/me')),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: !widget.allowed
                  ? const Padding(padding: EdgeInsets.all(30), child: Text('هذه الشاشة للأخصائي المعتمد ومدير سفرتي فقط.', textAlign: TextAlign.center))
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      DropdownButtonFormField<String>(
                        initialValue: _prog,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'النظام'),
                        items: [for (final m in widget.library.active) DropdownMenuItem(value: m.id, child: Text('${m.icon} ${m.label}'))],
                        onChanged: (v) { _prog = v!; _load(); },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن مكوّن', border: OutlineInputBorder()),
                        onChanged: (v) => setState(() => _q = v.trim()),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _onlyPending,
                        onChanged: (v) => setState(() => _onlyPending = v),
                        title: const Text('غير المعتمد فقط'),
                        subtitle: Text('اعتُمد $doneCount من ${p?.ingredients.length ?? 0}'),
                      ),
                      if (_loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: Brand.green))),
                      for (final i in items)
                        Builder(builder: (_) {
                          final d = _done['${_prog}__${i.key}'];
                          final n = d == null ? i.nutri! : Nutri((d['kcal'] as num).toDouble(), (d['p'] as num).toDouble(), (d['c'] as num).toDouble(), (d['f'] as num).toDouble());
                          return CardBox(
                            onTap: () => _edit(Ingredient(i.key, {'label': i.label, 'unit': i.unit, 'kcal': n.kcal, 'p': n.p, 'c': n.c, 'f': n.f})),
                            child: Row(children: [
                              Icon(d == null ? Icons.hourglass_top : Icons.verified, color: d == null ? Brand.grey : Brand.green),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${i.label} · لكل ${i.unit}', style: const TextStyle(fontWeight: black)),
                                  Text('${n.kcal.round()} سعرة · ب ${n.p.toStringAsFixed(1)} · ك ${n.c.toStringAsFixed(1)} · د ${n.f.toStringAsFixed(1)}',
                                      style: const TextStyle(fontSize: 12, color: Brand.grey)),
                                ]),
                              ),
                              const Icon(Icons.edit, size: 18),
                            ]),
                          );
                        }),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }
}
