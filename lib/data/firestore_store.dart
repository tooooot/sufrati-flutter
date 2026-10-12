// مخزن البيت الحقيقي: households/{hid}/weeks/{yyyy-MM-dd} و shopping/{yyyy-MM-dd}.
// من يملك صلاحية الإدارة (مدير البيت/الطبيب) يولّد خطة الأسبوع عند أول فتح؛ الطاهي يقرأ فقط ويعلّم «جاهز».
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'events.dart';

import '../logic/planner.dart';
import '../logic/prayer.dart';
import '../logic/shopping.dart';
import '../logic/shopping_text.dart';
import 'household.dart';
import 'models.dart';
import 'repository.dart';
import 'store.dart';

/// الطاهي فتح الأسبوع قبل أن يجهّز مدير البيت أو الطبيب خطته.
class PlanNotReady implements Exception {
  const PlanNotReady();
  @override
  String toString() => 'لم تُجهَّز خطة هذا الأسبوع بعد. اطلب من مدير البيت فتح التطبيق.';
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
    // الجسم والهدف (عمر/طول/وزن/سعرات) بيانات صحية: في private/body لا في وثيقة البيت المقروءة للطاهي أيضاً
    Map<String, dynamic>? body;
    if (canManage) {
      try {
        body = (await db.doc('households/$hid/private/body').get()).data();
      } catch (_) {}
      if (body == null && (d['target'] != null || d['profile'] != null)) {
        // بيت قديم حفظها في الوثيقة العامة: ننقلها ونمسحها من هناك
        body = {if (d['profile'] != null) 'profile': d['profile'], if (d['target'] != null) 'target': d['target']};
        try {
          await db.doc('households/$hid/private/body').set(body);
          await db.doc('households/$hid').update({'target': FieldValue.delete(), 'profile': FieldValue.delete()});
        } catch (_) {}
      }
    }
    final h = Household(
      id: hid,
      label: d['label'] as String? ?? '',
      programId: d['programId'] as String? ?? '',
      cookName: d['cookName'] as String? ?? '',
      city: d['city'] as String? ?? 'Jeddah',
      eaters: (d['eaters'] as num?)?.toInt() ?? 1,
      kids: (d['kids'] as num?)?.toInt() ?? 0,
      portion: (d['portion'] as num?)?.toDouble() ?? 1.0,
      track: d['track'] as String? ?? 'family',
      target: (body?['target'] as Map?)?.cast<String, dynamic>(),
      profile: (body?['profile'] as Map?)?.cast<String, dynamic>(),
      pantry: (d['pantry'] as List?)?.cast<String>().toSet(),
      hidden: ((d['hidden'] as List?)?.cast<String>() ?? const <String>[]).toSet(),
      favorites: ((d['favorites'] as List?)?.cast<String>() ?? const <String>[]).toSet(),
      custom: [for (final c in (d['custom'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)],
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
        final t = d.data()['shopToken'] as String?;
        if (t != null) _shopTokens[d.id] = t;
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
            (e.value as Map)['bought'] == true, ((e.value as Map)['auto'] as num?)?.toInt(), ((e.value as Map)['need'] as num?)?.toDouble() ?? 0),
    ]..sort((a, b) => a.key.compareTo(b.key));
  }

  @override
  Future<Program> baseProgram() => library.program(household.programId);

  @override
  Future<void> persistHousehold(Map<String, Object?> fields) async {
    if (!canManage) return;
    final priv = {for (final k in const ['target', 'profile']) if (fields.containsKey(k)) k: fields[k]};
    final pub = {for (final e in fields.entries) if (!priv.containsKey(e.key)) e.key: e.value};
    if (priv.isNotEmpty) await db.doc('households/$hid/private/body').set(priv, SetOptions(merge: true));
    if (pub.isNotEmpty) await db.doc('households/$hid').update(pub);
  }

  @override
  Future<void> reflowShopping() async {
    // الكميات تتبع العدد/الحصة/المخزن: نعيد حساب مشتريات هذا الأسبوع والقادم مع إبقاء ما اشتُري
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final ws = weekStartFor(DateTime(now.year, now.month, now.day));
    for (final w in [ws, ws.add(const Duration(days: 7))]) {
      if (_weeks.containsKey(weekId(w))) {
        _shopping.remove(weekId(w));
        await _saveShopping(w, await _build(w, previous: _prevLines[weekId(w)]));
      }
    }
  }

  @override
  Future<void> regenerateWeek(DateTime weekStart) async {
    if (!canManage) return;
    final id = weekId(weekStart);
    final old = _weeks[id];
    final avoid = <String, Set<String>>{};
    for (final d in old?.days ?? const <Map<String, String>>[]) {
      d.forEach((slot, opt) => (avoid[slot] ??= {}).add(opt));
    }
    final p = await program();
    final days = List.generate(7, (_) => <String, String>{});
    for (final pick in (household.personal ? pickBalancedWeek(p, avoid: avoid, hidden: household.hidden, favorites: household.favorites) : pickWeekOptions(p, avoid: avoid, hidden: household.hidden, favorites: household.favorites))) {
      days[pick.day][pick.slotId] = pick.option.id;
    }
    _weeks[id] = WeekPlan(weekStart, days);
    await db.doc('households/$hid/weeks/$id').set({'days': days, 'prepared': <String>[], 'createdAt': FieldValue.serverTimestamp()});
    _shopping.remove(id);
    await _saveShopping(weekStart, await _build(weekStart, previous: _prevLines[id]));
    notifyListeners();
    if (household.personal && household.targetKcal > 0) await calibrateToTarget();
  }

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
    for (final pick in (household.personal ? pickBalancedWeek(p, avoid: avoid, hidden: household.hidden, favorites: household.favorites) : pickWeekOptions(p, avoid: avoid, hidden: household.hidden, favorites: household.favorites))) {
      days[pick.day][pick.slotId] = pick.option.id;
    }
    final plan = WeekPlan(weekStart, days);
    _weeks[id] = plan;
    await db.doc('households/$hid/weeks/$id').set({'days': days, 'prepared': <String>[], 'createdAt': FieldValue.serverTimestamp()});
    return plan;
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
      // يُخبَر مدير البيت والطبيب أن الوجبة حُضّرت (اسم الوجبة بالعربية كما في البرنامج)
      final name = (await program()).slots.where((x) => x.id == slot).firstOrNull?.name;
      EventQueue.instance.emit('prepared', hid: hid, meal: name, throttleKey: 'prep:$hid:${weekId(weekStart)}:$k', every: const Duration(minutes: 5));
    }
  }

  final _prevLines = <String, List<ShoppingLine>>{};

  Future<List<ShoppingLine>> _build(DateTime ws, {List<ShoppingLine>? previous}) async =>
      _buildLines(await program(), await week(ws), previous);

  List<ShoppingLine> _buildLines(Program p, WeekPlan w, List<ShoppingLine>? previous) =>
      buildShopping(p, w, household.servings, previous: previous, pantry: pantryOf(p));

  Future<void> _saveShopping(DateTime ws, List<ShoppingLine> lines) async {
    final id = weekId(ws);
    _shopping[id] = lines;
    _prevLines[id] = lines;
    await db.doc('households/$hid/shopping/$id').set({
      'lines': {for (final l in lines) l.key: {'packs': l.packs, 'unitPrice': l.unitPrice, 'bought': l.bought, 'auto': l.auto ?? l.packs, 'need': l.need}},
    });
  }

  final _shopTokens = <String, String>{};

  @override
  Future<String?> createShopLink(DateTime weekStart) async {
    if (!canManage) return null;
    final id = weekId(weekStart);
    final prog = await program();
    final lines = await shopping(weekStart);
    final r = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghijkmnpqrstuvwxyz';
    final token = List.generate(14, (_) => chars[r.nextInt(chars.length)]).join();
    await db.doc('shopLinks/$token').set({
      'hid': hid, 'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '', 'title': household.label, 'week': id,
      ...shopLinkLines(prog, lines, pantry: pantryOf(prog)), 'createdAt': FieldValue.serverTimestamp(),
    });
    _shopTokens[id] = token;
    await db.doc('households/$hid/shopping/$id').set({'shopToken': token}, SetOptions(merge: true));
    return token;
  }

  @override
  Future<void> syncShopLink(DateTime weekStart) async {
    final id = weekId(weekStart);
    final token = _shopTokens[id];
    if (token == null) return;
    try {
      final d = (await db.doc('shopLinks/$token').get()).data();
      final bought = (d?['bought'] as Map?)?.cast<String, dynamic>() ?? const {};
      final lines = await shopping(weekStart);
      for (final l in lines) {
        final v = bought[l.key] == true;
        if (v != l.bought) await updateShopping(weekStart, l.key, bought: v);
      }
    } catch (_) {}
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
      'lines': {key: {'packs': line.packs, 'unitPrice': line.unitPrice, 'bought': line.bought, 'auto': line.auto ?? line.packs}},
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
