import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/session.dart';
import '../data/growth.dart';
import '../data/marketing.dart';
import '../routing.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// قسم التسويق في لوحة المدير: مهام اليوم (مستهدفون جدد)، المتابعة، وإضافة مستهدف، ومعاينة العروض.
/// لا إرسال تلقائي: «إرسال واتساب» يفتح الرسالة جاهزة والمدير يضغط إرسال بنفسه، وبحد يومي.
class MarketingScreen extends StatefulWidget {
  final FirebaseFirestore? db;
  final GrowthService growth;
  const MarketingScreen({super.key, required this.db, required this.growth});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _T {
  final String id, name, specialty, city, channel, sourceUrl, phone, manual;
  final TargetKind kind;
  final DateTime? sentAt;
  final int sentCount;
  final bool opened, registered;
  _T(this.id, Map<String, dynamic> d, Map<String, dynamic>? pitch)
      : name = d['name'] as String? ?? '',
        specialty = d['specialty'] as String? ?? '',
        city = d['city'] as String? ?? '',
        channel = d['channel'] as String? ?? '',
        sourceUrl = d['sourceUrl'] as String? ?? '',
        phone = d['phone'] as String? ?? '',
        manual = d['status'] as String? ?? '',
        kind = TargetKindX.parse(d['kind'] as String?),
        sentAt = (d['sentAt'] as Timestamp?)?.toDate(),
        sentCount = (d['sentCount'] as num?)?.toInt() ?? 0,
        opened = pitch?['openedAt'] != null,
        registered = pitch?['registeredAt'] != null;
  TargetStatus get status => deriveStatus(manual: manual, sent: sentAt != null, opened: opened, registered: registered);
  String get link => pitchLinkFor(id);
}

class _MarketingScreenState extends State<MarketingScreen> {
  int _tab = 0; // 0 مهام اليوم · 1 المتابعة · 2 الكل

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        GreenHeader(
          icon: '📣', title: 'التسويق', subtitle: 'أطباء وأخصائيون وأصحاب جروبات',
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.canPop() ? context.pop() : context.go('/admin')),
        ),
        if (db == null)
          const Padding(padding: EdgeInsets.all(24), child: Text('متاح في تطبيق الجوال.'))
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: db.collection('marketingTargets').snapshots(),
                  builder: (context, tSnap) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db.collection('pitchLinks').snapshots(),
                    builder: (context, pSnap) {
                      if (tSnap.hasError) return Text('تعذّر التحميل: ${tSnap.error}');
                      if (!tSnap.hasData || !pSnap.hasData) return const Center(child: CircularProgressIndicator());
                      final pitches = {for (final d in pSnap.data!.docs) d.id: d.data()};
                      final all = [for (final d in tSnap.data!.docs) _T(d.id, d.data(), pitches[d.id])]
                        ..sort((a, b) => a.name.compareTo(b.name));
                      return _body(db, all);
                    },
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _body(FirebaseFirestore db, List<_T> all) {
    int n(TargetStatus s) => all.where((t) => t.status == s).length;
    final today = sentToday(all.map((t) => t.sentAt).whereType<DateTime>(), DateTime.now());
    final shown = switch (_tab) {
      0 => all.where((t) => t.status == TargetStatus.fresh).toList(),
      1 => all.where((t) => const [TargetStatus.sent, TargetStatus.opened, TargetStatus.registered].contains(t.status)).toList(),
      _ => all,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardBox(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _Stat('جديد', n(TargetStatus.fresh)), _Stat('أُرسل', n(TargetStatus.sent)),
            _Stat('فتح', n(TargetStatus.opened)), _Stat('سجّل', n(TargetStatus.registered)),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: (today / dailySendLimit).clamp(0, 1), minHeight: 8, color: today >= dailySendLimit ? Colors.red : Brand.green,
              backgroundColor: Brand.green.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 6),
          Text('أُرسل اليوم $today من $dailySendLimit', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Brand.grey)),
        ]),
      ),
      const SizedBox(height: 12),
      const Text('معاينة العروض (كما يراها المستلم)', style: TextStyle(fontWeight: black, fontSize: 15)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        for (final e in const {'doctor': 'طبيب/أخصائي/صاحب جروب', 'cook': 'الطاهي', 'user': 'صاحب الخطة'}.entries)
          ActionChip(label: Text(e.value), onPressed: () => context.push('/pitch/${e.key}')),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        for (final (i, l) in const ['مهام اليوم', 'المتابعة', 'الكل'].indexed)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(label: Text(l), selected: _tab == i, onSelected: (_) => setState(() => _tab = i)),
          ),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Brand.green),
          icon: const Icon(Icons.add), label: const Text('مستهدف'),
          onPressed: () => _add(db),
        ),
      ]),
      const SizedBox(height: 10),
      if (shown.isEmpty)
        const CardBox(child: Text('لا شيء هنا الآن.', style: TextStyle(color: Brand.grey)))
      else
        for (final t in shown) _card(db, t, today),
    ]);
  }

  Widget _card(FirebaseFirestore db, _T t, int today) {
    final st = t.status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(t.name, style: const TextStyle(fontWeight: black, fontSize: 16))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: (st == TargetStatus.registered ? Brand.green : st == TargetStatus.declined ? Colors.red : Brand.honey).withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(st.label, style: const TextStyle(fontWeight: black, fontSize: 12)),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _menu(db, t, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'declined', child: Text('رفض (قال لا)')),
                PopupMenuItem(value: 'skipped', child: Text('تأجيل')),
                PopupMenuItem(value: 'reset', child: Text('إعادته للجديد')),
                PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: Colors.red))),
              ],
            ),
          ]),
          Text([t.kind.label, t.specialty, t.city].where((x) => x.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 13, color: Brand.grey)),
          if (t.channel.isNotEmpty || t.sourceUrl.isNotEmpty)
            InkWell(
              onTap: t.sourceUrl.isEmpty ? null : () => launchUrl(Uri.parse(t.sourceUrl), mode: LaunchMode.externalApplication),
              child: Text('المصدر: ${t.channel}${t.sourceUrl.isEmpty ? '' : ' ↗'}',
                  style: TextStyle(fontSize: 12, color: t.sourceUrl.isEmpty ? Brand.grey : Brand.green, decoration: t.sourceUrl.isEmpty ? null : TextDecoration.underline)),
            ),
          if (t.sentAt != null)
            Text('أُرسل ${t.sentAt!.day}/${t.sentAt!.month}${t.sentCount > 1 ? ' (×${t.sentCount})' : ''}', style: const TextStyle(fontSize: 12, color: Brand.grey)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                icon: const Icon(Icons.send, size: 18),
                label: Text(st == TargetStatus.fresh ? 'إرسال واتساب' : 'إعادة إرسال'),
                onPressed: () => _send(db, t, today),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final m = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: t.link));
                m.showSnackBar(const SnackBar(content: Text('نُسخ رابطه')));
              },
              child: const Icon(Icons.link),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () => context.push('/p/${t.id}'), child: const Icon(Icons.visibility)),
          ]),
        ]),
      ),
    );
  }

  Future<void> _menu(FirebaseFirestore db, _T t, String v) async {
    final ref = db.doc('marketingTargets/${t.id}');
    switch (v) {
      case 'delete':
        final b = db.batch()..delete(ref)..delete(db.doc('pitchLinks/${t.id}'));
        await b.commit();
      case 'reset':
        await ref.update({'status': '', 'sentAt': null, 'sentCount': 0});
      default:
        await ref.update({'status': v});
    }
  }

  Future<void> _send(FirebaseFirestore db, _T t, int today) async {
    final msg = TextEditingController(text: buildMessage(t.kind, t.name, t.link));
    final phone = normalizePhone(t.phone);
    final blocked = today >= dailySendLimit;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('رسالة إلى ${t.name}'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (blocked)
              const Padding(padding: EdgeInsets.only(bottom: 8),
                  child: Text('بلغتَ الحد اليومي. أوقِف الإرسال حفاظًا على رقمك.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800))),
            TextField(controller: msg, minLines: 6, maxLines: 10, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Text(phone == null ? 'لا رقم صالح: انسخ الرسالة وأرسلها من المصدر.' : 'يُفتح واتساب والرسالة جاهزة؛ اضغط إرسال بنفسك.',
                style: const TextStyle(fontSize: 12, color: Brand.grey)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: blocked ? null : () => Navigator.pop(c, true),
            child: Text(phone == null ? 'نسخ الرسالة' : 'فتح واتساب'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    if (phone == null) {
      await Clipboard.setData(ClipboardData(text: msg.text));
    } else {
      await launchUrl(Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg.text)}'), mode: LaunchMode.externalApplication);
    }
    await db.doc('marketingTargets/${t.id}').update({'sentAt': FieldValue.serverTimestamp(), 'sentCount': FieldValue.increment(1), 'status': ''});
  }

  Future<void> _add(FirebaseFirestore db) async {
    final name = TextEditingController(), spec = TextEditingController(), city = TextEditingController(),
        channel = TextEditingController(), url = TextEditingController(), phone = TextEditingController();
    var kind = TargetKind.doctor;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('مستهدف جديد'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم كما يُخاطَب (د. خالد)')),
                DropdownButton<TargetKind>(
                  value: kind, isExpanded: true,
                  items: [for (final k in TargetKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
                  onChanged: (v) => set(() => kind = v ?? kind),
                ),
                TextField(controller: spec, decoration: const InputDecoration(labelText: 'التخصص')),
                TextField(controller: city, decoration: const InputDecoration(labelText: 'المدينة')),
                TextField(controller: channel, decoration: const InputDecoration(labelText: 'أين وُجد (إنستغرام، موقع العيادة، جروب…)')),
                TextField(controller: url, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رابط المصدر')),
                TextField(controller: phone, textDirection: TextDirection.ltr, keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'واتساب مهني منشور للعموم (اختياري)')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, name.text.trim().isNotEmpty), child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final token = newDoctorCode(Random.secure());
    final b = db.batch();
    b.set(db.doc('marketingTargets/$token'), {
      'name': name.text.trim(), 'kind': kind.id, 'specialty': spec.text.trim(), 'city': city.text.trim(), 'channel': channel.text.trim(),
      'sourceUrl': url.text.trim(), 'phone': phone.text.trim(), 'status': '', 'sentAt': null, 'sentCount': 0, 'createdAt': FieldValue.serverTimestamp(),
    });
    b.set(db.doc('pitchLinks/$token'), {'kind': kind.pitchKind, 'name': name.text.trim(), 'openedAt': null, 'createdAt': FieldValue.serverTimestamp()});
    await b.commit();
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int n;
  const _Stat(this.label, this.n);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text('$n', style: const TextStyle(fontSize: 26, fontWeight: black, color: Brand.green)),
        Text(label, style: const TextStyle(fontSize: 12, color: Brand.grey, fontWeight: FontWeight.w800)),
      ]);
}

/// `/r/<رمز>` بعد الدخول من رابط تسويقي: يختم «سجّل» ثم يذهب لشاشة المستخدم.
class RegisteredStamp extends StatefulWidget {
  final GrowthService growth;
  final Session session;
  final String token;
  const RegisteredStamp({super.key, required this.growth, required this.session, required this.token});

  @override
  State<RegisteredStamp> createState() => _RegisteredStampState();
}

class _RegisteredStampState extends State<RegisteredStamp> {
  @override
  void initState() {
    super.initState();
    widget.growth.markRegistered(widget.token).whenComplete(() {
      if (mounted) context.go(landing(widget.session));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator(color: Brand.green)));
}
