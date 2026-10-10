// قسم التسويق (لوحة المدير): المستهدفون، رسالة واتساب الجاهزة، الحد اليومي، وحالة كل مستهدف.
// القاعدة: لا إرسال تلقائي أبداً — الزر يفتح wa.me والمدير يضغط «إرسال» بنفسه. حدّ يومي صغير + تعريف بالنفس + جملة إلغاء.

const dailySendLimit = 15;

enum TargetKind { doctor, dietitian, groupOwner }

extension TargetKindX on TargetKind {
  String get id => switch (this) { TargetKind.doctor => 'doctor', TargetKind.dietitian => 'dietitian', TargetKind.groupOwner => 'group_owner' };
  String get label => switch (this) { TargetKind.doctor => 'طبيب', TargetKind.dietitian => 'أخصائي', TargetKind.groupOwner => 'صاحب جروب' };
  /// نوع العرض الحركي الذي يراه (يوافق beatsFor).
  String get pitchKind => this == TargetKind.groupOwner ? 'group' : 'doctor';
  static TargetKind parse(String? s) => TargetKind.values.firstWhere((k) => k.id == s, orElse: () => TargetKind.doctor);
}

/// حالات المستهدف بترتيب التقدّم؛ declined/skipped يضعهما المدير يدوياً.
enum TargetStatus { fresh, sent, opened, registered, declined, skipped }

extension TargetStatusX on TargetStatus {
  String get label => switch (this) {
        TargetStatus.fresh => 'جديد',
        TargetStatus.sent => 'أُرسل',
        TargetStatus.opened => 'فتح الرابط',
        TargetStatus.registered => 'سجّل',
        TargetStatus.declined => 'رفض',
        TargetStatus.skipped => 'مؤجَّل',
      };
}

/// الحالة المعروضة: المنتهية يدوياً (رفض/تأجيل) تغلب، ثم الأعلى تقدّماً من الأحداث الفعلية.
TargetStatus deriveStatus({required String manual, required bool sent, required bool opened, required bool registered}) {
  if (manual == 'declined') return TargetStatus.declined;
  if (manual == 'skipped') return TargetStatus.skipped;
  if (registered) return TargetStatus.registered;
  if (opened) return TargetStatus.opened;
  if (sent) return TargetStatus.sent;
  return TargetStatus.fresh;
}

/// رقم دولي لـwa.me: 05xxxxxxxx ← 9665xxxxxxxx، 5xxxxxxxx ← 9665xxxxxxxx، 00… يُحذف الصفر المزدوج. null إن لم يصلح.
String? normalizePhone(String raw) {
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('00')) d = d.substring(2);
  if (d.startsWith('05') && d.length == 10) d = '966${d.substring(1)}';
  if (d.startsWith('5') && d.length == 9) d = '966$d';
  return d.length >= 11 && d.length <= 15 ? d : null;
}

/// رسالة الواتساب: تعريف بالنفس في أول سطر + الرابط باسمه + جملة إلغاء. المدير يعدّلها قبل الإرسال.
String buildMessage(TargetKind kind, String name, String link) {
  final hello = 'السلام عليكم ${kind == TargetKind.groupOwner ? 'أستاذ/ة' : ''} $name،'.replaceAll('  ', ' ');
  final intro = 'أنا من فريق تطبيق «سفرتي» لتنظيم الوجبات والأنظمة الغذائية للأسرة.';
  final pitch = kind == TargetKind.groupOwner
      ? 'جهّزنا لك عرضًا قصيرًا (نصف دقيقة) عن كيف تعرّف أعضاء جروبك بالتطبيق برابط واحد، بخطة أسبوعية وقائمة مشتريات لكل عضو:'
      : 'جهّزنا لك عرضًا قصيرًا (نصف دقيقة) عن كيف تنشر أنظمتك الغذائية لمتابعيك وتتابع مرضاك في التطبيق، مجانًا:';
  return '$hello\n$intro\n$pitch\n$link\n\nإن لم يناسبك اكتب «لا» ولن نراسلك مرة أخرى.';
}

/// رابط العرض الخارجي باسم الشخص.
String pitchLinkFor(String token) => 'https://maeda.wardyat.net/p/$token';

/// كم رسالة أُرسلت اليوم (بتوقيت الجهاز) من قائمة أوقات الإرسال.
int sentToday(Iterable<DateTime> sentAt, DateTime now) =>
    sentAt.where((t) => t.year == now.year && t.month == now.month && t.day == now.day).length;
