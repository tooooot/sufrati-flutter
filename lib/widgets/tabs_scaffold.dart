import 'package:flutter/material.dart';

import '../theme.dart';
import 'medical_note.dart';

class TabItem {
  final String icon, label;
  final WidgetBuilder builder;
  const TabItem(this.icon, this.label, this.builder);
}

/// شريط التبويب السفلي الثابت (نفس bottom-nav في الموقع).
class TabsScaffold extends StatefulWidget {
  final Widget header;
  final List<TabItem> tabs;
  final String? programId;
  const TabsScaffold({super.key, required this.header, required this.tabs, this.programId});

  @override
  State<TabsScaffold> createState() => _TabsScaffoldState();
}

class _TabsScaffoldState extends State<TabsScaffold> {
  int _i = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [
          widget.header,
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 512),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
                child: Column(children: [Builder(builder: widget.tabs[_i].builder), MedicalNote(programId: widget.programId)]),
              ),
            ),
          ),
        ]),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 12, offset: Offset(0, -4))]),
          child: SafeArea(
            top: false,
            child: Row(children: [
              for (final (i, t) in widget.tabs.indexed)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _i = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Opacity(opacity: i == _i ? 1 : .45, child: Text(t.icon, style: const TextStyle(fontSize: 22))),
                        Text(t.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: i == _i ? Brand.green : Colors.grey)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
