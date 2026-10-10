import 'package:flutter/material.dart';

import 'pitch_visuals.dart';

/// لقطة في عرض حركي: عنوان وشرح ورسم متحرك يأخذ تقدّمه من 0 إلى 1.
class PitchBeat {
  final String title, sub;
  final Widget Function(double t) visual;
  const PitchBeat(this.title, this.sub, this.visual);
}

/// لقطات كل عرض بحسب النوع: user (صاحب الخطة) · doctor (طبيب/أخصائي) · group (صاحب جروب).
/// [name] اختياري: اسم الطبيب يظهر في بطاقة بروفايله.
List<PitchBeat> beatsFor(String kind, {String name = ''}) => switch (kind) {
      'doctor' => [
          PitchBeat('ملفك المهني في سفرتي', 'اسمك وتخصصك ومدينتك، وشارة «موثَّق» بعد أن تعتمد الإدارة حسابك.', (t) => DoctorProfileVisual(t, name: name)),
          PitchBeat('رابط واحد لمتابعيك', 'انشره في جروباتك وحساباتك. من يفتحه يشاهد عرضًا قصيرًا ثم يسجّل ويبدأ.', (t) => LinkShareVisual(t)),
          PitchBeat('مرضاك في مكان واحد', 'كل مريض يوافق على ربطك به، فترى خطته ووجباته بموافقته.', (t) => PatientsVisual(t)),
          PitchBeat('تعدّل وتتابع', 'غيّر وجبة أو نظامًا بنقرة، ويصل التغيير لمريضك وطاهيه. مجانًا في هذه المرحلة.', (t) => EditPlanVisual(t)),
        ],
      'group' => [
          PitchBeat('جروبك يستحق أكثر من صورة', 'بدل إرسال جدول الوجبات صورة في كل مرة، أرسل رابطًا يفتح تطبيقًا يرتّب كل شيء.', (t) => GroupChatVisual(t)),
          PitchBeat('الرابط يعمل لكل عضو', 'يفتح عرضًا قصيرًا، ثم يسجّل بنقرة واحدة ويختار نظامه.', (t) => MembersJoinVisual(t)),
          PitchBeat('لكل عضو وجباته ومشترياته', 'خطة أسبوعية وقائمة مشتريات مصنّفة، بحسب نظامه الغذائي.', (t) => MealsVisual(t)),
          PitchBeat('وطبيبك أو أخصائيك يتابعهم', 'يربط العضو نفسه بطبيبه بموافقته، فتكتمل الدائرة: طبيب وبيت وطاهٍ.', (t) => HouseVisual(t)),
        ],
      _ => [
          PitchBeat('وجباتك كلها في مكان واحد', 'اختر نظامك الغذائي فتصلك وجبات كل يوم بأوقاتها.', (t) => MealsVisual(t)),
          PitchBeat('قائمة مشتريات تُبنى وحدها', 'من وجبات الأسبوع إلى أصناف تشتريها، مع التكلفة التقديرية.', (t) => ShoppingVisual(t)),
          PitchBeat('الطاهي يعرف ماذا يطبخ ومتى', 'تنبيه قبل الموعد وزر «حُضّرت» يطمئنك أن الوجبة جاهزة.', (t) => CookVisual(t)),
          PitchBeat('بيتك وطبيبك على خطة واحدة', 'ادعُ الطاهي والطبيب برابط واتساب، وكلٌّ يرى ما يخصه فقط.', (t) => HouseVisual(t)),
        ],
    };
