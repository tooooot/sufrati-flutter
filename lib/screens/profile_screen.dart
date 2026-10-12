import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/roles.dart';
import '../auth/session.dart';
import '../data/links.dart';
import '../data/prefs.dart';
import '../data/repository.dart';
import '../routing.dart';
import '../widgets/nav.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// ملفي الشخصي: هويتي، وتبديل الدور بنقرة (مفتاح مقسوم)، وبيوتي، والخصوصية والبيانات، والخروج.
class ProfileScreen extends StatelessWidget {
  final Session session;
  final LinkService links;
  final Library library;
  final PrefsService prefs;
  const ProfileScreen({super.key, required this.session, required this.links, required this.library, required this.prefs});

  Future<void> _switchTo(BuildContext context, Role r) async {
    if (r == Role.doctor && !links.isDoctor) {
      // الطبيب بموافقة المدير لا بالاختيار: بياناته المهنية تُراجَع مرة واحدة
      if (context.mounted) context.push(links.doctorRequested ? '/doctor-pending' : '/doctor/apply');
      return;
    }
    session.chooseRole(r);
    if (context.mounted) context.go(landing(session));
  }

  @override
  Widget build(BuildContext context) {
    final u = session.user;
    final name = (u?.name ?? '').isEmpty ? 'مستخدم سفرتي' : u!.name;
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([session, links]),
        builder: (context, _) => ListView(padding: EdgeInsets.zero, children: [
          CompactHeader(
            title: name, subtitle: u?.email,
            leading: IconButton(icon: const Icon(Icons.arrow_forward, color: Colors.white), onPressed: () => context.back(landing(session))),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // نظامي الحالي وتغييره
                  if (links.hasHousehold) ...[
                    const _GroupTitle('نظامي'),
                    CardBox(
                      child: Row(children: [
                        const Icon(Icons.restaurant_menu, color: Brand.green, size: 30),
                        const SizedBox(width: 12),
                        Expanded(child: Text(library.meta(links.programId)?.label ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                        OutlinedButton(onPressed: () => context.push('/journey?update=1'), child: const Text('غيّر نظامي')),
                      ]),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // المظهر: حجم الخط (يتبع الحساب على كل الأجهزة)
                  const _GroupTitle('حجم الخط'),
                  ListenableBuilder(
                    listenable: prefs,
                    builder: (_, _) => CardBox(
                      child: Row(children: [
                        for (final (l, v) in PrefsService.scales)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: GestureDetector(
                                onTap: () => prefs.setFontScale(v),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: (prefs.fontScale - v).abs() < .01 ? Brand.green : Brand.green.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(l, textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.w800, color: (prefs.fontScale - v).abs() < .01 ? Colors.white : Brand.green)),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // تبديل الدور: يظهر فقط لمن له أكثر من دور فعلي (مدير سفرتي، طبيب، أو عضو في بيت غيره). الدور يُشتق من الارتباطات لا يُختار
                  if (session.isAdmin || links.isDoctor || links.memberships.any((m) => m.role != Role.owner)) ...[
                  CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('أنت الآن تستخدم سفرتي كـ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Brand.grey)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Brand.green.withValues(alpha: .09), borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        for (final r in const [Role.owner, Role.cook, Role.doctor])
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _switchTo(context, r),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: session.role == r ? Brand.green : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(const {Role.owner: 'أدير بيتي', Role.cook: 'أنا طاهٍ', Role.doctor: 'أنا طبيب'}[r]!, textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 15, fontWeight: black,
                                        color: session.role == r ? Colors.white : Brand.green)),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Text(switch (session.role) {
                      Role.owner => 'ترى وتعدّل كل شيء في بيتك، وتدعو الطاهية والطبيب، وتطبخ بنفسك متى شئت.',
                      Role.cook => 'ترى وجبات اليوم ومكوّناتها فقط وتضغط «حُضّرت».',
                      Role.doctor => 'ترى خطط من ربطوك بهم فقط. يعتمد مدير سفرتي حسابك.',
                      _ => 'اختر دورك للبدء.',
                    }, style: const TextStyle(fontSize: 13, color: Brand.grey, height: 1.7)),
                  ])),
                  ],
                  const SizedBox(height: 20),
                  const _GroupTitle('بيوتي'),
                  if (links.memberships.isEmpty)
                    const CardBox(child: Text('لست مرتبطاً ببيت بعد. اختر دورك لتبدأ.', style: TextStyle(color: Brand.grey)))
                  else
                    CardBox(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (final (i, m) in links.memberships.indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              const Icon(Icons.home_outlined, color: Brand.green),
                              const SizedBox(width: 10),
                              Expanded(child: Text(m.householdLabel, style: const TextStyle(fontWeight: black))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(20)),
                                child: Text(roleName(m.role), style: const TextStyle(fontSize: 13, fontWeight: black, color: Brand.green)),
                              ),
                            ]),
                          ),
                        ],
                      ]),
                    ),
                  const SizedBox(height: 20),
                  if (links.isDoctor) ...[
                    const _GroupTitle('مهنتي'),
                    CardBox(padding: EdgeInsets.zero, child: _Row(Icons.badge_outlined, 'ملفي المهني ورابط متابعيّ', () => context.push('/doctor/profile'))),
                    const SizedBox(height: 20),
                  ],
                  const _GroupTitle('الخصوصية والبيانات'),
                  CardBox(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      _Row(Icons.privacy_tip_outlined, 'سياسة الخصوصية',
                          () => launchUrl(Uri.parse('https://maeda.wardyat.net/privacy'), mode: LaunchMode.externalApplication)),
                      const Divider(height: 1),
                      _Row(Icons.delete_forever, 'حذف حسابي وبياناتي', () => _confirmDelete(context), danger: true),
                    ]),
                  ),
                  if (session.isAdmin) ...[
                    const SizedBox(height: 20),
                    const _GroupTitle('الإدارة'),
                    CardBox(padding: EdgeInsets.zero, child: _Row(Icons.admin_panel_settings, 'لوحة المدير', () => context.push('/admin'))),
                  ],
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), side: const BorderSide(color: Brand.green, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const Icon(Icons.logout, color: Brand.green),
                    label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: black, fontSize: 16, color: Brand.green)),
                    onPressed: () => _signOut(context),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await session.auth.signOut();
      router.go('/login');
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر تسجيل الخروج. حاول مرة أخرى.')));
    }
  }

  void _confirmDelete(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('حذف الحساب؟'),
          content: const Text('سيُحذف حسابك وكل بياناتك نهائياً ولا يمكن التراجع.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  await links.deleteMyData(); // البيوت والخطط والدعوات أولاً، ثم الحساب
                  await session.auth.deleteAccount();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('تعذّر الحذف الكامل: $e\nسجّل الدخول من جديد ثم أعد المحاولة.')));
                }
              },
              child: const Text('حذف نهائياً', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
}

class _GroupTitle extends StatelessWidget {
  final String text;
  const _GroupTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: black, color: Brand.honey)),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _Row(this.icon, this.label, this.onTap, {this.danger = false});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, color: danger ? Colors.red : Brand.green),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: danger ? Colors.red : null))),
            const Icon(Icons.chevron_left, color: Colors.grey),
          ]),
        ),
      );
}
