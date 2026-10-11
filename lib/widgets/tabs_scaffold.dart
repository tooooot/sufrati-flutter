import 'package:flutter/material.dart';

import '../theme.dart';
import 'medical_note.dart';
import 'nav.dart';

class TabItem {
  final IconData icon;
  final String label;
  final WidgetBuilder builder;
  const TabItem(this.icon, this.label, this.builder);
}

/// يتحكم بالتبويب النشط من خارج الشريط (بطاقات الإجراءات السريعة تنقل المستخدم بنقرة).
class TabsController extends ChangeNotifier {
  int _index = 0;
  int get index => _index;
  void select(int i) {
    if (i == _index) return;
    _index = i;
    notifyListeners();
  }
}

/// الشريط السفلي الثابت: وجهات قليلة بأيقونة داخل كبسولة للنشطة (نفس مبدأ الواجهة المعتمدة).
class TabsScaffold extends StatefulWidget {
  final Widget? header;
  /// ترويسة تتبدل مع التبويب (الفهرس، اسمه) وتغلب [header].
  final Widget Function(int index, String label)? tabHeader;
  final List<TabItem> tabs;
  final String? programId;
  final TabsController? controller;
  const TabsScaffold({super.key, this.header, this.tabHeader, required this.tabs, this.programId, this.controller});

  @override
  State<TabsScaffold> createState() => _TabsScaffoldState();
}

class _TabsScaffoldState extends State<TabsScaffold> {
  late final TabsController _c = widget.controller ?? TabsController();

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _c.removeListener(_onChange);
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = _c.index.clamp(0, widget.tabs.length - 1);
    // الرجوع: من أي تبويب غير الأول ← للأول، ثم ضغطتان للخروج
    return ExitGuard(
      onBack: () {
        if (_c.index != 0) {
          _c.select(0);
          return true;
        }
        return false;
      },
      child: Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        widget.tabHeader != null ? widget.tabHeader!(i, widget.tabs[i].label) : widget.header!,
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 512),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
              child: Column(children: [Builder(builder: widget.tabs[i].builder), if (i == 0) MedicalNote(programId: widget.programId)]),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, -4))]),
        child: SafeArea(
          top: false,
          child: Row(children: [
            for (final (n, t) in widget.tabs.indexed)
              Expanded(
                child: InkWell(
                  onTap: () => _c.select(n),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 56, height: 32,
                        decoration: BoxDecoration(
                          color: n == i ? Brand.green.withValues(alpha: .14) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(t.icon, size: 24, color: n == i ? Brand.green : const Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 2),
                      Text(t.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800,
                          color: n == i ? Brand.green : const Color(0xFF6B7280))),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
      ),
    );
  }
}
