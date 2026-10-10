import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// لوحة مدير سفرتي: طلبات تفعيل الأطباء وبلاغات المحتوى. (القواعد تسمح للمدير وحده؛ هذه الواجهة تعرض فقط.)
class AdminScreen extends StatelessWidget {
  final FirebaseFirestore? db;
  const AdminScreen({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final d = db;
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        const GreenHeader(icon: '🛠️', title: 'لوحة المدير', subtitle: 'طلبات الأطباء وبلاغات المحتوى'),
        if (d == null)
          const Padding(padding: EdgeInsets.all(24), child: Text('متاحة في تطبيق الجوال.'))
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  CardBox(
                    onTap: () => context.go('/admin/marketing'),
                    child: const Row(children: [
                      Icon(Icons.campaign, color: Brand.honey, size: 30),
                      SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('التسويق', style: TextStyle(fontWeight: black, fontSize: 17)),
                        Text('مهام اليوم، إرسال واتساب، ومعاينة العروض', style: TextStyle(fontSize: 12, color: Brand.grey)),
                      ])),
                      Icon(Icons.chevron_left),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  const Text('طلبات تفعيل الأطباء', style: TextStyle(fontWeight: black, fontSize: 17)),
                  const SizedBox(height: 8),
                  _Doctors(db: d),
                  const SizedBox(height: 20),
                  const Text('بروفايلات الأطباء (التوثيق)', style: TextStyle(fontWeight: black, fontSize: 17)),
                  const SizedBox(height: 8),
                  _Profiles(db: d),
                  const SizedBox(height: 22),
                  const Text('بلاغات المحتوى', style: TextStyle(fontWeight: black, fontSize: 17)),
                  const SizedBox(height: 8),
                  _Reports(db: d),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: () => context.go('/browse'), child: const Text('تصفّح الأنظمة')),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Doctors extends StatelessWidget {
  final FirebaseFirestore db;
  const _Doctors({required this.db});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('users').where('doctorRequested', isEqualTo: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Text('تعذّر التحميل: ${snap.error}');
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final pending = snap.data!.docs.where((d) => d.data()['isDoctor'] != true).toList();
          if (pending.isEmpty) return const CardBox(child: Text('لا طلبات معلّقة.', style: TextStyle(color: Brand.grey)));
          return Column(children: [
            for (final d in pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CardBox(
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.data()['name'] as String? ?? '', style: const TextStyle(fontWeight: black)),
                      Text(d.data()['email'] as String? ?? '', style: const TextStyle(fontSize: 12, color: Brand.grey)),
                    ])),
                    IconButton(
                      tooltip: 'رفض',
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => d.reference.update({'doctorRequested': false}),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Brand.green),
                      onPressed: () => d.reference.update({'isDoctor': true, 'doctorRequested': false}),
                      child: const Text('تفعيل'),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      );
}

class _Reports extends StatelessWidget {
  final FirebaseFirestore db;
  const _Reports({required this.db});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('reports').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Text('تعذّر التحميل: ${snap.error}');
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const CardBox(child: Text('لا بلاغات.', style: TextStyle(color: Brand.grey)));
          return Column(children: [
            for (final d in snap.data!.docs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CardBox(
                  child: Row(children: [
                    Expanded(child: Text(d.data()['reason'] as String? ?? '', style: const TextStyle(height: 1.5))),
                    IconButton(icon: const Icon(Icons.done, color: Brand.green), onPressed: () => d.reference.delete()),
                  ]),
                ),
              ),
          ]);
        },
      );
}

/// اعتماد بروفايل الطبيب العام: تفعيل verified يفتح رابطه للجميع. راجع رقم الترخيص قبل التفعيل.
class _Profiles extends StatelessWidget {
  final FirebaseFirestore db;
  const _Profiles({required this.db});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('doctors').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Text('تعذّر التحميل: ${snap.error}');
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const CardBox(child: Text('لا بروفايلات بعد.', style: TextStyle(color: Brand.grey)));
          return Column(children: [
            for (final d in snap.data!.docs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CardBox(
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.data()['name'] as String? ?? '', style: const TextStyle(fontWeight: black)),
                      Text('${d.data()['specialty'] ?? ''} · ${d.data()['city'] ?? ''}', style: const TextStyle(fontSize: 12, color: Brand.grey)),
                      Text('ترخيص: ${(d.data()['licenseNo'] as String?)?.isNotEmpty == true ? d.data()['licenseNo'] : 'غير مذكور'}',
                          style: const TextStyle(fontSize: 12, color: Brand.grey)),
                      Text('الرمز: ${d.id}', style: const TextStyle(fontSize: 12, color: Brand.grey)),
                    ])),
                    Switch(
                      value: d.data()['verified'] == true,
                      activeThumbColor: Brand.green,
                      onChanged: (v) => d.reference.update({'verified': v}),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      );
}
