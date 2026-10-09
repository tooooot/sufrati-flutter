import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/session.dart';
import '../data/links.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// ملفي الشخصي: بياناتي من Google/Apple، وأدواري وبيوتي، وتبديل الدور، والخروج وحذف الحساب.
class ProfileScreen extends StatelessWidget {
  final Session session;
  final LinkService links;
  const ProfileScreen({super.key, required this.session, required this.links});

  @override
  Widget build(BuildContext context) {
    final u = session.user;
    final name = (u?.name ?? '').isEmpty ? 'مستخدم سفرتي' : u!.name;
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([session, links]),
        builder: (context, _) => ListView(padding: EdgeInsets.zero, children: [
          GreenHeader(
            icon: '👤', title: name, subtitle: u?.email,
            leading: IconButton(icon: const Icon(Icons.arrow_forward, color: Colors.white),
                onPressed: () => context.canPop() ? context.pop() : context.go('/')),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('أدواري وبيوتي', style: TextStyle(fontWeight: black, fontSize: 17)),
                  const SizedBox(height: 8),
                  if (links.memberships.isEmpty)
                    const CardBox(child: Text('لست مرتبطاً ببيت بعد. اختر دورك لتبدأ.', style: TextStyle(color: Brand.grey))),
                  for (final m in links.memberships) ...[
                    CardBox(child: Row(children: [
                      const Icon(Icons.home_outlined, color: Brand.green),
                      const SizedBox(width: 10),
                      Expanded(child: Text(m.householdLabel, style: const TextStyle(fontWeight: black))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(20)),
                        child: Text(roleName(m.role), style: const TextStyle(fontSize: 12, fontWeight: black, color: Brand.green)),
                      ),
                    ])),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  _Tile(icon: Icons.swap_horiz, label: 'تغيير الدور', onTap: () => context.go('/role')),
                  _Tile(icon: Icons.home, label: 'بيتي وأعضاؤه', onTap: () => context.go('/household')),
                  _Tile(icon: Icons.privacy_tip_outlined, label: 'سياسة الخصوصية',
                      onTap: () => launchUrl(Uri.parse('https://maeda.wardyat.net/privacy'), mode: LaunchMode.externalApplication)),
                  const SizedBox(height: 8),
                  _Tile(icon: Icons.logout, label: 'تسجيل الخروج', onTap: () => session.auth.signOut()),
                  _Tile(icon: Icons.delete_forever, label: 'حذف حسابي وبياناتي', danger: true, onTap: () => _confirmDelete(context)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
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
                Navigator.pop(context);
                links.leaveAll();
                await session.auth.deleteAccount();
              },
              child: const Text('حذف نهائياً', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _Tile({required this.icon, required this.label, required this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CardBox(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: danger ? Colors.red : Brand.green),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: danger ? Colors.red : null))),
            const Text('‹', style: TextStyle(fontSize: 20, color: Colors.grey)),
          ]),
        ),
      );
}
