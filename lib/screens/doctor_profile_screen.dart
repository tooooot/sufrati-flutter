import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/roles.dart';
import '../data/growth.dart';
import '../data/links.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// ملف الطبيب المهني: بياناته العامة، رابطه للمتابعين، طلبات الربط، ومرضاه.
class DoctorProfileScreen extends StatefulWidget {
  final GrowthService growth;
  final LinkService links;
  const DoctorProfileScreen({super.key, required this.growth, required this.links});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _name = TextEditingController(), _spec = TextEditingController(), _city = TextEditingController(),
      _bio = TextEditingController(), _lic = TextEditingController();
  DoctorProfile? _p;
  List<LinkRequest> _reqs = const [];
  bool _loading = true, _saving = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.growth.myProfile();
      final r = p == null ? const <LinkRequest>[] : await widget.growth.requests();
      if (!mounted) return;
      setState(() {
        _p = p;
        _reqs = r;
        _loading = false;
        if (p != null) {
          _name.text = p.name; _spec.text = p.specialty; _city.text = p.city; _bio.text = p.bio; _lic.text = p.licenseNo;
        }
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _msg = 'تعذّر التحميل.'; });
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _msg = 'اكتب اسمك كما يظهر للمتابعين.');
      return;
    }
    setState(() { _saving = true; _msg = null; });
    try {
      final p = await widget.growth.saveProfile(name: _name.text, specialty: _spec.text, city: _city.text, bio: _bio.text, licenseNo: _lic.text);
      if (mounted) setState(() { _p = p; _saving = false; _msg = 'حُفظ ✓'; });
    } catch (_) {
      if (mounted) setState(() { _saving = false; _msg = 'تعذّر الحفظ. حاول مرة أخرى.'; });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _spec, _city, _bio, _lic]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, {int lines = 1, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c, minLines: lines, maxLines: lines,
          decoration: InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final patients = widget.links.memberships.where((m) => m.role == Role.doctor).toList();
    final p = _p;
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        GreenHeader(
          icon: '🩺', title: 'ملفي المهني', subtitle: 'يراه متابعوك قبل أن يبدؤوا معك',
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.canPop() ? context.pop() : context.go('/me')),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Brand.green)))
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      CardBox(
                        child: Row(children: [
                          Icon(p?.verified == true ? Icons.verified : Icons.hourglass_top, color: p?.verified == true ? Brand.honey : Brand.grey),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p == null
                                  ? 'أنشئ ملفك: بعد حفظه تراجعه الإدارة وتضع عليه شارة «معتمد».'
                                  : (p.verified ? 'معتمد — رابطك يعمل للجميع.' : 'قيد المراجعة — رابطك سيعمل بعد اعتماد الإدارة.'),
                              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.6),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      _field(_name, 'الاسم كما يظهر للمتابعين', hint: 'د. أحمد الشهري'),
                      _field(_spec, 'التخصص', hint: 'أخصائي تغذية علاجية'),
                      _field(_city, 'المدينة'),
                      _field(_bio, 'نبذة قصيرة', lines: 3),
                      _field(_lic, 'رقم الترخيص المهني', hint: 'يُعرض للمتابعين ويراجعه المدير'),
                      if (_msg != null)
                        Padding(padding: const EdgeInsets.only(bottom: 8),
                            child: Text(_msg!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.green))),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Brand.green, minimumSize: const Size.fromHeight(52)),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('حفظ', style: TextStyle(fontSize: 17, fontWeight: black)),
                      ),
                      if (p != null) ...[
                        const SizedBox(height: 20),
                        const Text('رابطك للمتابعين', style: TextStyle(fontWeight: black, fontSize: 17)),
                        const SizedBox(height: 8),
                        CardBox(
                          child: Column(children: [
                            SelectableText(p.link, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: black, color: Brand.green)),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.copy),
                                  label: const Text('نسخ'),
                                  onPressed: () async {
                                    final m = ScaffoldMessenger.of(context);
                                    await Clipboard.setData(ClipboardData(text: p.link));
                                    m.showSnackBar(const SnackBar(content: Text('نُسخ الرابط')));
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                                  icon: const Icon(Icons.share),
                                  label: const Text('واتساب'),
                                  onPressed: () => launchUrl(
                                      Uri.parse('https://wa.me/?text=${Uri.encodeComponent('جرّب نظامي الغذائي في تطبيق سفرتي:\n${p.link}')}'),
                                      mode: LaunchMode.externalApplication),
                                ),
                              ),
                            ]),
                          ]),
                        ),
                      ],
                      if (_reqs.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text('طلبات الربط', style: TextStyle(fontWeight: black, fontSize: 17)),
                        const SizedBox(height: 8),
                        for (final r in _reqs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: CardBox(
                              child: Row(children: [
                                const Icon(Icons.person_add_alt_1, color: Brand.green),
                                const SizedBox(width: 10),
                                Expanded(child: Text(r.fromName.isEmpty ? 'مستخدم' : r.fromName, style: const TextStyle(fontWeight: black))),
                                IconButton(
                                  tooltip: 'رفض',
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () async { await widget.growth.decline(r); _load(); },
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Brand.green),
                                  onPressed: () async {
                                    final m = ScaffoldMessenger.of(context);
                                    final err = await widget.growth.accept(r);
                                    if (err != null) m.showSnackBar(SnackBar(content: Text(err)));
                                    _load();
                                  },
                                  child: const Text('قبول'),
                                ),
                              ]),
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                      const Text('مرضاي', style: TextStyle(fontWeight: black, fontSize: 17)),
                      const SizedBox(height: 8),
                      if (patients.isEmpty)
                        const CardBox(child: Text('لم يرتبط بك أحد بعد.', style: TextStyle(color: Brand.grey)))
                      else
                        for (final m in patients)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: CardBox(
                              onTap: () { widget.links.selectHousehold(m.householdId); context.go('/me'); },
                              child: Row(children: [
                                const Icon(Icons.home_outlined, color: Brand.green),
                                const SizedBox(width: 10),
                                Expanded(child: Text(m.householdLabel, style: const TextStyle(fontWeight: black))),
                                const Icon(Icons.chevron_left),
                              ]),
                            ),
                          ),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }
}
