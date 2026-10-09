import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/roles.dart';
import '../data/links.dart';
import '../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/link_explainer.dart';

/// «بيتي» لصاحب البيت: ملخص البيت + أعضاؤه (الطاهي والطبيب) + إصدار دعوات الربط.
class HouseholdScreen extends StatelessWidget {
  final LinkService links;
  final Library library;
  const HouseholdScreen({super.key, required this.links, required this.library});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: links,
        builder: (context, _) => Scaffold(
          body: ListView(padding: EdgeInsets.zero, children: [
            GreenHeader(
              icon: '🏠',
              title: links.hasHousehold ? links.label : 'بيتي',
              subtitle: links.hasHousehold ? (library.meta(links.programId)?.label ?? '') : 'لم تنشئ بيتاً بعد',
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (!links.hasHousehold) ...[
                      CardBox(
                        onTap: () => context.go('/browse'),
                        color: Brand.amber50,
                        border: Border.all(color: Brand.honey, width: 2),
                        child: const Row(children: [
                          Text('🥗', style: TextStyle(fontSize: 38)),
                          SizedBox(width: 12),
                          Expanded(child: Text('ابدأ بإنشاء بيتك: اختر النظام الغذائي المناسب',
                              style: TextStyle(fontWeight: black, fontSize: 16, color: Brand.green))),
                          Text('‹', style: TextStyle(fontSize: 22, color: Colors.grey)),
                        ]),
                      ),
                    ] else ...[
                      CardBox(
                        onTap: () => context.go('/me'),
                        child: const Row(children: [
                          Text('🍽️', style: TextStyle(fontSize: 34)),
                          SizedBox(width: 12),
                          Expanded(child: Text('وجبات اليوم والمشتريات',
                              style: TextStyle(fontWeight: black, fontSize: 16, color: Brand.green))),
                          Text('‹', style: TextStyle(fontSize: 22, color: Colors.grey)),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      const Text('أعضاء البيت', style: TextStyle(fontWeight: black, fontSize: 17)),
                      const SizedBox(height: 8),
                      _Member(icon: '👤', title: 'أنت', sub: 'صاحب البيت', done: true),
                      const SizedBox(height: 8),
                      _Slot(links: links, role: Role.cook, icon: '👨‍🍳', title: 'الطاهي',
                          empty: 'لم يُربط طاهٍ بعد — يرى وجبات اليوم ومكوّناتها فقط'),
                      const SizedBox(height: 8),
                      _Slot(links: links, role: Role.doctor, icon: '🩺', title: 'الطبيب',
                          empty: 'لم يُربط طبيب بعد — يتابع الخطة ويعدّلها'),
                    ],
                    const SizedBox(height: 18),
                    const LinkExplainer(),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _Member extends StatelessWidget {
  final String icon, title, sub;
  final bool done;
  const _Member({required this.icon, required this.title, required this.sub, required this.done});
  @override
  Widget build(BuildContext context) => CardBox(
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: black, fontSize: 16)),
            Text(sub, style: const TextStyle(fontSize: 12, color: Brand.grey)),
          ])),
          if (done) const Icon(Icons.check_circle, color: Brand.green),
        ]),
      );
}

class _Slot extends StatelessWidget {
  final LinkService links;
  final Role role;
  final String icon, title, empty;
  const _Slot({required this.links, required this.role, required this.icon, required this.title, required this.empty});

  @override
  Widget build(BuildContext context) {
    final joined = links.joinedBy(role);
    final pending = links.inviteFor(role);
    if (joined != null) {
      return _Member(icon: icon, title: title, sub: 'انضم ✓ (${joined.usedBy})', done: true);
    }
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: black, fontSize: 16)),
            Text(pending == null ? empty : 'بانتظار أن يدخل الرمز', style: const TextStyle(fontSize: 12, color: Brand.grey)),
          ])),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Brand.green),
            onPressed: () => _showInvite(context, pending ?? links.createInvite(role)),
            child: Text(pending == null ? 'دعوة' : 'عرض الرمز'),
          ),
        ]),
      ]),
    );
  }

  void _showInvite(BuildContext context, Invite inv) {
    final who = role == Role.cook ? 'الطاهي' : 'الطبيب';
    final msg = 'دعوة للانضمام إلى بيتي في تطبيق سفرتي بدور $who.\nرمز الدعوة: ${inv.code}\n'
        'سجّل دخولك في التطبيق، اختر «$who»، واكتب الرمز.';
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('رمز دعوة $who', textAlign: TextAlign.center, style: const TextStyle(fontWeight: black, fontSize: 18, color: Brand.green)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(16)),
            child: Text(inv.code, textAlign: TextAlign.center, textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 38, fontWeight: black, letterSpacing: 8, color: Brand.green)),
          ),
          const SizedBox(height: 6),
          const Text('يعمل مرة واحدة · ينتهي بعد 7 أيام', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Brand.grey)),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.send),
            label: const Text('إرسال بواتساب', style: TextStyle(fontWeight: black)),
            onPressed: () => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'),
                mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('نسخ الرمز'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inv.code));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرمز')));
            },
          ),
        ]),
      ),
    );
  }
}
