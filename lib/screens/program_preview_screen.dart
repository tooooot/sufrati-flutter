import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../logic/planner.dart';
import '../widgets/nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/medical_note.dart';

/// معاينة نظام قبل التسجيل — نقل لـ program_preview.html (معرض الأطباق + أسبوع تجريبي بلا حساب).
class ProgramPreviewScreen extends StatefulWidget {
  final Library library;
  final String programId;
  const ProgramPreviewScreen({super.key, required this.library, required this.programId});

  @override
  State<ProgramPreviewScreen> createState() => _ProgramPreviewScreenState();
}

class _ProgramPreviewScreenState extends State<ProgramPreviewScreen> {
  late final Future<(Program, List<PlannedDay>)> _data = () async {
    final p = await widget.library.program(widget.programId);
    return (p, previewWeek(p, widget.library.dayNames));
  }();

  @override
  Widget build(BuildContext context) {
    final meta = widget.library.meta(widget.programId);
    if (meta == null || !meta.active) {
      return const Scaffold(body: Center(child: Text('هذا النظام غير متاح')));
    }
    return Scaffold(
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Brand.green));
          final (program, days) = snap.data!;
          final gallery = [
            for (final slot in program.slots)
              for (final o in slot.options)
                if (widget.library.photoUrl(program.meta.id, o.id) case final url?) (slot, o, url),
          ];
          return ListView(padding: EdgeInsets.zero, children: [
            GreenHeader(
              icon: meta.icon,
              title: meta.label,
              subtitle: meta.blurb,
              leading: TextButton(
                onPressed: () => context.back('/browse'),
                child: Text('‹ كل الأنظمة',
                    style: TextStyle(color: Colors.white.withValues(alpha: .85), decoration: TextDecoration.underline)),
              ),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: MedicalNote(programId: program.meta.id)),
            if (gallery.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Text('📸 تصفّح أطباق النظام',
                    style: TextStyle(fontSize: 14, fontWeight: black, color: Brand.green)),
              ),
              SizedBox(
                height: 310,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: gallery.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final (slot, o, url) = gallery[i];
                    return SizedBox(
                      width: 256,
                      child: Column(children: [
                        DishPhoto(url, width: 256, height: 256),
                        const SizedBox(height: 8),
                        Text('${slot.icon} ${slot.name}', style: const TextStyle(fontSize: 12, color: Brand.grey)),
                        Text(o.label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ]),
                    );
                  },
                ),
              ),
            ],
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 512),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('📅 جدول أسبوعي تجريبي',
                        style: TextStyle(fontSize: 18, fontWeight: black, color: Brand.green)),
                    const SizedBox(height: 4),
                    const Text('هذا مثال — جدولك الفعلي يتولّد تلقائياً ويتغيّر أسبوعياً، وتقدر تعدّله بنفسك.',
                        style: TextStyle(fontSize: 12, color: Brand.grey)),
                    const SizedBox(height: 12),
                    for (final (i, day) in days.indexed) ...[
                      _DayCard(day: day, program: program, library: widget.library, initiallyOpen: i == 0),
                      const SizedBox(height: 8),
                    ],
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -4))]),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Brand.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => context.push('/signup/${widget.programId}'),
            child: const Text('🚀 اقتنعت — ابدأ بهذا النظام',
                style: TextStyle(fontSize: 20, fontWeight: black, fontFamily: 'Tajawal')),
          ),
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final PlannedDay day;
  final Program program;
  final Library library;
  final bool initiallyOpen;
  const _DayCard({required this.day, required this.program, required this.library, required this.initiallyOpen});

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyOpen,
          title: Text(day.name, style: const TextStyle(fontSize: 18, fontWeight: black, color: Brand.green)),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            for (final s in day.slots) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(s.slot.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(s.slot.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Brand.grey)),
                  ]),
                  const SizedBox(height: 8),
                  if (library.photoUrl(program.meta.id, s.option.id) case final url?) ...[
                    DishPhoto(url, width: double.infinity, height: 128, radius: 12),
                    const SizedBox(height: 8),
                  ],
                  Text(s.option.label, style: const TextStyle(fontWeight: black)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final it in scaledItems(s.option, 1, program.ingredients))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: '${it.icon} ', style: const TextStyle(fontSize: 15)),
                          TextSpan(text: '${it.qtyLabel} ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          TextSpan(text: it.label, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                        ])),
                      ),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
