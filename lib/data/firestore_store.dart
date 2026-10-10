// مخزن البيت الحقيقي: households/{hid}/weeks/{yyyy-MM-dd} و shopping/{yyyy-MM-dd}.
// من يملك صلاحية الإدارة (صاحب الخطة/الطبيب) يولّد خطة الأسبوع عند أول فتح؛ الطاهي يقرأ فقط ويعلّم «جاهز».
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'events.dart';

import '../logic/planner.dart';
import '../logic/prayer.dart';
import '../logic/shopping.dart';
import 'household.dart';
import 'models.dart';
import 'repository.dart';
import 'store.dart';

/// الطاهي فتح الأسبوع قبل أن يجهّز صاحب الخطة أو الطبيب خطته.
class PlanNotReady implements Exception {
  const PlanNotReady();
  @override
  String toString() => 'لم تُجهَّز خطة هذا الأسبوع بعد. اطلب من صاحب الخطة فتح التطبيق.';
}

String weekId(DateTime ws) =>
    '${ws.year.toString().padLeft(4, '0')}-${ws.month.toString().padLeft(2, '0')}-${ws.day.toString().padLeft(2, '0')}';

class FirestoreStore extends HouseholdStore {
  final FirebaseFirestore db;
  final Library library;
  final String hid;
  final bool canManage;
  @override
  final Household household;

  final _weeks = <String, WeekPlan>{};
  final _shopping = <String, List<ShoppingLine>>{};
  final _subs = <StreamSubscription<dynamic>>[];
  Completer<void>? _loaded;

  FirestoreStore._(this.db, this.library, this.hid, this.canManage, this.household);

  /// يفتح مخزن بيت: يقرأ وثيقة البيت ثم يتابع الأسابيع والمشتريات لحظياً.
  static Future<FirestoreStore> open(FirebaseFirestore db, Library library, String hid, {required bool canManage}) async {
    final snap = await db.doc('households/$hid').get();
    final d = snap.data();
    if (d == null) throw StateError('البيت غير موجود أو لا تملك صلاحية الوصول إليه');
    final h = Household(
      id: hid,
      label: d['label'] as String? ?? '',
      programId: d['programId'] as String? ?? '',
      cookName: d['cookName'] as String? ?? '',
      city: d['city'] as String? ?? 'Jeddah',
      eaters: (d['eaters'] as num?)?.toInt() ?? 1,
      cutoffDay: (d['cutoffDay'] as num?)?.toInt() ?? 5,
      cutoffTime: d['cutoffTime'] as String? ?? '20:00',
      mealLinks: (d['mealLinks'] as Map?)?.map((k, v) =>
          MapEntry(k as String, PrayerLink((v as Map)['prayer'] as String, ((v)['offset'] as num).toInt()))),
    );
    return FirestoreStore._(db, library, hid, canManage, h).._listen();
  }

  void _listen() {
    final weeks = Completer<void>(), shop = Completer<void>();
    _loaded = Completer<void>();
    _subs.add(db.collection('households/$hid/weeks').snapshots().listen((s) {
      for (final d in s.docs) {
        _weeks[d.id] = _planFrom(DateTime.parse(d.id), d.data());
      }
      if (!weeks.isCompleted) weeks.complete();
      notifyListeners();
    }, onError: (_) {
      if (!weeks.isCompleted) weeks.complete();
    }));
    _subs.add(db.collection('households/$hid/shopping').snapshots().listen((s) {
      for (final d in s.docs) {
        _shopping[d.id] = _linesFrom(d.data());
      }
      if (!shop.isCompleted) shop.complete();
      notifyListeners();
    }, onError: (_) {
      if (!shop.isCompleted) shop.complete();
    }));
    Future.wait([weeks.future, shop.future]).then((_) => _loaded!.complete());
  }

  WeekPlan _planFrom(DateTime ws, Map<String, dynamic> d) => WeekPlan(
        ws,
        [for (final m in (d['days'] as List? ?? const [])) {for (final e in (m as Map).entries) e.key as String: e.value as String}],
        {...List<String>.from(d['prepared'] ?? const [])},
      );

  List<ShoppingLine> _linesFrom(Map<String, dynamic> d) {
    final lines = (d['lines'] as Map? ?? const {});
    return [
      for (final e in lines.entries)
        ShoppingLine(e.key as String, ((e.value as Map)['packs'] as num).toInt(), ((e.value as Map)['unitPrice'] as num).toDouble(),
            (e.value as Map)['bought'] == true),
    ]..sort((a, b) => a.key.compareTo(b.key));
  }

  @override
  Future<Program> program() => library.program(household.programId);

  @override
  Future<WeekPlan> week(DateTime weekStart) async {
    await _loaded!.future;
    final id = weekId(weekStart);
    final hit = _weeks[id];
    if (hit != null) return hit;
    if (!canManage) throw const PlanNotReady();
    final p = await program();
    final days = List.generate(7, (_) => <String, String>{});
    // لا يكرر الأسبوع الجديد وجبات الأسبوع الماضي حرفياً (ربّة البيت تكره التكرار)
    final prev = _weeks[weekId(weekStart.subtract(const Duration(days: 7)))];
    final avoid = <String, Set<String>>{};
    for (final d in prev?.days ?? const <Map<String, String>>[]) {
      d.forEach((slot, opt) => (avoid[slot] ??= {}).add(opt));
    }
    for (final pick in pickWeekOptions(p, avoid: avoid)) {
      days[pick.day][pick.slotId] = pick.option.id;
    }
    final plan = WeekPlan(weekStart, days);
    _weeks[id] = plan;
    await db.doc('households/$hid/weeks/$id').set({'days': days, 'prepared': <String>[], 'createdAt': FieldValue.serverTimestamp()});
    return plan;
  }

  @override
  Future<void> setEaters(int n) async {
    final v = n.clamp(1, 20);
    if (!canManage || v == household.eaters) return;
    household.eaters = v;
    await db.doc('households/$hid').update({'eaters': v});
    // الكميات تتبع العدد: نعيد حساب مشتريات هذا الأسبوع والقادم مع إبقاء ما اشتُري
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final ws = weekStartFor(DateTime(now.year, now.month, now.day));
    for (final w in [ws, ws.add(const Duration(days: 7))]) {
      if (_weeks.containsKey(weekId(w))) {
        _shopping.remove(weekId(w));
        await _saveShopping(w, await _build(w, previous: _prevLines[weekId(w)]));
      }
    }
    notifyListeners();
  }

  @override
  Future<void> setOption(DateTime weekStart, int day, String slot, String optionId) async {
    final plan = await week(weekStart);
    plan.days[day][slot] = optionId;
    _shopping.remove(weekId(weekStart)); // تُعاد مع الحفاظ على تعديلات المستخدم
    await db.doc('households/$hid/weeks/${weekId(weekStart)}').update({'days': plan.days});
    await _saveShopping(weekStart, await _build(weekStart, previous: _prevLines[weekId(weekStart)]));
    notifyListeners();
    // تعديلات متتابعة ← إشعار واحد للطاهي والطرف الآخر كل 30 ثانية على الأكثر
    EventQueue.instance.emit('planChanged', hid: hid, throttleKey: 'plan:$hid', every: const Duration(seconds: 30));
  }

  @override
  Future<void> setPrepared(DateTime weekStart, int day, String slot, bool value) async {
    final plan = await week(weekStart);
    final k = '$day:$slot';
    value ? plan.prepared.add(k) : plan.prepared.remove(k);
    notifyListeners();
    await db.doc('households/$hid/weeks/${weekId(weekStart)}').update({
      'prepared': value ? FieldValue.arrayUnion([k]) : FieldValue.arrayRemove([k]),
    });
    if (value) {
      // يُخبَر صاحب الخطة والطبيب أن الوجبة حُضّرت (اسم الوجبة بالعربية كما في البرنامج)
      final name = (await program()).slots.where((x) => x.id == slot).firstOrNull?.name;
      EventQueue.instance.emit('prepared', hid: hid, meal: name, throttleKey: 'prep:$hid:${weekId(weekStart)}:$k', every: const Duration(minutes: 5));
    }
  }

  final _prevLines = <String, List<ShoppingLine>>{};

  Future<List<ShoppingLine>> _build(DateTime ws, {List<ShoppingLine>? previous}) async =>
      buildShopping(await program(), await week(ws), household.eaters, previous: previous);

  Future<void> _saveShopping(DateTime ws, List<ShoppingLine> lines) async {
    final id = weekId(ws);
    _shopping[id] = lines;
    _prevLines[id] = lines;
    await db.doc('households/$hid/shopping/$id').set({
      'lines': {for (final l in lines) l.key: {'packs': l.packs, 'unitPrice': l.unitPrice, 'bought': l.bought}},
    });
  }

  @override
  Future<List<ShoppingLine>> shopping(DateTime weekStart) async {
    await _loaded!.future;
    final id = weekId(weekStart);
    final hit = _shopping[id];
    if (hit != null) return hit;
    final lines = await _build(weekStart);
    if (canManage) {
      await _saveShopping(weekStart, lines);
    } else {
      _shopping[id] = lines; // الطاهي: عرض محلي فقط (القواعد تمنعه من الكتابة)
    }
    return lines;
  }

  @override
  Future<void> updateShopping(DateTime weekStart, String key, {int? packs, bool? bought}) async {
    final line = (await shopping(weekStart)).where((l) => l.key == key).firstOrNull;
    if (line == null) return;
    if (packs != null) line.packs = packs;
    if (bought != null) line.bought = bought;
    notifyListeners();
    await db.doc('households/$hid/shopping/${weekId(weekStart)}').set({
      'lines': {key: {'packs': line.packs, 'unitPrice': line.unitPrice, 'bought': line.bought}},
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
