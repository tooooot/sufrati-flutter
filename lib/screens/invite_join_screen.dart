import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/roles.dart';
import '../auth/session.dart';
import '../data/links.dart';
import '../routing.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// رابط دعوة /i/<رمز>: بعد الدخول ينضم المستخدم مباشرة بالدور المكتوب في الدعوة (بلا اختيار دور ولا كتابة رمز).
class InviteJoinScreen extends StatefulWidget {
  final Session session;
  final LinkService links;
  final String code;
  const InviteJoinScreen({super.key, required this.session, required this.links, required this.code});

  @override
  State<InviteJoinScreen> createState() => _InviteJoinScreenState();
}

class _InviteJoinScreenState extends State<InviteJoinScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    try {
      final r = await widget.links.redeemAny(widget.code, who: widget.session.user?.name ?? 'مستخدم');
      if (!mounted) return;
      if (r.error != null) {
        setState(() => _error = r.error);
        return;
      }
      final role = r.role!;
      if (role == Role.doctor && !widget.links.isDoctor) {
        await widget.links.requestDoctor(); // انضم للبيت، وحساب الطبيب ينتظر موافقة المدير
        if (mounted) context.go('/doctor-pending');
        return;
      }
      widget.session.chooseRole(role);
      if (mounted) context.go(landing(widget.session));
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر الاتصال. تأكد من الإنترنت وحاول مرة أخرى.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [
          GreenHeader(icon: _error == null ? '🤝' : '⚠️', title: _error == null ? 'جارٍ انضمامك للبيت' : 'تعذّر الانضمام'),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              if (_error == null)
                const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Brand.green))
              else ...[
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Brand.grey, height: 1.7)),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size(220, 50)),
                  onPressed: () => context.go('/join/cook'),
                  child: const Text('إدخال الرمز يدوياً', style: TextStyle(fontWeight: black)),
                ),
                TextButton(onPressed: () => context.go(landing(widget.session)), child: const Text('‹ رجوع')),
              ],
            ]),
          ),
        ]),
      );
}
