import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/medical_note.dart';

/// الدخول الرسمي: Google وApple فقط (Apple إلزامية متى وُجد Google في iOS). لا كلمات سر ولا روابط سرية.
class LoginScreen extends StatefulWidget {
  final AuthService auth;
  /// الوجهة بعد نجاح الدخول (الافتراضي: «بيوتي»).
  final String next;
  const LoginScreen({super.key, required this.auth, this.next = '/'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  SignInMethod? _busy;
  String? _error;
  bool _reviewOpen = false, _reviewBusy = false;
  final _email = TextEditingController(), _pass = TextEditingController();

  Future<void> _go(SignInMethod m) async {
    setState(() { _busy = m; _error = null; });
    try {
      await widget.auth.signIn(m);
      if (mounted) context.go(widget.next);
    } on SignInCancelled {
      // المستخدم أغلق النافذة — لا رسالة
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تسجيل الدخول. تأكد من الاتصال وحاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _reviewSignIn() async {
    setState(() { _reviewBusy = true; _error = null; });
    try {
      await widget.auth.signInWithPassword(_email.text, _pass.text);
      if (mounted) context.go(widget.next);
    } catch (_) {
      if (mounted) setState(() => _error = 'البريد أو كلمة السر غير صحيحة.');
    } finally {
      if (mounted) setState(() => _reviewBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.auth;
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        const GreenHeader(icon: '🍽️', title: 'سفرتي', subtitle: 'سجّل دخولك بحساب Google أو Apple ثم حدّد دورك'),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (!a.isAvailable(SignInMethod.google) && !a.isAvailable(SignInMethod.apple))
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Brand.amber50, borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Brand.honey)),
                    child: const Text('تسجيل الدخول متاح في تطبيق سفرتي على أندرويد وآيفون.\nيمكنك هنا تصفّح الأنظمة الغذائية.',
                        textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, height: 1.7)),
                  ),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFECACA))),
                    child: Text('⚠️ $_error', textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold)),
                  ),
                if (a.isAvailable(SignInMethod.google))
                  _Btn(label: 'المتابعة بحساب Google', icon: 'G', busy: _busy == SignInMethod.google,
                      disabled: _busy != null, onTap: () => _go(SignInMethod.google),
                      bg: Colors.white, fg: const Color(0xFF1F2937), border: const Color(0xFFD1D5DB)),
                if (a.isAvailable(SignInMethod.google) && a.isAvailable(SignInMethod.apple)) const SizedBox(height: 12),
                if (a.isAvailable(SignInMethod.apple))
                  _Btn(label: 'المتابعة بحساب Apple', icon: '', busy: _busy == SignInMethod.apple,
                      disabled: _busy != null, onTap: () => _go(SignInMethod.apple), bg: Colors.black, fg: Colors.white),
                const SizedBox(height: 20),
                const Text('بالمتابعة توافق على تخزين بياناتك الغذائية لتشغيل التطبيق. لا نشاركها مع أحد.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Brand.grey, height: 1.6)),
                TextButton(
                  onPressed: () => launchUrl(Uri.parse('https://maeda.wardyat.net/privacy'), mode: LaunchMode.externalApplication),
                  child: const Text('سياسة الخصوصية'),
                ),
                const MedicalNote(),
                if (a.supportsPassword) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _reviewOpen = !_reviewOpen),
                    child: const Text('دخول المراجعين', style: TextStyle(fontSize: 12, color: Brand.grey)),
                  ),
                  if (_reviewOpen) ...[
                    TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(labelText: 'البريد', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
                    const SizedBox(height: 8),
                    TextField(controller: _pass, obscureText: true, textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(labelText: 'كلمة السر', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                        onSubmitted: (_) => _reviewSignIn()),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _reviewBusy ? null : _reviewSignIn,
                      child: _reviewBusy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('دخول'),
                    ),
                  ],
                ],
                const Divider(height: 40),
                TextButton(onPressed: () => context.go('/browse'), child: const Text('تصفّح الأنظمة بلا تسجيل')),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label, icon;
  final bool busy, disabled;
  final VoidCallback onTap;
  final Color bg, fg;
  final Color? border;
  const _Btn({required this.label, required this.icon, required this.busy, required this.disabled,
      required this.onTap, required this.bg, required this.fg, this.border});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: disabled ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg, foregroundColor: fg, disabledBackgroundColor: bg.withValues(alpha: .6),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
                side: border == null ? BorderSide.none : BorderSide(color: border!)),
          ),
          child: busy
              ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(icon, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ]),
        ),
      );
}
