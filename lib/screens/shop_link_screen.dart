import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../logic/shopping_text.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// صفحة المتسوّق (الزوج/السائق) `/s/<رمز>`: بلا تسجيل ولا تطبيق. يرى القائمة مصنّفة بأقسام السوق ويعلّم «اشتريتُ»،
/// وتصل التعليمات لربّة البيت عند فتحها المشتريات. الرمز عشوائي طويل: من يملكه يقدر على تعليم الأصناف فقط.
class ShopLinkScreen extends StatelessWidget {
  final FirebaseFirestore? db;
  final String token;
  const ShopLinkScreen({super.key, required this.db, required this.token});

  @override
  Widget build(BuildContext context) {
    final d = db;
    return Scaffold(
      body: d == null
          ? const Center(child: Text('تعذّر الاتصال'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: d.doc('shopLinks/$token').snapshots(),
              builder: (context, snap) {
                if (snap.hasError || (snap.hasData && !snap.data!.exists)) {
                  return ListView(padding: EdgeInsets.zero, children: const [
                    GreenHeader(icon: '🛒', title: 'الرابط غير متاح', subtitle: 'اطلب رابطًا جديدًا من صاحبة البيت'),
                  ]);
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Brand.green));
                final data = snap.data!.data()!;
                final lines = [for (final l in (data['lines'] as List? ?? const [])) Map<String, dynamic>.from(l as Map)];
                final bought = (data['bought'] as Map?)?.cast<String, dynamic>() ?? const {};
                final done = lines.where((l) => bought[l['k']] == true).length;
                return ListView(padding: EdgeInsets.zero, children: [
                  GreenHeader(icon: '🛒', title: 'قائمة المشتريات', subtitle: data['title'] as String?),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          LinearProgressIndicator(value: lines.isEmpty ? 0 : done / lines.length, minHeight: 10, color: Brand.green,
                              backgroundColor: Brand.green.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)),
                          const SizedBox(height: 6),
                          Text('اشتريتَ $done من ${lines.length}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.grey)),
                          for (final e in shopCategories.entries) ...[
                            if (lines.any((l) => l['cat'] == e.key))
                              Padding(padding: const EdgeInsets.only(top: 14, bottom: 4), child: Text(e.value, style: const TextStyle(fontWeight: black, color: Brand.green, fontSize: 16))),
                            for (final l in lines.where((l) => l['cat'] == e.key))
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                                child: CheckboxListTile(
                                  value: bought[l['k']] == true,
                                  activeColor: Brand.green,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text('${l['icon'] ?? ''} ${l['label']}${(l['packs'] as num) > 1 ? '  × ${l['packs']}' : ''}',
                                      style: TextStyle(fontWeight: FontWeight.w800, decoration: bought[l['k']] == true ? TextDecoration.lineThrough : null,
                                          color: bought[l['k']] == true ? Brand.grey : null)),
                                  onChanged: (v) => d.doc('shopLinks/$token').update({'bought.${l['k']}': v ?? false, 'updatedAt': FieldValue.serverTimestamp()}),
                                ),
                              ),
                          ],
                          const SizedBox(height: 16),
                          const Text('علّم على ما اشتريتَه ليصل ربّة البيت. هذه القائمة من تطبيق سفرتي.', textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: Brand.grey, height: 1.6)),
                        ]),
                      ),
                    ),
                  ),
                ]);
              },
            ),
    );
  }
}
