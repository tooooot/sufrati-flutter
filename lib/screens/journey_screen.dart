import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../data/journey.dart';
import '../data/links.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../logic/calories.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// رحلة الاستكشاف قبل الدخول: اختر هدفك ← أجب بأسئلة قصيرة ← خطة تقديرية ← احفظها (يطلب الدخول عندها فقط).
class JourneyScreen extends StatefulWidget {
  final Library library;
  final Session session;
  const JourneyScreen({super.key, required this.library, required this.session});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

enum _Step { goal, family, body, result }

class _JourneyScreenState extends State<JourneyScreen> {
  _Step _step = _Step.goal;
  String _track = 'family';
  int _eaters = 5, _kids = 2;
  Sex _sex = Sex.female;
  Activity _act = Activity.light;
  final _age = TextEditingController(), _h = TextEditingController(), _w = TextEditingController(), _goal = TextEditingController();
  double _pace = 0.5;
  bool _special = false;
  JourneyDraft? _draft;
  Program? _prog;
  String? _error;

  @override
  void dispose() {
    for (final c in [_age, _h, _w, _goal]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _back() {
    setState(() {
      _error = null;
      _step = switch (_step) { _Step.result => _track == 'family' ? _Step.family : _Step.body, _ => _Step.goal };
    });
  }

  Future<void> _computeFamily() async {
    final prog = await widget.library.program('saudi_family');
    final servings = (_eaters - _kids) + 0.5 * _kids;
    setState(() {
      _prog = prog;
      _draft = JourneyDraft(track: 'family', programId: 'saudi_family', eaters: _eaters, kids: _kids);
      _step = _Step.result;
      _servings = servings;
    });
  }

  double _servings = 1;

  Future<void> _computeBody() async {
    final age = _num(_age)?.round(), h = _num(_h), w = _num(_w), g = _num(_goal);
    if (age == null || h == null || w == null || g == null) {
      setState(() => _error = 'أكمل الحقول الأربعة (العمر والطول والوزن والوزن المستهدف).');
      return;
    }
    if (g >= w) {
      setState(() => _error = 'الوزن المستهدف يجب أن يكون أقل من وزنك الحالي.');
      return;
    }
    final prof = Profile(sex: _sex, age: age, heightCm: h, weightKg: w, activity: _act, goalKg: g, paceKgWeek: _pace, needsSpecialist: _special);
    final plan = planFor(prof);
    if (plan == null) {
      setState(() => _error = _special || age < 18
          ? 'حالتك تحتاج أخصائي تغذية يحدد السعرات بنفسه، ولا نحسبها آلياً. تصفّح الأنظمة أو تواصل مع طبيب.'
          : 'تحقق من الأرقام المدخلة (الطول بالسنتيمتر والوزن بالكيلو).');
      return;
    }
    final prog = await widget.library.program('weight_loss_general');
    setState(() {
      _prog = prog;
      _draft = JourneyDraft(track: 'weight', programId: 'weight_loss_general', eaters: 1, profile: prof, plan: plan, portion: portionFor(prog, plan.kcal));
      _error = null;
      _step = _Step.result;
    });
  }

  void _save() {
    JourneyDraft.current = _draft;
    if (widget.session.signedIn) {
      context.go('/journey/finish');
    } else {
      context.push('/login?next=${Uri.encodeComponent('/journey/finish')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.goal => 'ما هدفك؟',
      _Step.family => 'أسرتك',
      _Step.body => 'عنك',
      _Step.result => 'خطتك المقترحة',
    };
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        GreenHeader(
          icon: '🧭', title: title, subtitle: 'دقيقة واحدة بلا تسجيل',
          leading: _step == _Step.goal ? null : IconButton(onPressed: _back, icon: const Icon(Icons.arrow_forward, color: Colors.white)),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 32), child: _body(context)),
          ),
        ),
      ]),
    );
  }

  Widget _body(BuildContext context) => switch (_step) {
        _Step.goal => _goalStep(),
        _Step.family => _familyStep(),
        _Step.body => _bodyStep(),
        _Step.result => _resultStep(),
      };

  Widget _choice(String icon, String title, String sub, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CardBox(
          onTap: onTap,
          child: Row(children: [
            Text(icon, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: black, color: Brand.green)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 13, color: Brand.grey, height: 1.5)),
              ]),
            ),
          ]),
        ),
      );

  Widget _goalStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _choice('👨‍👩‍👧‍👦', 'أدير غذاء أسرتي', 'قائمة سعودية أسبوعية بالمقادير ومشتريات جاهزة، والتذكيرات للطاهي.', () => setState(() { _track = 'family'; _step = _Step.family; })),
        _choice('⚖️', 'أريد تنقيص وزني', 'نحسب سعراتك من طولك ووزنك، وتصلك وجبات بحصص مضبوطة.', () => setState(() { _track = 'weight'; _step = _Step.body; })),
        _choice('🩺', 'عندي حالة صحية', 'سكري، كلى، ضغط… بإشراف أخصائي تغذية. تصفّح الأنظمة المتاحة.', () => context.push('/browse')),
        _choice('💪', 'أريد بناء العضل', 'نظام عالي البروتين. تصفّحه الآن، والحساب الشخصي قادم.', () => context.push('/browse')),
        Center(
          child: TextButton(onPressed: () => context.push('/login'), child: const Text('لدي حساب — دخول')),
        ),
      ]);

  Widget _stepper(String label, int v, int min, int max, ValueChanged<int> on) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: black))),
          IconButton(onPressed: v > min ? () => on(v - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
          SizedBox(width: 30, child: Text('$v', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: black))),
          IconButton(onPressed: v < max ? () => on(v + 1) : null, icon: const Icon(Icons.add_circle_outline, color: Brand.green)),
        ]),
      );

  Widget _familyStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardBox(child: Column(children: [
          _stepper('عدد أفراد الأسرة', _eaters, 1, 15, (v) => setState(() { _eaters = v; if (_kids > v - 1) _kids = v - 1; })),
          _stepper('منهم أطفال', _kids, 0, _eaters - 1, (v) => setState(() => _kids = v)),
          const SizedBox(height: 4),
          const Text('الطفل يُحسب بنصف حصة. تغيّر هذا لاحقاً من التحكم.', style: TextStyle(fontSize: 12, color: Brand.grey)),
        ])),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Brand.green, minimumSize: const Size.fromHeight(52)),
          onPressed: _computeFamily,
          child: const Text('أرِني الخطة', style: TextStyle(fontSize: 17, fontWeight: black)),
        ),
      ]);

  Widget _field(String label, TextEditingController c, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
        ),
      );

  Widget _seg<T>(List<(T, String)> items, T cur, ValueChanged<T> on) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (v, l) in items)
          InkWell(
            onTap: () => on(v),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: cur == v ? Brand.green : Colors.white,
                border: Border.all(color: cur == v ? Brand.green : Colors.black26),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(l, style: TextStyle(color: cur == v ? Colors.white : Colors.black87, fontWeight: black, fontSize: 14)),
            ),
          ),
      ]);

  Widget _bodyStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _seg<Sex>(const [(Sex.female, 'أنثى'), (Sex.male, 'ذكر')], _sex, (v) => setState(() => _sex = v)),
        const SizedBox(height: 14),
        _field('العمر (سنة)', _age, '30'),
        _field('الطول (سم)', _h, '165'),
        _field('الوزن الحالي (كجم)', _w, '85'),
        _field('الوزن المستهدف (كجم)', _goal, '70'),
        const Text('نشاطك اليومي', style: TextStyle(fontWeight: black)),
        const SizedBox(height: 6),
        _seg<Activity>(const [
          (Activity.sedentary, 'جلوس غالباً'), (Activity.light, 'خفيف (مشي)'), (Activity.moderate, 'رياضة ٣–٥ أيام'),
          (Activity.high, 'رياضة يومية'), (Activity.athlete, 'رياضي محترف'),
        ], _act, (v) => setState(() => _act = v)),
        const SizedBox(height: 14),
        const Text('سرعة النزول', style: TextStyle(fontWeight: black)),
        const SizedBox(height: 6),
        _seg<double>(const [(0.25, 'هادئ ٠٫٢٥ كجم/أسبوع'), (0.5, 'متوازن ٠٫٥'), (0.75, 'سريع ٠٫٧٥')], _pace, (v) => setState(() => _pace = v)),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _special,
          onChanged: (v) => setState(() => _special = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('حامل أو مرضعة، أو عندي سكري/كلى/اضطراب أكل', style: TextStyle(fontSize: 13)),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.red, height: 1.6))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Brand.green, minimumSize: const Size.fromHeight(52)),
          onPressed: _computeBody,
          child: const Text('احسب خطتي', style: TextStyle(fontSize: 17, fontWeight: black)),
        ),
      ]);

  Widget _macro(String l, String v) => Expanded(
        child: Column(children: [
          Text(v, style: const TextStyle(fontSize: 20, fontWeight: black, color: Brand.green)),
          Text(l, style: const TextStyle(fontSize: 12, color: Brand.grey)),
        ]),
      );

  /// معاينة يوم: أول خيار من كل وجبة بحصة الهدف.
  Widget _dayPreview() {
    final prog = _prog!;
    final portion = _draft!.portion;
    var total = Nutri.zero;
    final rows = <Widget>[];
    for (final s in prog.slots) {
      if (s.options.isEmpty) continue;
      final k = _draft!.track == 'weight' ? portion : 1.0;
      // الخيار الأقرب لمتوسط الخانة: فيقرب مجموع اليوم المعروض من هدف السعرات بدل أن يصادف أثقل الخيارات
      final avg = s.options.map((x) => optionNutri(prog, x).total.kcal).reduce((a, b) => a + b) / s.options.length;
      final o = ([...s.options]..sort((a, b) => (optionNutri(prog, a).total.kcal - avg).abs().compareTo((optionNutri(prog, b).total.kcal - avg).abs()))).first;
      final n = optionNutri(prog, o, portion: k).total;
      total = total + n;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(s.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text('${s.name}: ${o.label}', style: const TextStyle(fontSize: 14, height: 1.4))),
          Text('${n.kcal.round()}', style: const TextStyle(fontWeight: black, color: Brand.honey)),
        ]),
      ));
    }
    return CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('مثال ليوم واحد', style: TextStyle(fontWeight: black, color: Brand.green)),
      ...rows,
      const Divider(),
      Row(children: [
        const Expanded(child: Text('المجموع التقريبي', style: TextStyle(fontWeight: black))),
        Text('${total.kcal.round()} سعرة', style: const TextStyle(fontWeight: black)),
      ]),
    ]));
  }

  Widget _resultStep() {
    final d = _draft!;
    final plan = d.plan;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (plan != null) ...[
        CardBox(child: Column(children: [
          const Text('سعراتك اليومية المقترحة', style: TextStyle(color: Brand.grey)),
          Text('${plan.kcal.round()}', style: const TextStyle(fontSize: 44, fontWeight: black, color: Brand.green)),
          Row(children: [
            _macro('بروتين', '${plan.proteinG.round()} غ'),
            _macro('كربوهيدرات', '${plan.carbG.round()} غ'),
            _macro('دهون', '${plan.fatG.round()} غ'),
          ]),
          const SizedBox(height: 10),
          Text('مؤشر كتلة الجسم ${plan.bmi.toStringAsFixed(1)}'
              '${plan.weeks != null ? ' · نحو ${plan.weeks} أسبوعاً للوصول لهدفك' : ''}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Brand.grey)),
          if (plan.note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(plan.note!, style: const TextStyle(fontSize: 12, color: Brand.honey))),
        ])),
        const SizedBox(height: 12),
      ] else
        CardBox(child: Text(
            'بيت من ${d.eaters} أفراد (${d.eaters - d.kids} بالغ و${d.kids} أطفال) — الحصص تُحسب لـ ${_servings.toStringAsFixed(1)} حصة بالغ. القائمة والمقادير ومشترياتك الأسبوعية تُجهَّز فور الحفظ.',
            style: const TextStyle(height: 1.7))),
      const SizedBox(height: 12),
      if (_prog != null) _dayPreview(),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Brand.amber50, borderRadius: BorderRadius.circular(12)),
        child: const Text(
            'أرقام تقديرية بدقة نحو ±١٠٪ وليست وصفة طبية. يراجعها أخصائي التغذية ويعدّلها إن لزم، ومن لديه حالة مرضية يستشير طبيبه أولاً.',
            style: TextStyle(fontSize: 12, height: 1.7)),
      ),
      const SizedBox(height: 16),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(56)),
        onPressed: _save,
        child: const Text('احفظ خطتي', style: TextStyle(fontSize: 18, fontWeight: black)),
      ),
    ]);
  }
}

/// يحوّل المسودة إلى بيت حقيقي بعد الدخول، ثم يفتح الشاشة الرئيسية.
class JourneyFinishScreen extends StatefulWidget {
  final LinkService links;
  final Session session;
  const JourneyFinishScreen({super.key, required this.links, required this.session});

  @override
  State<JourneyFinishScreen> createState() => _JourneyFinishScreenState();
}

class _JourneyFinishScreenState extends State<JourneyFinishScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final d = JourneyDraft.current;
    if (d == null || widget.links.hasHousehold) {
      if (mounted) context.go(widget.links.hasHousehold ? '/me' : '/new-house');
      return;
    }
    try {
      final name = widget.session.user?.name.split(' ').first ?? '';
      await widget.links.createHousehold(name.isEmpty ? 'بيتي' : 'بيت $name', d.programId, d.eaters, extra: d.toHousehold());
      JourneyDraft.current = null;
      if (mounted) context.go('/me');
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر حفظ الخطة. تحقق من الاتصال وأعد المحاولة.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: _error == null
              ? const Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: Brand.green), SizedBox(height: 14), Text('نجهّز خطتك…')])
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!),
                  TextButton(onPressed: () { setState(() => _error = null); _run(); }, child: const Text('إعادة المحاولة')),
                ]),
        ),
      );
}
