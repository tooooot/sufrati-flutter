import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/roles.dart';
import '../data/links.dart';
import '../data/role_videos.dart';
import '../data/repository.dart';
import '../platform_flags.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/link_explainer.dart';
import '../widgets/profile_button.dart';
import 'pitch_content.dart' show pitchLangs;

/// «بيتي» كشاشة مستقلة (مسار /household) — محتواها نفسه تبويب «بيتي» في لوحة مدير البيت.
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
              leading: const ProfileButton(),
              icon: '🏠',
              title: links.hasHousehold ? links.label : 'بيتي',
              subtitle: links.hasHousehold ? (library.meta(links.programId)?.label ?? '') : 'لم تنشئ بيتاً بعد',
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: HouseholdBody(links: links),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// محتوى «بيتي»: أعضاء البيت (الطاهي والطبيب) وإصدار دعوات الربط، أو الدعوة لإنشاء بيت.
class HouseholdBody extends StatelessWidget {
  final LinkService links;
  /// شخصي: بلا بطاقة «أنت» ولا شريك افتراضي (الأخصائي والشريك والطاهي اختيارية).
  final bool personal;
  const HouseholdBody({super.key, required this.links, this.personal = false});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: links,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!links.hasHousehold)
            CardBox(
              onTap: () => context.push('/new-house'),
              color: Brand.amber50,
              border: Border.all(color: Brand.honey, width: 2),
              child: const Row(children: [
                Text('🥗', style: TextStyle(fontSize: 38)),
                SizedBox(width: 12),
                Expanded(child: Text('ابدأ بإنشاء بيتك: اختر النظام الغذائي المناسب',
                    style: TextStyle(fontWeight: black, fontSize: 16, color: Brand.green))),
                Text('‹', style: TextStyle(fontSize: 22, color: Colors.grey)),
              ]),
            )
          else ...[
            if (!personal) ...[
              const Text('أعضاء البيت', style: TextStyle(fontWeight: black, fontSize: 17)),
              const SizedBox(height: 8),
              const _Member(icon: '👤', title: 'أنت', sub: 'مدير البيت', done: true),
              const SizedBox(height: 8),
            ],
            if (doctorFeaturesEnabled) ...[
            _Slot(links: links, role: Role.doctor, icon: '🩺', title: personal ? 'أخصائي التغذية أو الطبيب' : 'الطبيب',
                empty: personal ? 'يتابع خطتك ويعدّل سعراتك' : 'يتابع الخطة ويعدّلها'),
            const SizedBox(height: 8),
            ],
            _Slot(links: links, role: Role.owner, icon: '👫', title: personal ? 'شريك' : 'شريكي في إدارة البيت',
                empty: personal ? 'شخص يرى خطتك ويعدّلها معك' : 'الزوج أو الزوجة: يرى الخطة نفسها ويعدّلها معك (بيت واحد، لا بيتان)'),
            const SizedBox(height: 8),
            _Slot(links: links, role: Role.cook, icon: '👨‍🍳', title: 'الطاهي',
                empty: 'يرى وجبات اليوم ومكوّناتها فقط'),
          ],
          const SizedBox(height: 14),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: BoxDecoration(color: Brand.amber50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Brand.honey.withValues(alpha: .4))),
              child: const ExpansionTile(
                title: Text('كيف يتم الربط؟', style: TextStyle(fontWeight: FontWeight.w700, color: Brand.green)),
                childrenPadding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [LinkExplainer()],
              ),
            ),
          ),
        ]),
      );
}

class _Member extends StatelessWidget {
  final String icon, title, sub;
  final bool done;
  final Widget? trailing;
  const _Member({required this.icon, required this.title, required this.sub, required this.done, this.trailing});
  @override
  Widget build(BuildContext context) => CardBox(
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(sub, style: const TextStyle(fontSize: 13, color: Brand.grey)),
          ])),
          ?trailing,
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
      return _Member(icon: icon, title: title, sub: 'انضم ✓ (${joined.usedBy})', done: true,
          trailing: TextButton(onPressed: () => _confirmRemove(context, links, role, title), child: const Text('إزالة', style: TextStyle(color: Colors.red))));
    }
    return CardBox(
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(pending == null ? empty : 'بانتظار أن يدخل الرمز', style: const TextStyle(fontSize: 13, color: Brand.grey)),
        ])),
        if (pending != null)
          IconButton(
            tooltip: 'إلغاء الدعوة',
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => links.removeRole(role),
          ),
        OutlinedButton(
          onPressed: () => inviteFlow(context, links, role),
          child: Text(pending == null ? 'دعوة' : 'عرض الرمز'),
        ),
      ]),
    );
  }
}

/// يصدر دعوة (أو يعرض المعلّقة) ويفتح نافذة الرمز مع مشاركة واتساب — تُستدعى من «بيتي» ومن الرئيسية.
Future<void> inviteFlow(BuildContext context, LinkService links, Role role) async {
  final Invite inv;
  try {
    inv = links.inviteFor(role) ?? await links.createInvite(role);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 8), content: Text('تعذّر إصدار الدعوة: ${_errText(e)}')));
    }
    return;
  }
  if (!context.mounted) return;
  final who = switch (role) { Role.cook => 'الطاهي', Role.owner => 'شريك إدارة البيت', _ => 'الطبيب' };
  final link = 'https://maeda.wardyat.net/i/${inv.code}';
  final arMsg = 'دعوة للانضمام إلى بيتي في تطبيق سفرتي بدور $who.\nافتح الرابط وسجّل دخولك فتنضم مباشرة:\n$link\n'
      'أو اكتب الرمز يدوياً: ${inv.code}'
      '${role == Role.cook ? '\n\nشاهد شرحاً قصيراً (نصف دقيقة):\nhttps://maeda.wardyat.net/pitch/cook?lang=ar' : ''}';
  var lang = 'ar';
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
      final msg = role == Role.cook && lang != 'ar' ? _cookInviteMessage(lang, link, inv.code) : arMsg;
      return SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('رمز دعوة $who', textAlign: TextAlign.center, style: const TextStyle(fontWeight: black, fontSize: 18, color: Brand.green)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(16)),
          child: Text(inv.code, textAlign: TextAlign.center, textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 30, fontWeight: black, letterSpacing: 6, color: Brand.green)),
        ),
        const SizedBox(height: 6),
        const Text('يعمل مرة واحدة · ينتهي بعد 7 أيام', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Brand.grey)),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), minimumSize: const Size.fromHeight(50)),
          icon: const Icon(Icons.send),
          label: Text(role == Role.cook ? 'إرسال بواتساب (${pitchLangs[lang]})' : 'إرسال بواتساب', style: const TextStyle(fontWeight: black)),
          // الفيديو الخاص بدور المستلم يُرفق مع الدعوة: الطاهي ← فيديو الطاهي، والطبيب ← فيديو الأخصائي
          // الطاهية: الشرح المتحرك بلغتها برابط داخل الرسالة نفسها؛ فيديو الدور الجاهز (إن وُجد) لغيرها
          onPressed: () => role == Role.cook
              ? launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication)
              : RoleVideos.share(msg, role == Role.owner ? 'owner' : 'specialist'),
        ),
        if (role == Role.cook) ...[
          const SizedBox(height: 16),
          const Text('لغة الطاهية: تصلها الرسالة وشرح فيديو قصير بلغتها', textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Brand.green)),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
            for (final e in pitchLangs.entries)
              ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontWeight: black)),
                selected: lang == e.key,
                onSelected: (_) => setSt(() => lang = e.key),
              ),
          ]),
        ],
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
    ));
    }),
  );
}

String _errText(Object e) => e is FirebaseException ? '${e.code} — ${e.message ?? ''}' : e.toString();

Future<void> _confirmRemove(BuildContext context, LinkService links, Role role, String title) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('إزالة $title؟'),
      content: const Text('سيخرج من بيتك ولن يرى خطتك بعد الآن. يمكنك دعوة غيره لاحقاً.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('إزالة', style: TextStyle(color: Colors.red))),
      ],
    ),
  );
  if (ok == true) await links.removeRole(role);
}

/// رسالة دعوة الطاهية بلغتها: شرح الفيديو القصير (العرض الحركي بلغتها) ثم رابط الانضمام والرمز.
String _cookInviteMessage(String lang, String link, String code) {
  final pitch = 'https://maeda.wardyat.net/pitch/cook?lang=$lang';
  final (head, watch, open, orCode) = switch (lang) {
    'am' => ('በሱፍራቲ መተግበሪያ ውስጥ የቤቴ ምግብ አብሳይ እንድትሆኑ ተጋብዘዋል።', 'አጭሩን ቪዲዮ ይመልከቱ (30 ሰከንድ)', 'ሊንኩን ከፍተው ይግቡ', 'ወይም ኮዱን ያስገቡ'),
    'tl' => ('Inaanyayahan kitang maging tagaluto sa aming bahay sa app na Sufrati.', 'Panoorin ang maikling video (30 segundo)', 'Buksan ang link at mag-sign in', 'O i-type ang code'),
    'so' => ('Waxaa laguu casuumay inaad noqoto kookaha gurigayga ee app-ka Sufrati.', 'Daawo muuqaalka gaaban (30 ilbiriqsi)', 'Fur linkiga oo gal', 'Ama geli koodka'),
    'bn' => ('সুফরাতি অ্যাপে আমার বাড়ির রাঁধুনি হওয়ার জন্য আপনাকে আমন্ত্রণ জানানো হচ্ছে।', 'ছোট ভিডিওটি দেখুন (৩০ সেকেন্ড)', 'লিংকটি খুলে সাইন ইন করুন', 'অথবা কোডটি লিখুন'),
    'hi' => ('सुफ़राती ऐप पर मेरे घर की रसोइया बनने के लिए आपको आमंत्रित किया गया है।', 'छोटा वीडियो देखें (30 सेकंड)', 'लिंक खोलकर साइन इन करें', 'या कोड डालें'),
    _ => ('You are invited to be the cook in my household on the Sufrati app.', 'Watch this short video (30 seconds)', 'Open the link and sign in', 'Or type the code'),
  };
  return '$head\n\n1) $watch:\n$pitch\n\n2) $open:\n$link\n\n$orCode: $code';
}
