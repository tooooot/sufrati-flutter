import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/roles.dart';
import '../data/firestore_store.dart';
import '../data/links.dart';
import '../data/repository.dart';
import '../data/store.dart';
import '../theme.dart';
import 'common.dart';

/// يفتح مخزن بيت المستخدم الحقيقي بحسب دوره، ويعرض حالات التحميل والخطأ وعدم وجود بيت.
class StoreLoader extends StatefulWidget {
  final FirebaseFirestore? db;
  final LinkService links;
  final Library library;
  final Role role; // owner/doctor يديران الخطة، cook يقرأ فقط
  final Widget Function(HouseholdStore store) builder;
  const StoreLoader({super.key, required this.db, required this.links, required this.library, required this.role, required this.builder});

  @override
  State<StoreLoader> createState() => _StoreLoaderState();
}

class _StoreLoaderState extends State<StoreLoader> {
  FirestoreStore? _store;
  Future<FirestoreStore>? _future;
  String? _hid;

  Membership? get _membership => widget.links.membershipOf(widget.role);

  void _open(Membership m) {
    _store?.dispose();
    _store = null;
    _hid = m.householdId;
    _future = FirestoreStore.open(widget.db!, widget.library, m.householdId, canManage: widget.role != Role.cook)
        .then((s) => _store = s);
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.links,
        builder: (context, _) {
          final m = _membership;
          if (widget.db == null) return _Msg('🔒', 'الدخول متاح في تطبيق الجوال', 'ثبّت سفرتي على أندرويد أو آيفون.');
          if (m == null) {
            return _Msg('🏠', widget.role == Role.cook ? 'لست مرتبطاً ببيت بعد' : 'لا بيت بعد',
                widget.role == Role.cook ? 'اطلب رمز الدعوة من صاحب البيت.' : 'أنشئ بيتك أو اطلب رمزاً من مريضك.',
                action: widget.role == Role.cook ? ('إدخال الرمز', '/join/cook') : ('بيتي', '/household'));
          }
          if (_hid != m.householdId) _open(m);
          return FutureBuilder<FirestoreStore>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return _Msg('⚠️', 'تعذّر فتح البيت', '${snap.error}', action: ('إعادة المحاولة', '/loading'));
              }
              if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              return widget.builder(snap.data!);
            },
          );
        },
      );
}

class _Msg extends StatelessWidget {
  final String icon, title, sub;
  final (String, String)? action;
  const _Msg(this.icon, this.title, this.sub, {this.action});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [
          GreenHeader(icon: icon, title: title),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Brand.grey, height: 1.7)),
              if (action != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: () => context.go(action!.$2), child: Text(action!.$1)),
              ],
            ]),
          ),
        ]),
      );
}
