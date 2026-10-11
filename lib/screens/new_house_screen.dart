import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../data/growth.dart';
import '../data/links.dart';
import '../data/repository.dart';
import '../logic/names.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/medical_note.dart';

/// إنشاء البيت في شاشة واحدة: اختيار النظام + اسم البيت + الموافقة (بدل أربع شاشات متتالية).
class NewHouseScreen extends StatefulWidget {
  final Library library;
  final LinkService links;
  final Session session;
  /// قادم من رابط طبيب: بعد إنشاء البيت يُرسَل طلب الربط به.
  final GrowthService? growth;
  final String? doctorCode;
  const NewHouseScreen({super.key, required this.library, required this.links, required this.session, this.growth, this.doctorCode});

  @override
  State<NewHouseScreen> createState() => _NewHouseScreenState();
}

class _NewHouseScreenState extends State<NewHouseScreen> {
  String? _program;
  late final _name = TextEditingController(text: _suggest());
  int _eaters = 1;
  bool _consent = false, _busy = false;
  String? _error;

  String _suggest() {
    final n = firstName(widget.session.user?.name ?? '');
    return n.isEmpty ? '' : 'بيت $n';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ok => _program != null && _name.text.trim().isNotEmpty && _consent && !_busy;

  Future<void> _create() async {
    setState(() { _busy = true; _error = null; });
    try {
      await widget.links.createHousehold(_name.text, _program!, _eaters);
      final dr = widget.doctorCode;
      if (dr != null && widget.growth != null) await widget.growth!.requestLink(dr); // فشله لا يمنع إنشاء البيت
      if (mounted) context.go('/me');
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'تعذّر إنشاء البيت. تأكد من الاتصال وحاول مرة أخرى.'; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [
          const GreenHeader(icon: '🏠', title: 'أنشئ بيتك', subtitle: 'اختر نظامك وسمِّ بيتك، وتبدأ فوراً'),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('١ · اختر النظام', style: TextStyle(fontSize: 17, fontWeight: black, color: Brand.green)),
                  const SizedBox(height: 10),
                  for (final p in widget.library.active) ...[
                    CardBox(
                      onTap: () => setState(() {
                        _program = p.id;
                        if (p.id == 'saudi_family' && _eaters == 1) _eaters = 5; // أسرة سعودية نموذجية
                      }),
                      border: Border.all(color: _program == p.id ? Brand.honey : Colors.transparent, width: 2.5),
                      child: Row(children: [
                        Text(p.icon, style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.label, style: const TextStyle(fontSize: 17, fontWeight: black)),
                          Text(p.blurb, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: Brand.grey, height: 1.5)),
                        ])),
                        const SizedBox(width: 8),
                        Column(children: [
                          Icon(_program == p.id ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: _program == p.id ? Brand.honey : Colors.grey),
                          GestureDetector(
                            onTap: () => context.push('/programs/${p.id}'),
                            child: const Padding(padding: EdgeInsets.only(top: 4),
                                child: Text('معاينة', style: TextStyle(fontSize: 12, color: Brand.green, decoration: TextDecoration.underline))),
                          ),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_program == 'kidney_salama')
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Brand.amber50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Brand.honey)),
                      child: const Text('هذا النظام لمرضى الكلى منقول من دليل مستشفى متخصص. استشر طبيبك قبل البدء، ويمكنك دعوة طبيبك لمتابعة خطتك بعد إنشاء البيت.',
                          style: TextStyle(fontSize: 13, height: 1.7, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 10),
                  const Text('٢ · سمِّ بيتك', style: TextStyle(fontSize: 17, fontWeight: black, color: Brand.green)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _name,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'اسم البيت أو مدير البيت', hintText: 'مثال: بيت أبو عبدالله',
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CardBox(child: Row(children: [
                    const Expanded(child: Text('عدد من يأكل', style: TextStyle(fontWeight: black))),
                    IconButton(onPressed: _eaters > 1 ? () => setState(() => _eaters--) : null, icon: const Icon(Icons.remove_circle_outline)),
                    Text('$_eaters', style: const TextStyle(fontSize: 20, fontWeight: black)),
                    IconButton(onPressed: _eaters < 12 ? () => setState(() => _eaters++) : null, icon: const Icon(Icons.add_circle_outline)),
                  ])),
                  CheckboxListTile(
                    value: _consent,
                    onChanged: (v) => setState(() => _consent = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('أوافق على تخزين بياناتي الغذائية لتشغيل التطبيق', style: TextStyle(fontSize: 13)),
                  ),
                  if (_error != null)
                    Padding(padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(54)),
                    onPressed: _ok ? _create : null,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('ابدأ', style: TextStyle(fontSize: 18, fontWeight: black)),
                  ),
                  const MedicalNote(),
                ]),
              ),
            ),
          ),
        ]),
      );
}
