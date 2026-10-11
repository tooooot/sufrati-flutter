// النمو: بروفايل الطبيب العام، وطلبات الربط من المرضى، وروابط التسويق باسم الشخص.
// GrowthService واجهة؛ FirestoreGrowthService هو التنفيذ الحقيقي، وMemoryGrowthService للاختبارات.
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_service.dart';
import '../auth/roles.dart';
import 'events.dart';
import 'links.dart';

class DoctorProfile {
  final String code, uid, name, specialty, city, bio, licenseNo;
  final bool verified;
  const DoctorProfile({required this.code, required this.uid, required this.name, this.specialty = '', this.city = '',
      this.bio = '', this.licenseNo = '', this.verified = false});

  /// رابط الطبيب العام الذي ينشره بين متابعيه.
  String get link => 'https://maeda.wardyat.net/dr/$code';
}

class LinkRequest {
  final String id, from, fromName, hid, inviteCode;
  const LinkRequest(this.id, this.from, this.fromName, this.hid, this.inviteCode);
}

/// رابط تسويقي باسم شخص: النوع (doctor/group/cook/user) والاسم الأول فقط.
class PitchLink {
  final String token, kind, name;
  const PitchLink(this.token, this.kind, this.name);
}

abstract class GrowthService {
  Future<DoctorProfile?> myProfile();
  Future<DoctorProfile> saveProfile({required String name, String specialty, String city, String bio, String licenseNo});
  Future<DoctorProfile?> byCode(String code);

  /// مدير البيت يطلب الارتباط بطبيب بالرمز. يرجع نص الخطأ أو null عند النجاح.
  Future<String?> requestLink(String code);
  Future<List<LinkRequest>> requests();
  /// الطبيب يقبل (يستهلك دعوة المريض) أو يرفض. يرجع نص الخطأ أو null.
  Future<String?> accept(LinkRequest r);
  Future<void> decline(LinkRequest r);

  Future<PitchLink?> pitch(String token);

  /// يختم رابط التسويق «سجّل» باسم المستخدم الحالي (مرة واحدة، فشله لا يمنع شيئاً).
  Future<void> markRegistered(String token);
}

String newDoctorCode(Random r) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // بلا حروف ملتبسة (0/O و1/I)
  return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
}

class FirestoreGrowthService implements GrowthService {
  final FirebaseFirestore db;
  final AuthService auth;
  final LinkService links;
  final Random _rnd;
  FirestoreGrowthService(this.db, this.auth, this.links, {Random? random}) : _rnd = random ?? Random.secure();

  String get _me => auth.user!.uid;

  DoctorProfile? _fromDoc(String code, Map<String, dynamic>? d) => d == null
      ? null
      : DoctorProfile(
          code: code, uid: d['uid'] as String? ?? '', name: d['name'] as String? ?? '', specialty: d['specialty'] as String? ?? '',
          city: d['city'] as String? ?? '', bio: d['bio'] as String? ?? '', licenseNo: d['licenseNo'] as String? ?? '',
          verified: d['verified'] == true);

  @override
  Future<DoctorProfile?> myProfile() async {
    final code = (await db.doc('users/$_me').get()).data()?['doctorCode'] as String?;
    if (code == null) return null;
    return _fromDoc(code, (await db.doc('doctors/$code').get()).data());
  }

  @override
  Future<DoctorProfile> saveProfile({required String name, String specialty = '', String city = '', String bio = '', String licenseNo = ''}) async {
    final fields = {'name': name.trim(), 'specialty': specialty.trim(), 'city': city.trim(), 'bio': bio.trim(), 'licenseNo': licenseNo.trim()};
    final mine = await myProfile();
    if (mine != null) {
      // تغيير الاسم أو رقم الترخيص يعيد البروفايل لمراجعة المدير (الاعتماد يخصّ ما راجعه)
      final recheck = mine.verified && (fields['name'] != mine.name || fields['licenseNo'] != mine.licenseNo);
      await db.doc('doctors/${mine.code}').update({...fields, if (recheck) 'verified': false});
      return DoctorProfile(code: mine.code, uid: mine.uid, name: fields['name']!, specialty: fields['specialty']!, city: fields['city']!,
          bio: fields['bio']!, licenseNo: fields['licenseNo']!, verified: mine.verified && !recheck);
    }
    final code = newDoctorCode(_rnd);
    final b = db.batch();
    b.set(db.doc('doctors/$code'), {...fields, 'uid': _me, 'verified': false, 'createdAt': FieldValue.serverTimestamp()});
    b.set(db.doc('users/$_me'), {'doctorCode': code}, SetOptions(merge: true));
    await b.commit();
    return DoctorProfile(code: code, uid: _me, name: fields['name']!, specialty: fields['specialty']!, city: fields['city']!,
        bio: fields['bio']!, licenseNo: fields['licenseNo']!);
  }

  @override
  Future<DoctorProfile?> byCode(String code) async {
    final c = normalizeCode(code);
    if (c.isEmpty) return null;
    try {
      return _fromDoc(c, (await db.doc('doctors/$c').get()).data());
    } on FirebaseException {
      return null; // غير معتمد أو غير موجود: لا نكشف الفرق
    }
  }

  @override
  Future<String?> requestLink(String code) async {
    final c = normalizeCode(code);
    final doc = await byCode(c);
    if (doc == null) return 'رابط الطبيب غير متاح.';
    final m = links.membershipOf(Role.owner);
    if (m == null) return 'أنشئ بيتك أولاً.';
    try {
      final inv = links.inviteFor(Role.doctor) ?? await links.createInvite(Role.doctor);
      await db.collection('doctors/$c/requests').add({
        'from': _me, 'fromName': auth.user?.name ?? '', 'hid': m.householdId, 'inviteCode': inv.code,
        'createdAt': FieldValue.serverTimestamp(),
      });
      EventQueue.instance.emit('doctorRequest', code: c, throttleKey: 'dr:$c:$_me', every: const Duration(hours: 1));
      return null;
    } on FirebaseException {
      return 'تعذّر إرسال الطلب. حاول مرة أخرى.';
    }
  }

  @override
  Future<List<LinkRequest>> requests() async {
    final mine = await myProfile();
    if (mine == null) return const [];
    final snap = await db.collection('doctors/${mine.code}/requests').get();
    return [
      for (final d in snap.docs)
        LinkRequest(d.id, d['from'] as String? ?? '', d['fromName'] as String? ?? '', d['hid'] as String? ?? '', d['inviteCode'] as String? ?? '')
    ];
  }

  @override
  Future<String?> accept(LinkRequest r) async {
    final err = await links.redeem(r.inviteCode, Role.doctor, who: auth.user?.name ?? 'طبيب');
    if (err != null) return err;
    await decline(r);
    return null;
  }

  @override
  Future<void> decline(LinkRequest r) async {
    final mine = await myProfile();
    if (mine != null) await db.doc('doctors/${mine.code}/requests/${r.id}').delete();
  }

  @override
  Future<void> markRegistered(String token) async {
    try {
      await db.doc('pitchLinks/$token').update({'registeredAt': FieldValue.serverTimestamp(), 'registeredBy': _me});
    } catch (_) {}
  }

  @override
  Future<PitchLink?> pitch(String token) async {
    try {
      final ref = db.doc('pitchLinks/$token');
      final d = (await ref.get()).data();
      if (d == null) return null;
      if (d['openedAt'] == null) {
        // تسجيل أول فتح (القواعد تسمح به مرة واحدة)؛ فشله لا يمنع العرض
        ref.update({'openedAt': FieldValue.serverTimestamp()}).catchError((_) {});
      }
      return PitchLink(token, d['kind'] as String? ?? 'user', d['name'] as String? ?? '');
    } on FirebaseException {
      return null;
    }
  }
}

/// تنفيذ في الذاكرة للاختبارات.
class MemoryGrowthService implements GrowthService {
  final LinkService links;
  final String uid, userName;
  MemoryGrowthService(this.links, {this.uid = 'u1', this.userName = 'مستخدم'});
  final profiles = <String, DoctorProfile>{};
  final reqs = <String, List<LinkRequest>>{};
  final pitches = <String, PitchLink>{};
  String? _myCode;

  @override
  Future<DoctorProfile?> myProfile() async => _myCode == null ? null : profiles[_myCode];

  @override
  Future<DoctorProfile> saveProfile({required String name, String specialty = '', String city = '', String bio = '', String licenseNo = ''}) async {
    _myCode ??= newDoctorCode(Random(1));
    final old = profiles[_myCode];
    final recheck = old != null && old.verified && (old.name != name || old.licenseNo != licenseNo);
    return profiles[_myCode!] = DoctorProfile(code: _myCode!, uid: uid, name: name, specialty: specialty, city: city, bio: bio,
        licenseNo: licenseNo, verified: (old?.verified ?? false) && !recheck);
  }

  @override
  Future<DoctorProfile?> byCode(String code) async {
    final p = profiles[normalizeCode(code)];
    return p != null && p.verified ? p : null;
  }

  @override
  Future<String?> requestLink(String code) async {
    final p = await byCode(code);
    if (p == null) return 'رابط الطبيب غير متاح.';
    final m = links.membershipOf(Role.owner);
    if (m == null) return 'أنشئ بيتك أولاً.';
    final inv = links.inviteFor(Role.doctor) ?? await links.createInvite(Role.doctor);
    (reqs[p.code] ??= []).add(LinkRequest('r${reqs[p.code]?.length ?? 0}', uid, userName, m.householdId, inv.code));
    return null;
  }

  @override
  Future<List<LinkRequest>> requests() async => List.of(reqs[_myCode] ?? const []);

  @override
  Future<String?> accept(LinkRequest r) async {
    final err = await links.redeem(r.inviteCode, Role.doctor, who: userName);
    if (err == null) reqs[_myCode]?.removeWhere((x) => x.id == r.id);
    return err;
  }

  @override
  Future<void> decline(LinkRequest r) async => reqs[_myCode]?.removeWhere((x) => x.id == r.id);

  @override
  Future<PitchLink?> pitch(String token) async => pitches[token];

  final registered = <String>[];
  @override
  Future<void> markRegistered(String token) async => registered.add(token);
}
