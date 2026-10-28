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

/// خيار زر في صفحة سؤال: النقر عليه يقدّم للتالي مباشرة.
class _Opt<T> {
  final String label;
  final String? icon, sub;
  final T value;
  const _Opt(this.label, this.value, {this.icon, this.sub});
}

/// رحلة الاستكشاف قبل الدخول: شاشة الأنظمة ← (ساعدني/اختر لي) ← أسئلة بالأزرار فقط، سؤال في كل صفحة ← خطة تقديرية ← احفظها (الدخول عندها فقط).
class JourneyScreen extends StatefulWidget {
  final Library library;
  final Session session;
  /// تغيير نظام بيت قائم (لا إنشاء بيت جديد).
  final bool update;
  /// من إعلان لهدف محدد: يتخطى شاشة الأنظمة (weight/muscle/medical/withcook/family).
  final String? goal;
  const JourneyScreen({super.key, required this.library, required this.session, this.update = false, this.goal});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

enum _Flow { catalog, help1, help2, reco, q }

class _JourneyScreenState extends State<JourneyScreen> {
  _Flow _flow = _Flow.catalog;

  @override
  void initState() {
    super.initState();
    final pid = const {'weight': 'weight_loss_general', 'muscle': 'muscle_gain', 'medical': 'kidney_salama', 'withcook': 'saudi_family', 'family': 'saudi_family'}[widget.goal];
    if (pid != null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _select(pid) : null);
  }
  // الاختيار
  String? _pid;
  String _track = 'family';
  Mode _mode = Mode.lose;
  // مساعد الاختيار
  String? _helpGoal;
  // خطوات الأسئلة
  List<String> _steps = const [];
  int _qi = 0;
  final _a = <String, Object?>{};
  JourneyDraft? _draft;
  Program? _prog;
  double _servings = 1;

  // ---- النظام ← المسار ----
  void _select(String pid) {
    _pid = pid;
    switch (pid) {
      case 'saudi_family':
        _track = 'family';
      case 'kidney_salama':
        _track = 'medical';
      case 'muscle_gain':
        _track = 'muscle';
        _mode = Mode.gain;
      case 'cutting_gym':
        _track = 'muscle';
        _mode = Mode.cut;
      default:
        _track = 'weight';
        _mode = Mode.lose;
    }
    _steps = switch (_track) {
      'family' => const ['members', 'kids', 'cooker', 'result'],
      'medical' => const ['consent'],
      _ => const ['health', 'sex', 'age', 'height', 'weight', 'goal', 'activity', 'pace', 'result'],
    };
    _a.clear();
    _qi = 0;
    setState(() => _flow = _Flow.q);
  }

  void _back() => setState(() {
        switch (_flow) {
          case _Flow.catalog:
            break;
          case _Flow.help1:
            _flow = _Flow.catalog;
          case _Flow.help2:
            _flow = _Flow.help1;
          case _Flow.reco:
            _flow = _Flow.catalog;
          case _Flow.q:
            if (_qi > 0) {
              _qi--;
            } else {
              _flow = _Flow.catalog;
            }
        }
      });

  bool get _atRoot => _flow == _Flow.catalog;

  bool _locked = false;

  void _answer(String key, Object? v) {
    if (_locked) return; // نقرتان سريعتان لا تتخطيان سؤالاً
    _locked = true;
    _a[key] = v;
    Future.delayed(const Duration(milliseconds: 140), () async {
      if (!mounted) return;
      _locked = false;
      final cur = _steps[_qi];
      // فحص صحي: غير «لا» ← صفحة إحالة بدل المتابعة
      if (cur == 'health' && v != 'none') {
        setState(() => _steps = const ['health', 'blocked']);
        _qi = 1;
        return;
      }
      if (_steps[_qi + 1] == 'result') await _computeResult();
      if (mounted) setState(() => _qi++);
    });
  }

  // ---- الحساب من الشرائح ----
  Future<void> _computeResult() async {
    if (_track == 'family') {
      final eaters = (_a['members'] as int?) ?? 5, kids = ((_a['kids'] as int?) ?? 0).clamp(0, eaters - 1);
      final prog = await widget.library.program('saudi_family');
      _prog = prog;
      _servings = (eaters - kids) + 0.5 * kids;
      _draft = JourneyDraft(track: 'family', programId: 'saudi_family', eaters: eaters, kids: kids, cooker: _a['cooker'] as String?);
      return;
    }
    final w = (_a['weight'] as num).toDouble(), h = (_a['height'] as num).toDouble();
    final delta = (_a['goal'] as num?)?.toDouble();
    double? goal;
    if (delta != null) goal = _mode == Mode.gain ? w + delta : w - delta;
    final prof = Profile(
        sex: _a['sex'] as Sex, age: (_a['age'] as num).round(), heightCm: h, weightKg: w,
        activity: _a['activity'] as Activity, goalKg: goal, paceKgWeek: (_a['pace'] as num?)?.toDouble() ?? 0.5, mode: _mode);
    final plan = planFor(prof)!;
    final prog = await widget.library.program(_pid!);
    _prog = prog;
    _draft = JourneyDraft(track: _track, programId: _pid!, profile: prof, plan: plan, portion: portionFor(prog, plan.kcal));
  }

  void _save() {
    JourneyDraft.current = _draft;
    if (widget.session.signedIn) {
      context.go(widget.update ? '/journey/finish?update=1' : '/journey/finish');
    } else {
      context.push('/login?next=${Uri.encodeComponent('/journey/finish')}');
    }
  }

  // ---- الواجهة ----
  @override
  Widget build(BuildContext context) {
    final progress = _flow == _Flow.q && _steps.isNotEmpty ? (_qi + 1) / _steps.length : null;
    return PopScope(
      canPop: _atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
                  child: Row(children: [
                    IconButton(
                      onPressed: _atRoot ? (context.canPop() ? () => context.pop() : null) : _back,
                      icon: Icon(Icons.arrow_forward, color: (_atRoot && !context.canPop()) ? Colors.transparent : Brand.green),
                    ),
                    Expanded(
                      child: progress == null
                          ? const SizedBox.shrink()
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Brand.green.withValues(alpha: .12), color: Brand.honey),
                            ),
                    ),
                  ]),
                ),
                Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: KeyedSubtree(key: ValueKey('$_flow$_qi${_steps.length}'), child: _page()))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _page() => switch (_flow) {
        _Flow.catalog => _catalog(),
        _Flow.help1 => _helpGoalPage(),
        _Flow.help2 => _helpStylePage(),
        _Flow.reco => _recoPage(),
        _Flow.q => _questionPage(_steps[_qi]),
      };

  // ---- شاشة الأنظمة ----
  Widget _catalog() {
    final progs = widget.library.active;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
      const Text('اختر نظامك', style: TextStyle(fontSize: 28, fontWeight: black, color: Brand.green)),
      const SizedBox(height: 4),
      const Text('اضغط النظام لتبدأ مباشرة، أو اطلب المساعدة.', style: TextStyle(fontSize: 14, color: Brand.grey)),
      const SizedBox(height: 12),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: () => setState(() => _flow = _Flow.help1),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('ساعدني في الاختيار — اختر لي', style: TextStyle(fontSize: 17, fontWeight: black)),
      ),
      const SizedBox(height: 14),
      for (final p in progs)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CardBox(
            onTap: () => _select(p.id),
            child: Row(children: [
              Text(p.icon, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Brand.green)),
                  const SizedBox(height: 2),
                  Text(p.blurb, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Brand.grey, height: 1.5)),
                ]),
              ),
              TextButton(onPressed: () => context.push('/programs/${p.id}'), child: const Text('معاينة')),
            ]),
          ),
        ),
      const SizedBox(height: 6),
      // طريق ظاهر للطاهي والأخصائي (لا يسجّلان بالرحلة): الطاهي بدعوة، والأخصائي بطلب يراجعه المدير
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text('هل أنت طاهٍ أو أخصائي؟', style: TextStyle(fontSize: 18, fontWeight: black, color: Brand.green)),
      ),
      CardBox(
        onTap: () => context.push('/join/cook'),
        child: const Row(children: [
          Text('👨‍🍳', style: TextStyle(fontSize: 32)),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أنا طاهٍ — عندي رمز دعوة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Brand.green)),
            Text('يدعوك مدير البيت برمز أو رابط، فتدخل وترى وجبات اليوم فقط.', style: TextStyle(fontSize: 13, color: Brand.grey, height: 1.5)),
          ])),
          Icon(Icons.chevron_left, color: Brand.grey),
        ]),
      ),
      const SizedBox(height: 10),
      CardBox(
        onTap: () => context.push('/doctor/apply'),
        child: const Row(children: [
          Text('🩺', style: TextStyle(fontSize: 32)),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أنا طبيب أو أخصائي تغذية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Brand.green)),
            Text('قدّم بياناتك المهنية وتُراجَع مرة واحدة قبل اعتماد حسابك.', style: TextStyle(fontSize: 13, color: Brand.grey, height: 1.5)),
          ])),
          Icon(Icons.chevron_left, color: Brand.grey),
        ]),
      ),
      if (!widget.session.signedIn)
        Center(child: TextButton(onPressed: () => context.push('/login'), child: const Text('لدي حساب — دخول'))),
    ]);
  }

  // ---- مساعد الاختيار («اختر لي»): سؤالان ثم ترشيح واحد ----
  Widget _helpGoalPage() => _optionsPage(
        'ما هدفك الأهم؟', null,
        [
          const _Opt('أنقص وزني', 'lose', icon: '⚖️'),
          const _Opt('أبني عضلاً', 'gain', icon: '💪'),
          const _Opt('أنشّف جسمي', 'cut', icon: '🔥'),
          const _Opt('أدير غذاء أسرتي', 'family', icon: '👨‍👩‍👧‍👦'),
          const _Opt('عندي حالة صحية', 'health', icon: '🩺'),
        ],
        (v) {
          _helpGoal = v as String;
          setState(() => _flow = (v == 'lose' || v == 'health') ? _Flow.help2 : _Flow.reco);
        },
      );

  Widget _helpStylePage() => _helpGoal == 'health'
      ? _optionsPage('أي حالة؟', null, [
          const _Opt('النظام الخفيف', 'kidney_salama', icon: '🥗'),
          const _Opt('السكري أو الضغط أو الحمل', 'soon', icon: '🩸', sub: 'قيد الإعداد'),
        ], (v) {
          _helpGoal = v as String;
          setState(() => _flow = _Flow.reco);
        })
      : _optionsPage('كيف تفضّل أن تأكل؟', null, [
          const _Opt('متوازن ومرن', 'weight_loss_general', icon: '🥗'),
          const _Opt('كارب قليل', 'low_carb', icon: '🥩'),
          const _Opt('كيتو صارم', 'keto_general', icon: '🥑'),
          const _Opt('أتمرن وأريد طاقة', 'carb_cycle', icon: '🔄'),
          const _Opt('لا أعرف', 'weight_loss_general', icon: '🤷'),
        ], (v) {
          _helpGoal = v as String;
          setState(() => _flow = _Flow.reco);
        });

  String get _recoId => switch (_helpGoal) {
        'gain' => 'muscle_gain',
        'cut' => 'cutting_gym',
        'family' => 'saudi_family',
        'soon' => 'soon',
        final g? when widget.library.meta(g) != null => g,
        _ => 'weight_loss_general',
      };

  static const _reasons = {
    'muscle_gain': 'فائض سعرات وبروتين عالٍ يدعمان بناء العضل مع التمرين.',
    'cutting_gym': 'عجز سعرات مع بروتين عالٍ لإظهار العضل وحفظه.',
    'saudi_family': 'وجبات سعودية مألوفة لأسرتك بمقاديرها ومشترياتها.',
    'kidney_salama': 'وجبات خفيفة بمقادير معتدلة، لتنظيم أسبوعك.',
    'weight_loss_general': 'عجز معتدل يمكن الاستمرار عليه، بحصص محسوبة.',
    'low_carb': 'تقليل النشويات مع مرونة أكبر من الكيتو.',
    'keto_general': 'كارب منخفض جداً ودهون عالية لمن يريد الالتزام الصارم.',
    'carb_cycle': 'أيام كارب أعلى وأخرى أقل لتوازن بين التنحيف والطاقة.',
  };

  Widget _recoPage() {
    final id = _recoId;
    if (id == 'soon') {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🩸', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text('هذه الحالات قيد الإعداد', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: black, color: Brand.green)),
          const SizedBox(height: 8),
          const Text('لا نطلقها قبل مرجع طبي موثوق لكل حالة. عالجها مع طبيبك الآن.', textAlign: TextAlign.center, style: TextStyle(color: Brand.grey, height: 1.7)),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: () => setState(() => _flow = _Flow.catalog), child: const Text('رجوع للأنظمة')),
        ]),
      );
    }
    final m = widget.library.meta(id)!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('نرشّح لك', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Brand.grey)),
        const SizedBox(height: 10),
        CardBox(
          padding: const EdgeInsets.all(22),
          border: Border.all(color: Brand.honey, width: 2),
          child: Column(children: [
            Text(m.icon, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text(m.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: black, color: Brand.green)),
            const SizedBox(height: 8),
            Text(_reasons[id] ?? m.blurb, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, height: 1.7, color: Brand.grey)),
          ]),
        ),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: () => _select(id),
          child: const Text('ابدأ بهذا النظام', style: TextStyle(fontSize: 18, fontWeight: black)),
        ),
        TextButton(onPressed: () => setState(() => _flow = _Flow.catalog), child: const Text('أرني غيره')),
      ]),
    );
  }

  // ---- صفحات الأسئلة ----
  Widget _questionPage(String step) {
    switch (step) {
      case 'health':
        return _optionsPage('هل عندك حالة خاصة؟', 'للسلامة: بعض الحالات تحتاج أخصائياً لا حاسبة.', [
          const _Opt('لا، لا شيء من ذلك', 'none', icon: '✅'),
          const _Opt('حامل أو مرضعة', 'preg', icon: '🤰'),
          const _Opt('سكري أو كلى أو ضغط', 'chronic', icon: '🩺'),
          const _Opt('اضطراب في الأكل', 'ed', icon: '⚠️'),
        ], (v) => _answer('health', v));
      case 'blocked':
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🩺', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text('حالتك تحتاج أخصائي تغذية', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: black, color: Brand.green)),
            const SizedBox(height: 8),
            const Text('لا نحسب السعرات آلياً لحالتك لسلامتك. اعرض نظامك على طبيبك أو أخصائيك.', textAlign: TextAlign.center, style: TextStyle(color: Brand.grey, height: 1.7)),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: () => setState(() => _flow = _Flow.catalog), child: const Text('رجوع للأنظمة')),
          ]),
        );
      case 'sex':
        return _optionsPage('أنت…', null, [const _Opt('أنثى', Sex.female, icon: '👩'), const _Opt('ذكر', Sex.male, icon: '👨')], (v) => _answer('sex', v));
      case 'age':
        return _optionsPage('كم عمرك؟', null, [
          for (final e in const [('18–25', 22), ('26–35', 30), ('36–45', 40), ('46–55', 50), ('56 فأكثر', 60)]) _Opt(e.$1, e.$2),
        ], (v) => _answer('age', v), grid: true);
      case 'height':
        return _optionsPage('كم طولك؟', 'بالسنتيمتر', [
          for (final e in const [('أقل من 155', 150), ('155–159', 157), ('160–164', 162), ('165–169', 167), ('170–174', 172), ('175–179', 177), ('180–184', 182), ('185 فأكثر', 188)]) _Opt(e.$1, e.$2),
        ], (v) => _answer('height', v), grid: true);
      case 'weight':
        return _optionsPage('كم وزنك الآن؟', 'بالكيلوجرام', [
          const _Opt('أقل من 55', 52),
          for (var lo = 55; lo < 120; lo += 5) _Opt('$lo–${lo + 4}', lo + 2),
          const _Opt('120 فأكثر', 125),
        ], (v) => _answer('weight', v), grid: true);
      case 'goal':
        return _goalPage();
      case 'activity':
        return _optionsPage('كم تتحرك يومياً؟', null, [
          const _Opt('أجلس غالباً', Activity.sedentary, icon: '🪑'),
          const _Opt('أمشي قليلاً', Activity.light, icon: '🚶'),
          const _Opt('أتمرن ٣–٥ أيام', Activity.moderate, icon: '🏃'),
          const _Opt('أتمرن يومياً', Activity.high, icon: '🏋️'),
          const _Opt('رياضي محترف', Activity.athlete, icon: '🏅'),
        ], (v) => _answer('activity', v));
      case 'pace':
        return _optionsPage(_mode == Mode.gain ? 'بأي سرعة تريد البناء؟' : 'بأي سرعة تريد النزول؟', null, [
          _Opt('هادئ', 0.25, icon: '🐢', sub: _mode == Mode.gain ? 'فائض صغير' : '٠٫٢٥ كجم أسبوعياً'),
          _Opt('متوازن', 0.5, icon: '⚖️', sub: _mode == Mode.gain ? 'فائض معتدل' : '٠٫٥ كجم أسبوعياً'),
          _Opt('سريع', 0.75, icon: '🐇', sub: _mode == Mode.gain ? 'فائض كبير' : '٠٫٧٥ كجم أسبوعياً'),
        ], (v) => _answer('pace', v));
      case 'members':
        return _optionsPage('كم عدد أفراد الأسرة؟', null, [
          for (var n = 2; n <= 7; n++) _Opt('$n', n),
          const _Opt('8 فأكثر', 8),
        ], (v) => _answer('members', v), grid: true);
      case 'kids':
        final max = ((_a['members'] as int?) ?? 5) - 1;
        return _optionsPage('كم منهم أطفال؟', 'الطفل يُحسب بنصف حصة', [
          for (var n = 0; n <= 4 && n <= max; n++) _Opt(n == 0 ? 'لا أحد' : '$n', n),
        ], (v) => _answer('kids', v), grid: true);
      case 'cooker':
        return _optionsPage('من يطبخ في بيتكم؟', null, [
          const _Opt('أنا', 'me', icon: '👩‍🍳'),
          const _Opt('طاهٍ أو طاهية عندنا', 'cook', icon: '🧑‍🍳'),
          const _Opt('أحد أفراد الأسرة', 'other', icon: '👪'),
        ], (v) => _answer('cooker', v));
      case 'consent':
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('🥗', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
            const SizedBox(height: 10),
            const Text('النظام الخفيف', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: black, color: Brand.green)),
            const SizedBox(height: 8),
            const Text('وجبات خفيفة بمقادير معتدلة لتنظيم أسبوعك. لا نحسب لك سعرات آلياً، وهو ليس علاجاً ولا بديلاً عن طبيبك: استشره قبل الالتزام به إن كانت لديك حالة صحية.',
                textAlign: TextAlign.center, style: TextStyle(height: 1.8, color: Brand.grey)),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Brand.green, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                _draft = const JourneyDraft(track: 'medical', programId: 'kidney_salama');
                _save();
              },
              child: const Text('أفهم، تابع', style: TextStyle(fontSize: 18, fontWeight: black)),
            ),
          ]),
        );
      case 'result':
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [_resultStep()]);
    }
    return const SizedBox.shrink();
  }

  /// الهدف نسبي (كم تنقص/تزيد) لا رقماً مكتوباً. تُخفى الخيارات التي تنزل عن حدّ كتلة الجسم الصحي.
  Widget _goalPage() {
    final w = (_a['weight'] as num).toDouble(), h = (_a['height'] as num).toDouble();
    final minGoal = (18.5 * (h / 100) * (h / 100)).clamp(40, 200).toDouble();
    if (_mode == Mode.gain) {
      return _optionsPage('كم تريد أن تزيد؟', null, [
        const _Opt<int?>('3 كجم', 3), const _Opt<int?>('5 كجم', 5), const _Opt<int?>('8 كجم', 8), const _Opt<int?>('لا أحدد', null),
      ], (v) => _answer('goal', v), grid: true, cols: 2);
    }
    final opts = <_Opt<int?>>[for (final k in const [5, 10, 15, 20, 25]) if (w - k >= minGoal) _Opt<int?>('أنقص $k كجم', k)];
    if (opts.isEmpty) opts.add(const _Opt<int?>('أثبّت وزني', null));
    return _optionsPage('كم تريد أن تنقص؟', null, opts, (v) => _answer('goal', v), grid: true, cols: 2);
  }

  /// صفحة خيارات كاملة: عنوان كبير وأزرار ضخمة. [grid] للشرائح (٣ أعمدة)، وإلا قائمة بطاقات كبيرة.
  Widget _optionsPage<T>(String title, String? sub, List<_Opt<T>> opts, void Function(Object? v) onPick, {bool grid = false, int cols = 3}) {
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: black, color: Brand.green, height: 1.3)),
        if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, style: const TextStyle(fontSize: 14, color: Brand.grey))),
      ]),
    );
    if (grid) {
      return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        head,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final o in opts)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width.clamp(0, 520) - 32 - 10 * (cols - 1)) / cols,
                child: _OptButton(label: o.label, icon: o.icon, sub: o.sub, compact: true, onTap: () => onPick(o.value)),
              ),
          ]),
        ),
      ]);
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      head,
      for (final o in opts)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _OptButton(label: o.label, icon: o.icon, sub: o.sub, onTap: () => onPick(o.value)),
        ),
    ]);
  }

  Widget _macro(String l, String v) => Expanded(
        child: Column(children: [
          Text(v, style: const TextStyle(fontSize: 20, fontWeight: black, color: Brand.green)),
          Text(l, style: const TextStyle(fontSize: 13, color: Brand.grey)),
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
      final k = _draft!.plan != null ? portion : 1.0;
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
        const Expanded(child: Text('المجموع التقريبي (الأيام تتفاوت قليلاً حول هدفك)', style: TextStyle(fontWeight: black, fontSize: 13))),
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
          Text(_mode == Mode.gain ? 'سعراتك اليومية للبناء' : 'سعراتك اليومية المقترحة', style: TextStyle(color: Brand.grey)),
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
          if (plan.note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(plan.note!, style: const TextStyle(fontSize: 13, color: Brand.honey))),
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
            style: TextStyle(fontSize: 13, height: 1.7)),
      ),
      const SizedBox(height: 16),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(56)),
        onPressed: _save,
        child: Text(widget.session.signedIn ? 'ابدأ خطتي' : 'ابدأ خطتي (سنطلب الدخول لحفظها)', style: const TextStyle(fontSize: 18, fontWeight: black)),
      ),
    ]);
  }

}

/// زر خيار كبير: يضيء لحظة عند النقر ثم تتقدّم الصفحة.
class _OptButton extends StatefulWidget {
  final String label;
  final String? icon, sub;
  final bool compact;
  final VoidCallback onTap;
  const _OptButton({required this.label, required this.onTap, this.icon, this.sub, this.compact = false});

  @override
  State<_OptButton> createState() => _OptButtonState();
}

class _OptButtonState extends State<_OptButton> {
  bool _on = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _on = true);
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: widget.compact ? 18 : 18),
          decoration: BoxDecoration(
            color: _on ? Brand.green : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _on ? Brand.green : Brand.green.withValues(alpha: .25), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: widget.compact
              ? Text(widget.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _on ? Colors.white : Brand.green))
              : Row(children: [
                  if (widget.icon != null) ...[Text(widget.icon!, style: const TextStyle(fontSize: 30)), const SizedBox(width: 14)],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.label, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _on ? Colors.white : Brand.green)),
                      if (widget.sub != null) Text(widget.sub!, style: TextStyle(fontSize: 13, color: _on ? Colors.white70 : Brand.grey)),
                    ]),
                  ),
                ]),
        ),
      );
}

/// يحوّل المسودة إلى بيت حقيقي بعد الدخول، ثم يفتح الشاشة الرئيسية.
class JourneyFinishScreen extends StatefulWidget {
  final LinkService links;
  final Session session;
  final bool update;
  const JourneyFinishScreen({super.key, required this.links, required this.session, this.update = false});

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
    if (widget.update && d != null && widget.links.hasHousehold) {
      try {
        await widget.links.applyJourney(d.programId, d.eaters, d.toHousehold());
        JourneyDraft.current = null;
        if (mounted) context.go('/me');
      } catch (_) {
        if (mounted) setState(() => _error = 'تعذّر تغيير النظام. تحقق من الاتصال وأعد المحاولة.');
      }
      return;
    }
    if (d == null || widget.links.hasHousehold) {
      if (mounted) context.go(widget.links.hasHousehold ? '/me' : '/new-house');
      return;
    }
    try {
      final name = widget.session.user?.name.split(' ').first ?? '';
      await widget.links.createHousehold(name.isEmpty ? 'بيتي' : 'بيت $name', d.programId, d.eaters, extra: d.toHousehold());
      JourneyDraft.current = null;
      // ننتظر وصول البيت من Firestore قبل الانتقال، وإلا رأى الجهاز «بلا دور» لحظة وفُتحت شاشة اختيار الدور
      for (var i = 0; i < 40 && !widget.links.hasHousehold; i++) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      if (mounted) context.go('/review');
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
