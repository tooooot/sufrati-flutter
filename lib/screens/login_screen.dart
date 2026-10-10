import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../data/links.dart';
import '../theme.dart';
import '../widgets/medical_note.dart';

/// الدخول كنافذة فورية: شعار على الأخضر ونافذة كريمية سفلية (Google/Apple، ورمز دعوة اختياري، وتصفّح بلا تسجيل).
class LoginScreen extends StatefulWidget {
  final AuthService auth;
  /// الوجهة بعد نجاح الدخول (الافتراضي: الشاشة الرئيسية حسب الدور).
  final String next;
  const LoginScreen({super.key, required this.auth, this.next = '/'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  SignInMethod? _busy;
  String? _error;
  bool _codeOpen = false, _reviewOpen = false, _reviewBusy = false;
  final _code = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  /// من كتب رمز دعوة يذهب بعد الدخول إلى /i/<رمز>: ينضم مباشرة بلا اختيار دور.
  String get _target {
    final c = normalizeCode(_code.text);
    return _codeOpen && c.length >= 6 ? '/i/$c' : widget.next;
  }

  Future<void> _go(SignInMethod m) async {
    setState(() { _busy = m; _error = null; });
    try {
      await widget.auth.signIn(m);
      if (mounted) context.go(_target);
    } on SignInCancelled {
      // المستخدم أغلق النافذة — لا رسالة
    } on AuthFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (_) {
      if (mounted) setState(() => _error = const AuthFailure(AuthFailureKind.other).message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _reviewSignIn() async {
    setState(() { _reviewBusy = true; _error = null; });
    try {
      await widget.auth.signInWithPassword(_email.text, _pass.text);
      if (mounted) context.go(_target);
    } on AuthFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (_) {
      if (mounted) setState(() => _error = const AuthFailure(AuthFailureKind.other).message);
    } finally {
      if (mounted) setState(() => _reviewBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.auth;
    final hasSocial = a.isAvailable(SignInMethod.google) || a.isAvailable(SignInMethod.apple);
    return Scaffold(
      backgroundColor: Brand.green,
      body: Column(children: [
        // الشعار
        SizedBox(
          height: MediaQuery.sizeOf(context).height * .26,
          child: SafeArea(
            bottom: false,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 78, height: 78,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Brand.cream),
                  child: const Center(child: Icon(Icons.restaurant, size: 42, color: Brand.green)),
                ),
                const SizedBox(height: 8),
                const Text('سفرتي', style: TextStyle(color: Brand.cream, fontSize: 36, fontWeight: black)),
                Text('وجبات بيتك مرتّبة', style: TextStyle(color: Brand.cream.withValues(alpha: .85), fontSize: 15)),
              ]),
            ),
          ),
        ),
        // النافذة السفلية
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ListView(padding: const EdgeInsets.fromLTRB(22, 22, 22, 28), children: [
                  const Text('ادخل في ثوانٍ', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: black, color: Brand.green)),
                  const SizedBox(height: 6),
                  const Text('بنقرة واحدة، بلا كلمة سر ولا نموذج.', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Brand.grey)),
                  const SizedBox(height: 18),
                  if (!hasSocial)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Brand.amber50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Brand.honey)),
                      child: const Text('تسجيل الدخول متاح في تطبيق سفرتي على أندرويد وآيفون.\nيمكنك هنا تصفّح الأنظمة الغذائية.',
                          textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, height: 1.7)),
                    ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFECACA))),
                      child: Text('⚠️ $_error', textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold)),
                    ),
                  if (a.isAvailable(SignInMethod.google))
                    _Btn(label: 'المتابعة بحساب Google', icon: '',
                        iconWidget: SvgPicture.asset('assets/images/google_g.svg', width: 22, height: 22),
                        busy: _busy == SignInMethod.google, disabled: _busy != null,
                        onTap: () => _go(SignInMethod.google),
                        bg: Colors.white, fg: const Color(0xFF1F2937), border: const Color(0xFFD1D5DB)),
                  if (a.isAvailable(SignInMethod.google) && a.isAvailable(SignInMethod.apple)) const SizedBox(height: 12),
                  if (a.isAvailable(SignInMethod.apple))
                    _Btn(label: 'المتابعة بحساب Apple', icon: '',
                        iconWidget: const Icon(Icons.apple, color: Colors.white, size: 24),
                        busy: _busy == SignInMethod.apple, disabled: _busy != null,
                        onTap: () => _go(SignInMethod.apple), bg: Colors.black, fg: Colors.white),
                  if (hasSocial) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50), side: const BorderSide(color: Brand.honey, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.vpn_key_outlined, color: Brand.honey),
                      label: const Text('عندي رمز دعوة', style: TextStyle(color: Brand.honey, fontWeight: black, fontSize: 16)),
                      onPressed: () => setState(() => _codeOpen = !_codeOpen),
                    ),
                    if (_codeOpen)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Brand.green, width: 2)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('اكتب الرمز (8 خانات)', style: TextStyle(fontSize: 14, fontWeight: black, color: Brand.green)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _code, textAlign: TextAlign.center, textDirection: TextDirection.ltr,
                            textCapitalization: TextCapitalization.characters, maxLength: 10,
                            style: const TextStyle(fontSize: 24, fontWeight: black, letterSpacing: 5, color: Brand.green),
                            decoration: InputDecoration(counterText: '', filled: true, fillColor: Brand.cream, hintText: '••••••••',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                          const SizedBox(height: 6),
                          const Text('اضغط Google أو Apple أعلاه وستنضم للبيت مباشرة بعد الدخول.',
                              style: TextStyle(fontSize: 12.5, color: Brand.grey, height: 1.6)),
                        ]),
                      ),
                  ],
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => context.push('/browse'),
                    child: const Text('تصفّح الأنظمة بلا تسجيل',
                        style: TextStyle(fontSize: 15, fontWeight: black, color: Brand.green, decoration: TextDecoration.underline)),
                  ),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'بمتابعتك توافق على '),
                      TextSpan(
                        text: 'سياسة الخصوصية',
                        style: const TextStyle(color: Brand.green, fontWeight: FontWeight.w800, decoration: TextDecoration.underline),
                      ),
                      const TextSpan(text: ' وتخزين بياناتك الغذائية لتشغيل التطبيق.'),
                    ]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: Brand.grey, height: 1.7),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse('https://maeda.wardyat.net/privacy'), mode: LaunchMode.externalApplication),
                    child: const Text('قراءة سياسة الخصوصية'),
                  ),
                  const MedicalNote(),
                  if (a.supportsPassword) ...[
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
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label, icon;
  final Widget? iconWidget;
  final bool busy, disabled;
  final VoidCallback onTap;
  final Color bg, fg;
  final Color? border;
  const _Btn({required this.label, required this.icon, this.iconWidget, required this.busy, required this.disabled,
      required this.onTap, required this.bg, required this.fg, this.border});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: disabled ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg, foregroundColor: fg, disabledBackgroundColor: bg.withValues(alpha: .6),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
                side: border == null ? BorderSide.none : BorderSide(color: border!, width: 2)),
          ),
          child: busy
              ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  iconWidget ?? Text(icon, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 12),
                  Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ]),
        ),
      );
}
