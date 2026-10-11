// التنفيذ الحقيقي للارتباط: users/{uid}.hids ← households/{hid} (members) ← invites/{code}.
// المنع الفعلي في firebase/firestore.rules (مختبَر على المحاكي)، وهنا منطق الواجهة فقط.
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_service.dart';
import '../auth/roles.dart';
import 'links.dart';

class FirestoreLinkService extends LinkService {
  final FirebaseFirestore db;
  final AuthService auth;
  final DateTime Function() _now;
  final _rnd = Random.secure();

  String? _uid;
  bool _ready = false, _isDoctor = false, _doctorRequested = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  final _hhSubs = <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
  final _invSubs = <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
  final _households = <String, Map<String, dynamic>>{};
  final _invites = <String, Invite>{};
  final _pendingFirst = <String>{};
  Set<String> _knownHids = {};

  FirestoreLinkService(this.db, this.auth, {DateTime Function()? clock}) : _now = clock ?? DateTime.now {
    auth.addListener(_onAuth);
    _onAuth();
  }

  @override
  bool get ready => _ready;
  @override
  bool get isDoctor => _isDoctor;
  @override
  bool get doctorRequested => _doctorRequested;

  String get _me => _uid!;

  void _onAuth() {
    final u = auth.user?.uid;
    if (u == _uid) return;
    _stopAll();
    _uid = u;
    _ready = false;
    if (u == null) {
      notifyListeners();
      return;
    }
    _userSub = db.doc('users/$u').snapshots().listen(_onUser, onError: (_) {
      _ready = true;
      notifyListeners();
    });
    notifyListeners();
  }

  void _stopAll() {
    _userSub?.cancel();
    for (final s in [..._hhSubs.values, ..._invSubs.values]) {
      s.cancel();
    }
    _userSub = null;
    _hhSubs.clear();
    _invSubs.clear();
    _households.clear();
    _invites.clear();
    _pendingFirst.clear();
    _knownHids = {};
    _isDoctor = _doctorRequested = false;
  }

  void _onUser(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data() ?? const <String, dynamic>{};
    _isDoctor = d['isDoctor'] == true;
    _doctorRequested = d['doctorRequested'] == true;
    final hids = {...List<String>.from(d['hids'] ?? const [])};
    _knownHids = hids;
    for (final h in _hhSubs.keys.toList()) {
      if (!hids.contains(h)) {
        _hhSubs.remove(h)?.cancel();
        _households.remove(h);
      }
    }
    for (final h in hids) {
      if (_hhSubs.containsKey(h)) continue;
      _pendingFirst.add(h);
      _listenHousehold(h, 0);
    }
    _markReady();
  }

  /// يتابع وثيقة البيت. الاستماع قد يبدأ قبل أن يثبّت الخادم كتابة الانضمام/الإنشاء (دفعة واحدة: users + households)،
  /// فيرفضه الخادم لحظة ولا يعيد Firestore محاولته أبداً ← يبقى المستخدم «بلا بيت» حتى يعيد فتح التطبيق.
  /// لذلك نعيد الاستماع بتأخير متزايد قبل أن نعدّ العضوية منتهية.
  static const _retryDelays = [Duration(milliseconds: 400), Duration(milliseconds: 900), Duration(milliseconds: 1800), Duration(milliseconds: 3500), Duration(seconds: 6)];

  void _listenHousehold(String h, int attempt) {
    _hhSubs[h] = db.doc('households/$h').snapshots().listen((s) {
      _pendingFirst.remove(h);
      if (s.exists) {
        _households[h] = s.data()!;
        _watchInvites(List<String>.from(s.data()!['inviteCodes'] ?? const []), h);
      } else {
        _households.remove(h);
      }
      _markReady();
    }, onError: (_) {
      _hhSubs.remove(h)?.cancel();
      if (attempt < _retryDelays.length && _uid != null) {
        Future.delayed(_retryDelays[attempt], () {
          if (_uid != null && !_hhSubs.containsKey(h) && _userHasHid(h)) _listenHousehold(h, attempt + 1);
        });
        return;
      }
      // لم يعد المستخدم عضواً (حُذف البيت أو أُزيل) — نتجاهله
      _pendingFirst.remove(h);
      _households.remove(h);
      _markReady();
    });
  }

  bool _userHasHid(String h) => _knownHids.contains(h);

  void _markReady() {
    if (_pendingFirst.isEmpty) _ready = true;
    notifyListeners();
  }

  void _watchInvites(List<String> codes, String hid) {
    for (final c in codes) {
      if (_invSubs.containsKey(c)) continue;
      _invSubs[c] = db.doc('invites/$c').snapshots().listen((s) {
        final d = s.data();
        if (d == null) {
          _invites.remove(c);
        } else {
          _invites[c] = Invite(c, Role.parse(d['role'] as String?) ?? Role.cook,
              (d['expiresAt'] as Timestamp).toDate(), hid: hid, usedBy: d['usedBy'] == null ? null : (d['usedByName'] as String? ?? 'عضو'));
        }
        notifyListeners();
      }, onError: (_) {});
    }
  }

  @override
  List<Membership> get memberships {
    final out = <Membership>[];
    for (final e in _households.entries) {
      final role = Role.parse((e.value['members'] as Map?)?[_uid] as String?);
      if (role == null) continue;
      out.add(Membership(e.key, e.value['label'] as String? ?? '', e.value['programId'] as String? ?? '', role));
    }
    const order = {Role.owner: 0, Role.doctor: 1, Role.cook: 2, Role.admin: 3};
    out.sort((a, b) => order[a.role]!.compareTo(order[b.role]!));
    return out;
  }

  Iterable<Invite> _invitesOf(String? hid) => _invites.values.where((i) => i.hid == hid).toList().reversed;

  String? get _ownerHid => membershipOf(Role.owner)?.householdId;

  @override
  Invite? inviteFor(Role r) =>
      _invitesOf(_ownerHid).where((i) => i.role == r && !i.used && i.expires.isAfter(_now())).firstOrNull;
  @override
  Invite? joinedBy(Role r) => _invitesOf(_ownerHid).where((i) => i.role == r && i.used).firstOrNull;

  @override
  Future<void> createHousehold(String label, String programId, int eaters, {Map<String, dynamic>? extra}) async {
    final ref = db.collection('households').doc();
    final b = db.batch();
    b.set(ref, {
      'label': label.trim(), 'programId': programId, 'eaters': eaters, 'city': 'Jeddah', 'cookName': '',
      'cutoffDay': 5, 'cutoffTime': '20:00', 'members': {_me: Role.owner.name}, 'inviteCodes': <String>[],
      'createdAt': FieldValue.serverTimestamp(), ...?extra,
    });
    b.set(db.doc('users/$_me'), {'hids': FieldValue.arrayUnion([ref.id])}, SetOptions(merge: true));
    await b.commit();
  }

  @override
  Future<Invite> createInvite(Role role, {String? householdId}) async {
    final hid = householdId ?? _ownerHid;
    if (hid == null) throw StateError('لا بيت لإصدار دعوة منه');
    String code;
    do {
      code = newInviteCode(_rnd);
    } while ((await db.doc('invites/$code').get()).exists);
    final expires = _now().add(const Duration(days: 7));
    final b = db.batch();
    b.set(db.doc('invites/$code'), {
      'hid': hid, 'role': role.name, 'createdBy': _me, 'usedBy': null, 'expiresAt': Timestamp.fromDate(expires),
    });
    b.update(db.doc('households/$hid'), {'inviteCodes': FieldValue.arrayUnion([code])});
    await b.commit();
    return Invite(code, role, expires, hid: hid);
  }

  @override
  Future<String?> redeem(String raw, Role asRole, {String who = 'مستخدم'}) async {
    final code = normalizeCode(raw);
    if (code.isEmpty) return 'اكتب الرمز أولاً.';
    final snap = await db.doc('invites/$code').get();
    final d = snap.data();
    final inv = d == null
        ? null
        : Invite(code, Role.parse(d['role'] as String?) ?? Role.cook, (d['expiresAt'] as Timestamp).toDate(),
            hid: d['hid'] as String?, usedBy: d['usedBy'] == null ? null : 'x');
    final err = checkInvite(inv, asRole, _now());
    if (err != null) return err;
    final b = db.batch();
    b.update(db.doc('invites/$code'), {'usedBy': _me, 'usedAt': FieldValue.serverTimestamp(), 'usedByName': who});
    b.update(db.doc('households/${inv!.hid}'), {'members.$_me': asRole.name, 'lastInvite': code});
    b.set(db.doc('users/$_me'), {'hids': FieldValue.arrayUnion([inv.hid])}, SetOptions(merge: true));
    try {
      await b.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return 'تعذّر الربط بهذا الرمز. اطلب رمزاً جديداً من مدير البيت.';
      rethrow;
    }
    activeHid = inv.hid; // البيت الذي انضم إليه الآن هو بيته الحالي (مهم للشريك الذي له بيت سابق)
    notifyListeners();
    return null;
  }

  @override
  Future<void> removeRole(Role role) async {
    final hid = _ownerHid;
    if (hid == null) return;
    final b = db.batch();
    final codes = _invitesOf(hid).where((i) => i.role == role).map((i) => i.code).toList();
    // من انضم: يُحذف من خريطة الأعضاء (مفتاح uid من الدعوة المستهلكة)
    for (final c in codes) {
      final used = (await db.doc('invites/$c').get()).data()?['usedBy'] as String?;
      if (used != null) b.update(db.doc('households/$hid'), {'members.$used': FieldValue.delete()});
      b.delete(db.doc('invites/$c'));
    }
    if (codes.isNotEmpty) b.update(db.doc('households/$hid'), {'inviteCodes': FieldValue.arrayRemove(codes)});
    await b.commit();
    for (final c in codes) { _invSubs.remove(c)?.cancel(); _invites.remove(c); }
    notifyListeners();
  }

  @override
  Future<void> touchCookOpen() async {
    try {
      await db.doc('users/$_me').set({'lastCookOpenAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<Role?> inviteRoleOf(String raw) async {
    final code = normalizeCode(raw);
    if (code.isEmpty) return null;
    final d = (await db.doc('invites/$code').get()).data();
    return d == null ? null : Role.parse(d['role'] as String?);
  }

  @override
  Future<void> requestDoctor({Map<String, String>? draft}) => db.doc('users/$_me').set(
      {'doctorRequested': true, 'doctorDraft': ?draft}, SetOptions(merge: true));

  @override
  Future<void> deleteMyData() async {
    for (final m in memberships) {
      final ref = db.doc('households/${m.householdId}');
      final data = _households[m.householdId] ?? const {};
      final members = (data['members'] as Map?) ?? const {};
      final soleManager = m.role == Role.owner || (m.role == Role.doctor && !members.values.contains('owner'));
      if (soleManager) {
        for (final sub in const ['weeks', 'shopping', 'private']) {
          for (final d in (await ref.collection(sub).get()).docs) {
            await d.reference.delete();
          }
        }
        for (final c in List<String>.from(data['inviteCodes'] ?? const [])) {
          await db.doc('invites/$c').delete();
        }
        await ref.delete();
      } else {
        await ref.update({'members.$_me': FieldValue.delete()});
      }
    }
    await db.doc('users/$_me').set({'hids': <String>[]}, SetOptions(merge: true));
  }

  @override
  void dispose() {
    auth.removeListener(_onAuth);
    _stopAll();
    super.dispose();
  }
}
