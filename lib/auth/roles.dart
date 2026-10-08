// الأدوار والصلاحيات — نسخة Dart من «جدول الصلاحيات» في FLUTTER_PLAN.md.
// الواجهة تستعملها لإخفاء/إظهار الأزرار فقط؛ المنع الفعلي في firebase/firestore.rules (يجب أن يتطابق الاثنان).

/// دور المستخدم داخل بيت معيّن. المدير (admin) دور على مستوى المنصة، لا يُخزَّن في members.
enum Role {
  admin,
  doctor,
  owner,
  cook;

  static Role? parse(String? s) => values.where((r) => r.name == s).firstOrNull;
}

enum Perm {
  viewPlan,
  editPlan,
  viewShopping,
  editShopping,
  markPrepared, // «جاهز» وتنبيهات الطبخ
  viewHealth, // النظام المخصّص وملاحظات الطبيب
  requestProgram, // طلب نظام مخصّص من المنصة
  uploadProgram, // رفع نظام مخصّص مباشرة
  deleteHousehold,
  viewPlatform,
}

const Map<Perm, Set<Role>> _matrix = {
  Perm.viewPlan: {Role.admin, Role.doctor, Role.owner, Role.cook},
  Perm.editPlan: {Role.admin, Role.doctor, Role.owner},
  Perm.viewShopping: {Role.admin, Role.doctor, Role.owner, Role.cook},
  Perm.editShopping: {Role.admin, Role.doctor, Role.owner},
  Perm.markPrepared: {Role.admin, Role.cook},
  Perm.viewHealth: {Role.admin, Role.doctor, Role.owner},
  Perm.requestProgram: {Role.admin, Role.doctor, Role.owner},
  Perm.uploadProgram: {Role.admin, Role.doctor},
  Perm.deleteHousehold: {Role.admin, Role.owner},
  Perm.viewPlatform: {Role.admin},
};

bool can(Role role, Perm perm) => _matrix[perm]!.contains(role);

/// من يستطيع دعوة من: المدير أيّاً كان، الصاحب ← طباخ/طبيب، الطبيب ← مريض (صاحب بيت)، الطباخ لا أحد.
bool canInvite(Role inviter, Role invitee) => switch (inviter) {
      Role.admin => invitee != Role.admin,
      Role.owner => invitee == Role.cook || invitee == Role.doctor,
      Role.doctor => invitee == Role.owner,
      Role.cook => false,
    };

/// الأدوار التي تُخزَّن في households/{id}.members (المدير ليس منها).
const memberRoles = {Role.owner, Role.cook, Role.doctor};
