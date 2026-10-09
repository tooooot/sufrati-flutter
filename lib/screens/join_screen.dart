import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/roles.dart';
import '../auth/session.dart';
import '../data/links.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/link_explainer.dart';

/// الطاهي أو الطبيب يكتب رمز الدعوة فيرتبط بالبيت.
class JoinScreen extends StatefulWidget {
  final LinkService links;
  final Session session;
  final Role role;
  const JoinScreen({super.key, required this.links, required this.session, required this.role});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _ctl = TextEditingController();
  String? _error;

  void _submit() {
    final err = widget.links.redeem(_ctl.text, widget.role, who: widget.session.user?.name ?? 'مستخدم');
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    context.go(widget.role == Role.cook ? '/cook' : '/me');
  }

  @override
  Widget build(BuildContext context) {
    final cook = widget.role == Role.cook;
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        GreenHeader(
          icon: cook ? '👨‍🍳' : '🩺',
          title: cook ? 'الطاهي' : 'الطبيب',
          subtitle: 'اكتب رمز الدعوة الذي وصلك من صاحب البيت',
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _ctl,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  textDirection: TextDirection.ltr,
                  maxLength: 7,
                  style: const TextStyle(fontSize: 34, fontWeight: black, letterSpacing: 8, color: Brand.green),
                  decoration: InputDecoration(
                    hintText: '••••••', counterText: '', filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    errorText: _error,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(52)),
                  onPressed: _submit,
                  child: const Text('ربط', style: TextStyle(fontSize: 18, fontWeight: black)),
                ),
                const SizedBox(height: 22),
                const LinkExplainer(),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
