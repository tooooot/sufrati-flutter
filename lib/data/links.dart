// الربط بين صاحب الخطة والطاهي والطبيب: كل ارتباط يتم برمز دعوة يصدره من يملك البيت ويدخله الطرف الآخر.
// LinkService واجهة؛ FirestoreLinkService هو التنفيذ الحقيقي، وMemoryLinkService للاختبارات.
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../auth/roles.dart';

class Membership {
  final String householdId, householdLabel, programId;
  final Role role;
  const Membership(this.householdId, this.householdLabel, this.programId, this.role);
}

class Invite {
  final String code;
  final Role role; // الدور الذي سيحصل عليه من يدخل الرمز
  final DateTime expires;
  final String? hid;
  String? usedBy; // اسم من انضم
  Invite(this.code, this.role, this.expires, {this.hid, this.usedBy});
  bool get used => usedBy != null;
}

abstract class LinkService extends ChangeNotifier {
  /// false حتى تُحمَّل ارتباطات المستخدم أول مرة (لا نسأله عن دوره قبل أن نعرف إن كان له بيت).
  bool get ready;
  List<Membership> get memberships;

  Membership? membershipOf(Role r) => memberships.where((m) => m.role == r).firstOrNull;

  /// الدور المقترح لمن عنده ارتباطات: صاحب بيت، ثم طبيب، ثم طاهٍ.
  Role? get suggestedRole {
    for (final r in const [Role.owner, Role.doctor, Role.cook]) {
      if (membershipOf(r) != null) return r;
    }
    return null;
  }

  // بيت صاحب الخطة الحالي
  bool get hasHousehold => membershipOf(Role.owner) != null;
  String get label => membershipOf(Role.owner)?.householdLabel ?? '';
  String get programId => membershipOf(Role.owner)?.programId ?? '';

  Invite? inviteFor(Role r);
  Invite? joinedBy(Role r);

  Future<void> createHousehold(String label, String programId, int eaters);
  /// [householdId] اختياري: افتراضياً بيت صاحب الخطة الحالي (والطبيب يمرّر بيت مريضه).
  Future<Invite> createInvite(Role role, {String? householdId});

  /// الطبيب لا يُفعَّل بالاختيار الذاتي: يُرسَل طلب لمدير سفرتي.
  bool get isDoctor;
  bool get doctorRequested;
  Future<void> requestDoctor();

  /// يدخل الطاهي/الطبيب رمزاً. يرجع نص الخطأ أو null عند النجاح.
  Future<String?> redeem(String raw, Role asRole, {String who = 'مستخدم'});

  /// حذف كل بيانات المستخدم (بيوته وخططه ودعواته وخروجه من بيوت الآخرين) — شرط المتاجر.
  Future<void> deleteMyData();
}

/// تنفيذ في الذاكرة: للاختبارات فقط.
class MemoryLinkService extends LinkService {
  String? _label, _programId;
  final _invites = <String, Invite>{};
  final _joined = <Membership>[];
  final _rnd = Random.secure();
  final DateTime Function() _now;
  MemoryLinkService({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  @override
  bool get ready => true;

  @override
  List<Membership> get memberships => [
        if (_label != null) Membership('mem-1', _label!, _programId!, Role.owner),
        ..._joined,
      ];

  List<Invite> get invites => _invites.values.toList().reversed.toList();

  @override
  Invite? inviteFor(Role r) => invites.where((i) => i.role == r && !i.used).firstOrNull;
  @override
  Invite? joinedBy(Role r) => invites.where((i) => i.role == r && i.used).firstOrNull;

  @override
  Future<void> createHousehold(String label, String programId, int eaters) async {
    _label = label.trim();
    _programId = programId;
    notifyListeners();
  }

  bool _doctorRequested = false;
  @override
  bool get isDoctor => false;
  @override
  bool get doctorRequested => _doctorRequested;
  @override
  Future<void> requestDoctor() async {
    _doctorRequested = true;
    notifyListeners();
  }

  @override
  Future<Invite> createInvite(Role role, {String? householdId}) async {
    final inv = Invite(newInviteCode(_rnd), role, _now().add(const Duration(days: 7)));
    _invites[inv.code] = inv;
    notifyListeners();
    return inv;
  }

  @override
  Future<String?> redeem(String raw, Role asRole, {String who = 'مستخدم'}) async {
    final inv = _invites[normalizeCode(raw)];
    final err = checkInvite(inv, asRole, _now());
    if (err != null) return err;
    inv!.usedBy = who;
    _joined.add(Membership('mem-j', _label ?? 'بيت', _programId ?? '', asRole));
    notifyListeners();
    return null;
  }

  @override
  Future<void> deleteMyData() async {
    _label = _programId = null;
    _invites.clear();
    _joined.clear();
    notifyListeners();
  }
}

/// رمز من 8 خانات بلا حروف ملتبسة (32^8 ≈ 1.1 تريليون: تخمينه غير عملي). تبقى الرموز القديمة بـ6 خانات صالحة.
const inviteCodeLength = 8;

String newInviteCode(Random rnd) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return List.generate(inviteCodeLength, (_) => chars[rnd.nextInt(chars.length)]).join();
}

String normalizeCode(String raw) => raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// يتحقق من صلاحية دعوة لمن سيدخلها بدور معيّن. يرجع نص الخطأ أو null.
String? checkInvite(Invite? inv, Role asRole, DateTime now) {
  if (inv == null) return 'الرمز غير صحيح. تأكد منه مع صاحب الخطة.';
  if (inv.used) return 'هذا الرمز استُخدم من قبل.';
  if (inv.expires.isBefore(now)) return 'انتهت صلاحية الرمز. اطلب رمزاً جديداً.';
  if (inv.role != asRole) {
    return 'هذا الرمز مخصّص لـ«${roleName(inv.role)}» وليس لدورك.';
  }
  return null;
}

String roleName(Role r) => switch (r) {
      Role.owner => 'صاحب الخطة',
      Role.cook => 'الطاهي',
      Role.doctor => 'الطبيب',
      Role.admin => 'مدير سفرتي',
    };
