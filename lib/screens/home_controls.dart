// لوحة تحكم ربّة البيت: الأسرة (كبار/أطفال/حجم الحصة)، إدارة الوجبات (إخفاء/مفضلة/وجبة خاصة)، «عندي في البيت»، وإرسال المشتريات.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/household.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../logic/shopping_text.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// بطاقة الأسرة في «بيتي»: كبار، أطفال، حجم الحصة، ومداخل إدارة الوجبات والمخزن.
class HouseSettingsCard extends StatelessWidget {
  final HouseholdStore store;
  const HouseSettingsCard({super.key, required this.store});

  Widget _stepper(String label, int n, int min, int max, ValueChanged<int> set) => Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: black, fontSize: 16))),
        IconButton(onPressed: n > min ? () => set(n - 1) : null, icon: const Icon(Icons.remove_circle_outline, color: Brand.green)),
        SizedBox(width: 28, child: Text('$n', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: black))),
        IconButton(onPressed: n < max ? () => set(n + 1) : null, icon: const Icon(Icons.add_circle_outline, color: Brand.green)),
      ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final h = store.household;
          final adults = h.eaters - h.kids;
          return CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Row(children: [
                Icon(Icons.groups, color: Brand.green, size: 28),
                SizedBox(width: 8),
                Text('أسرتي وحجم الحصة', style: TextStyle(fontWeight: black, fontSize: 17, color: Brand.green)),
              ]),
              _stepper('كبار', adults, 1, 20, (v) => store.setEaters(v + h.kids)),
              _stepper('أطفال (نصف حصة)', h.kids, 0, 15, (v) => store.setEaters(adults + v).then((_) => store.setKids(v))),
              const SizedBox(height: 4),
              const Text('حجم الحصة', style: TextStyle(fontWeight: black, fontSize: 15)),
              const SizedBox(height: 6),
              Row(children: [
                for (final (v, l) in const [(0.8, 'صغيرة'), (1.0, 'عادية'), (1.3, 'كبيرة')])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => store.setPortion(v),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                              color: (h.portion - v).abs() < .01 ? Brand.green : Brand.green.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                          child: Text(l, textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: black, color: (h.portion - v).abs() < .01 ? Colors.white : Brand.green)),
                        ),
                      ),
                    ),
                  ),
              ]),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('الكميات تقديرية من وصفات شائعة لأسرة 4–5؛ إن كان أهلك يأكلون أكثر أو أقل فغيّري الحجم والقائمة تتبعه.',
                    style: TextStyle(fontSize: 12.5, color: Brand.grey, height: 1.6)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text('إدارة وجباتي'),
                    onPressed: () => showMealsManager(context, store),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.kitchen),
                    label: const Text('عندي في البيت'),
                    onPressed: () => showPantrySheet(context, store),
                  ),
                ),
              ]),
            ]),
          );
        },
      );
}

/// أزرار داخل بطاقة الوجبة: غيّريها · لا أحبها · مفضلة.
class MealActions extends StatelessWidget {
  final HouseholdStore store;
  final DateTime weekStart;
  final int day;
  final String slotId;
  final MealOption option;
  const MealActions({super.key, required this.store, required this.weekStart, required this.day, required this.slotId, required this.option});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final fav = store.household.favorites.contains(option.id);
          Widget b(IconData i, String l, VoidCallback f, {Color? c}) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), side: BorderSide(color: c ?? Brand.green)),
                    onPressed: f,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(i, color: c ?? Brand.green, size: 22),
                      Text(l, style: TextStyle(fontSize: 12.5, fontWeight: black, color: c ?? Brand.green)),
                    ]),
                  ),
                ),
              );
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(children: [
              b(Icons.autorenew, 'غيّريها', () async {
                final nav = Navigator.of(context);
                await store.replaceMeal(weekStart, day, slotId);
                nav.pop();
              }),
              b(Icons.thumb_down_alt_outlined, 'لا أحبها', () async {
                final nav = Navigator.of(context);
                await store.toggleHidden(option.id);
                await store.replaceMeal(weekStart, day, slotId);
                nav.pop();
              }, c: Colors.red.shade700),
              b(fav ? Icons.star : Icons.star_border, fav ? 'مفضلة ✓' : 'مفضلة', () => store.toggleFavorite(option.id), c: Brand.honey),
            ]),
          );
        },
      );
}

/// إدارة وجبات النظام: أخفِ ما لا تحبه الأسرة، فضّل ما تحبه، وأضف وجبتك الخاصة.
void showMealsManager(BuildContext context, HouseholdStore store) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.cream,
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: .85, minChildSize: .5, maxChildSize: .95,
        builder: (c, scroll) => FutureBuilder<Program>(
          future: store.program(),
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Brand.green));
            return ListenableBuilder(
              listenable: store,
              builder: (c, _) {
                final p = snap.data!; // يتجدد مع الوجبات الخاصة عبر إعادة فتح الصفحة؛ نقرأ الأحدث أدناه
                return FutureBuilder<Program>(
                  future: store.program(),
                  builder: (c, s2) {
                    final prog = s2.data ?? p;
                    final h = store.household;
                    return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
                      const Text('إدارة وجباتي', style: TextStyle(fontSize: 22, fontWeight: black, color: Brand.green)),
                      const Text('⭐ تظهر أكثر · 👁 إخفاء (لا تظهر في خططك الجديدة) · ➕ وجبتك الخاصة',
                          style: TextStyle(fontSize: 12.5, color: Brand.grey, height: 1.7)),
                      for (final slot in prog.slots) ...[
                        const SizedBox(height: 14),
                        Row(children: [
                          Text('${slot.icon} ${slot.name}', style: const TextStyle(fontSize: 18, fontWeight: black)),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.add_circle, color: Brand.honey),
                            label: const Text('أضيفي وجبتي', style: TextStyle(color: Brand.honey, fontWeight: black)),
                            onPressed: () => _addCustom(c, store, prog, slot),
                          ),
                        ]),
                        for (final o in slot.options)
                          Opacity(
                            opacity: h.hidden.contains(o.id) ? .45 : 1,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                dense: true,
                                title: Text(o.label, style: TextStyle(fontWeight: FontWeight.w800, decoration: h.hidden.contains(o.id) ? TextDecoration.lineThrough : null)),
                                subtitle: o.id.startsWith('c_') ? const Text('وجبتك الخاصة', style: TextStyle(fontSize: 12, color: Brand.honey)) : null,
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(
                                    tooltip: 'مفضلة',
                                    icon: Icon(h.favorites.contains(o.id) ? Icons.star : Icons.star_border, color: Brand.honey),
                                    onPressed: () => store.toggleFavorite(o.id),
                                  ),
                                  IconButton(
                                    tooltip: h.hidden.contains(o.id) ? 'إظهار' : 'إخفاء',
                                    icon: Icon(h.hidden.contains(o.id) ? Icons.visibility_off : Icons.visibility, color: Brand.grey),
                                    onPressed: () => store.toggleHidden(o.id),
                                  ),
                                  if (o.id.startsWith('c_'))
                                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => store.removeCustom(o.id)),
                                ]),
                              ),
                            ),
                          ),
                      ],
                    ]);
                  },
                );
              },
            );
          },
        ),
      ),
    );

Future<void> _addCustom(BuildContext context, HouseholdStore store, Program prog, MealSlot slot) async {
  final name = TextEditingController();
  final picked = <String>{};
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text('وجبة جديدة — ${slot.name}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: name, onChanged: (_) => set(() {}), decoration: const InputDecoration(labelText: 'اسم الوجبة (مثال: كبدة بالبصل)')),
              const SizedBox(height: 12),
              const Text('مكوّناتها (اختياري — لتدخل في المشتريات):', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in prog.ingredients.entries)
                  FilterChip(
                    label: Text('${e.value.icon} ${e.value.name}', style: const TextStyle(fontSize: 12.5)),
                    selected: picked.contains(e.key),
                    onSelected: (v) => set(() => v ? picked.add(e.key) : picked.remove(e.key)),
                  ),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: name.text.trim().isEmpty ? null : () => Navigator.pop(c, true), child: const Text('إضافة')),
        ],
      ),
    ),
  );
  if (ok == true) await store.addCustom(slotId: slot.id, label: name.text, ingredientKeys: picked.toList());
}

/// «عندي في البيت»: أصناف لا تدخل المشتريات (زيت، سكر، شاهي، بهارات…).
void showPantrySheet(BuildContext context, HouseholdStore store) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.cream,
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: .8, minChildSize: .5, maxChildSize: .95,
        builder: (c, scroll) => FutureBuilder<Program>(
          future: store.program(),
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Brand.green));
            final p = snap.data!;
            return ListenableBuilder(
              listenable: store,
              builder: (c, _) {
                final at = store.pantryOf(p);
                return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
                  const Text('عندي في البيت', style: TextStyle(fontSize: 22, fontWeight: black, color: Brand.green)),
                  const Text('ما تفعّلينه هنا لا يدخل قائمة المشتريات. ألغي التفعيل متى نفد.', style: TextStyle(fontSize: 12.5, color: Brand.grey, height: 1.7)),
                  const SizedBox(height: 8),
                  for (final e in shopCategories.entries) ...[
                    if (p.ingredients.values.any((i) => i.category == e.key))
                      Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(e.value, style: const TextStyle(fontWeight: black, color: Brand.green))),
                    for (final i in p.ingredients.entries.where((i) => i.value.category == e.key))
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: SwitchListTile(
                          dense: true,
                          activeThumbColor: Brand.green,
                          title: Text('${i.value.icon} ${i.value.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          value: at.contains(i.key),
                          onChanged: (v) => store.setPantry(i.key, v),
                        ),
                      ),
                  ],
                ]);
              },
            );
          },
        ),
      ),
    );

/// إرسال المشتريات: واتساب (للزوج أو السائق)، تطبيق توصيل (مرسول) بالنسخ ثم فتحه، أو أي تطبيق عبر المشاركة.
void showShopShare(BuildContext context, HouseholdStore store, DateTime week, Program program, List<ShoppingLine> lines, Set<String> pantry) {
  final text = shoppingText(program, lines, pantry: pantry);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('أرسلي المشتريات إلى…', textAlign: TextAlign.center, style: TextStyle(fontWeight: black, fontSize: 18, color: Brand.green)),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Brand.green, minimumSize: const Size.fromHeight(50)),
          icon: const Icon(Icons.link),
          label: const Text('رابط للزوج أو السائق (يعلّم «اشتريتُ» بلا تطبيق)', style: TextStyle(fontWeight: black)),
          onPressed: () async {
            final nav = Navigator.of(c);
            final m = ScaffoldMessenger.of(context);
            final token = await store.createShopLink(week);
            nav.pop();
            if (token == null) {
              m.showSnackBar(const SnackBar(content: Text('الرابط متاح من حساب مدير البيت')));
              return;
            }
            final msg = 'قائمة مشتريات البيت — افتح الرابط وعلّم على ما اشتريتَ:\nhttps://maeda.wardyat.net/s/$token';
            launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication);
          },
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), minimumSize: const Size.fromHeight(50)),
          icon: const Icon(Icons.chat),
          label: const Text('واتساب (القائمة نصاً)', style: TextStyle(fontWeight: black)),
          onPressed: () {
            Navigator.pop(c);
            launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          icon: const Icon(Icons.delivery_dining),
          label: const Text('مرسول (تُنسخ القائمة وتلصقينها في الطلب)'),
          onPressed: () async {
            final nav = Navigator.of(c);
            final m = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: text));
            nav.pop();
            m.showSnackBar(const SnackBar(content: Text('نُسخت القائمة — الصقيها في ملاحظات طلبك')));
            // لا رابط عميق موثَّق لمرسول: نفتح موقعه (يفتح التطبيق إن كان مثبتاً وإلا صفحة التحميل)
            launchUrl(Uri.parse('https://mrsool.co'), mode: LaunchMode.externalApplication);
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          icon: const Icon(Icons.ios_share),
          label: const Text('تطبيق آخر…'),
          onPressed: () {
            Navigator.pop(c);
            SharePlus.instance.share(ShareParams(text: text));
          },
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('نسخ القائمة فقط'),
          onPressed: () async {
            final m = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: text));
            if (c.mounted) Navigator.pop(c);
            m.showSnackBar(const SnackBar(content: Text('نُسخت القائمة')));
          },
        ),
      ]),
    ),
  );
}
