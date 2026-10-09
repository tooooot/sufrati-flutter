import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/links.dart';
import '../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// إنشاء البيت بعد اختيار النظام: اسم البيت وعدد الأكلة. (الموافقة على تخزين البيانات تُضاف مع Firestore.)
class HouseCreateScreen extends StatefulWidget {
  final Library library;
  final LinkService links;
  final String programId;
  const HouseCreateScreen({super.key, required this.library, required this.links, required this.programId});

  @override
  State<HouseCreateScreen> createState() => _HouseCreateScreenState();
}

class _HouseCreateScreenState extends State<HouseCreateScreen> {
  final _name = TextEditingController();
  int _eaters = 1;
  bool _consent = false;

  @override
  Widget build(BuildContext context) {
    final meta = widget.library.meta(widget.programId);
    final ok = _name.text.trim().isNotEmpty && _consent;
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        GreenHeader(icon: meta?.icon ?? '🏠', title: 'أنشئ بيتك', subtitle: meta?.label),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'اسم البيت أو المريض', hintText: 'مثال: بيت أبو عبدالله',
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                CardBox(child: Row(children: [
                  const Expanded(child: Text('عدد من يأكل', style: TextStyle(fontWeight: black))),
                  IconButton(onPressed: _eaters > 1 ? () => setState(() => _eaters--) : null, icon: const Icon(Icons.remove_circle_outline)),
                  Text('$_eaters', style: const TextStyle(fontSize: 20, fontWeight: black)),
                  IconButton(onPressed: _eaters < 12 ? () => setState(() => _eaters++) : null, icon: const Icon(Icons.add_circle_outline)),
                ])),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('أوافق على تخزين بياناتي الغذائية لتشغيل التطبيق', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Brand.honey, minimumSize: const Size.fromHeight(52)),
                  onPressed: ok
                      ? () {
                          widget.links.createHousehold(_name.text, widget.programId, _eaters);
                          context.go('/household');
                        }
                      : null,
                  child: const Text('إنشاء البيت', style: TextStyle(fontSize: 18, fontWeight: black)),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
