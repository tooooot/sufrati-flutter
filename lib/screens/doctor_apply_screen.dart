import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// طلب الانضمام كطبيب/أخصائي: بياناته المهنية تُرسل مع الطلب فيراجعها المدير مرة واحدة،
/// وبعد الموافقة يصير حسابه وبروفايله العام ورابطه جاهزة معاً (موافقة واحدة بدل اثنتين).
class DoctorApplyScreen extends StatefulWidget {
  final Session session;
  const DoctorApplyScreen({super.key, required this.session});

  @override
  State<DoctorApplyScreen> createState() => _DoctorApplyScreenState();
}

class _DoctorApplyScreenState extends State<DoctorApplyScreen> {
  late final _name = TextEditingController(text: widget.session.user?.name ?? '');
  final _spec = TextEditingController(), _city = TextEditingController(), _bio = TextEditingController(), _lic = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    for (final c in [_name, _spec, _city, _bio, _lic]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _f(TextEditingController c, String label, {int lines = 1, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c, minLines: lines, maxLines: lines, onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        ),
      );

  bool get _ok => _name.text.trim().isNotEmpty && _spec.text.trim().isNotEmpty && _lic.text.trim().isNotEmpty && !_busy;

  Future<void> _send() async {
    setState(() { _busy = true; _err = null; });
    try {
      await widget.session.links.requestDoctor(draft: {
        'name': _name.text.trim(), 'specialty': _spec.text.trim(), 'city': _city.text.trim(),
        'bio': _bio.text.trim(), 'licenseNo': _lic.text.trim(),
      });
      if (mounted) context.go('/doctor-pending');
    } catch (_) {
      if (mounted) setState(() { _busy = false; _err = 'تعذّر إرسال الطلب. حاول مرة أخرى.'; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [
          GreenHeader(
            icon: '🩺', title: 'طلب الانضمام كطبيب أو أخصائي', subtitle: 'مراجعة واحدة، ثم يصير ملفك ورابطك جاهزين',
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.go('/role')),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _f(_name, 'الاسم كما يظهر للمتابعين', hint: 'د. أحمد الشهري'),
                  _f(_spec, 'التخصص', hint: 'أخصائي تغذية علاجية'),
                  _f(_city, 'المدينة'),
                  _f(_bio, 'نبذة قصيرة (اختياري)', lines: 3),
                  _f(_lic, 'رقم الترخيص المهني (الهيئة السعودية للتخصصات الصحية)'),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('يراجع المدير الرقم قبل الاعتماد. يظهر اسمك وتخصصك ورقمك في صفحتك العامة بعد الاعتماد.',
                        style: TextStyle(fontSize: 12.5, color: Brand.grey, height: 1.6)),
                  ),
                  if (_err != null)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_err!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800))),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(54)),
                    onPressed: _ok ? _send : null,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('إرسال الطلب', style: TextStyle(fontSize: 18, fontWeight: black)),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      );
}
