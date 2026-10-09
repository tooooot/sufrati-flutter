// الربط بين صاحب البيت والطاهي والطبيب: كل ارتباط يتم برمز دعوة يصدره من يملك البيت ويدخله الطرف الآخر.
// هذه نسخة في الذاكرة تُجرَّب في المعاينة؛ تُستبدل في المرحلة 2 بـFirestore (invites + households.members) بنفس الواجهة.
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../auth/roles.dart';

class Membership {
  final String householdLabel, programId;
  final Role role;
  const Membership(this.householdLabel, this.programId, this.role);
}

class Invite {
  final String code;
  final Role role; // الدور الذي سيحصل عليه من يدخل الرمز
  final DateTime expires;
  String? usedBy; // اسم من انضم
  Invite(this.code, this.role, this.expires);
  bool get used => usedBy != null;
}

class LinkService extends ChangeNotifier {
  String? _label, _programId;
  int eaters = 1;
  final _invites = <String, Invite>{};
  final _joined = <Membership>[]; // ارتباطات هذا الحساب كطاهٍ/طبيب في بيوت الآخرين
  final _rnd = Random.secure();
  final DateTime Function() _now;
  LinkService({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  bool get hasHousehold => _label != null;
  String get label => _label ?? '';
  String get programId => _programId ?? '';
  List<Invite> get invites => _invites.values.toList().reversed.toList();
  List<Membership> get memberships => [
        if (_label != null) Membership(_label!, _programId!, Role.owner),
        ..._joined,
      ];

  Invite? inviteFor(Role r) => invites.where((i) => i.role == r && !i.used).firstOrNull;
  Invite? joinedBy(Role r) => invites.where((i) => i.role == r && i.used).firstOrNull;

  void createHousehold(String label, String programId, int eaters) {
    _label = label.trim();
    _programId = programId;
    this.eaters = eaters;
    notifyListeners();
  }

  /// يصدر رمزاً (6 خانات بلا حروف ملتبسة) صالحاً 7 أيام للدور المطلوب.
  Invite createInvite(Role role) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = List.generate(6, (_) => chars[_rnd.nextInt(chars.length)]).join();
    final inv = Invite(code, role, _now().add(const Duration(days: 7)));
    _invites[code] = inv;
    notifyListeners();
    return inv;
  }

  /// يدخل الطاهي/الطبيب رمزاً. يرجع نص الخطأ أو null عند النجاح.
  String? redeem(String raw, Role asRole, {String who = 'مستخدم'}) {
    final code = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final inv = _invites[code];
    if (inv == null) return 'الرمز غير صحيح. تأكد منه مع صاحب البيت.';
    if (inv.used) return 'هذا الرمز استُخدم من قبل.';
    if (inv.expires.isBefore(_now())) return 'انتهت صلاحية الرمز. اطلب رمزاً جديداً.';
    if (inv.role != asRole) {
      return 'هذا الرمز مخصّص لـ«${inv.role == Role.cook ? 'الطاهي' : inv.role == Role.doctor ? 'الطبيب' : 'صاحب البيت'}» وليس لدورك.';
    }
    inv.usedBy = who;
    _joined.add(Membership(_label ?? 'بيت', _programId ?? '', asRole));
    notifyListeners();
    return null;
  }

  void leaveAll() {
    _label = _programId = null;
    _invites.clear();
    _joined.clear();
    notifyListeners();
  }
}

String roleName(Role r) => switch (r) {
      Role.owner => 'صاحب البيت',
      Role.cook => 'الطاهي',
      Role.doctor => 'الطبيب',
      Role.admin => 'مدير سفرتي',
    };
