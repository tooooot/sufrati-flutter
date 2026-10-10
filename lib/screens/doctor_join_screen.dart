import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/roles.dart';
import '../auth/session.dart';
import '../data/growth.dart';
import '../routing.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// `/dr/<رمز>/join` بعد الدخول: بلا بيت ← إنشاء بيت (مع حمل الرمز)، وبعد البيت ← إرسال طلب الربط للطبيب.
class DoctorJoinScreen extends StatefulWidget {
  final Session session;
  final GrowthService growth;
  final String code;
  const DoctorJoinScreen({super.key, required this.session, required this.growth, required this.code});

  @override
  State<DoctorJoinScreen> createState() => _DoctorJoinScreenState();
}

class _DoctorJoinScreenState extends State<DoctorJoinScreen> {
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final s = widget.session;
    if (!s.links.ready) {
      s.links.addListener(_waitReady);
      return;
    }
    if (!s.links.hasHousehold) {
      s.chooseRole(Role.owner);
      if (mounted) context.go('/new-house?dr=${widget.code}');
      return;
    }
    final err = await widget.growth.requestLink(widget.code);
    if (!mounted) return;
    setState(() { _error = err; _done = err == null; });
  }

  void _waitReady() {
    if (widget.session.links.ready) {
      widget.session.links.removeListener(_waitReady);
      _go();
    }
  }

  @override
  void dispose() {
    widget.session.links.removeListener(_waitReady);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [
          GreenHeader(icon: _done ? '✅' : (_error != null ? '⚠️' : '🩺'),
              title: _done ? 'أُرسل طلبك للطبيب' : (_error != null ? 'تعذّر الإرسال' : 'جارٍ ربطك بالطبيب')),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              if (!_done && _error == null) const CircularProgressIndicator(color: Brand.green),
              if (_error != null) Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Brand.grey, height: 1.7)),
              if (_done)
                const Text('سيرى الطبيب خطتك بعد قبوله الطلب. تستطيع الآن استعمال التطبيق كالمعتاد.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Brand.grey, height: 1.7)),
              const SizedBox(height: 18),
              if (_done || _error != null)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size(220, 50)),
                  onPressed: () => context.go(landing(widget.session)),
                  child: const Text('متابعة', style: TextStyle(fontWeight: black)),
                ),
            ]),
          ),
        ]),
      );
}
