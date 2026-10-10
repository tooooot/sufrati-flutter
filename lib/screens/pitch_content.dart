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
List<PitchBeat> beatsFor(String kind, {String name = '', String lang = 'ar'}) => switch (kind) {
      'cook' => cookBeats(lang),
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

/// نصوص إطار العرض بكل لغة: تخطَّ · المس للتالي · زر الختام. والأمهرية/الإنجليزية من اليسار لليمين.
class PitchChrome {
  final String skip, tap, cta;
  final bool rtl;
  const PitchChrome(this.skip, this.tap, this.cta, this.rtl);
}

const pitchLangs = {'ar': 'العربية', 'en': 'English', 'am': 'አማርኛ'};

PitchChrome chromeFor(String lang) => switch (lang) {
      'en' => const PitchChrome('Skip', 'Tap to continue', 'Get started', false),
      'am' => const PitchChrome('ዝለል', 'ለቀጣዩ ማያ ገጹን ይንኩ', 'ጀምር', false),
      _ => const PitchChrome('تخطَّ', 'المس الشاشة للتالي', 'ابدأ الآن', true),
    };

/// عرض الطاهي: كيف يستعمل التطبيق وكيف تصله التنبيهات، بلغته (ar/en/am).
List<PitchBeat> cookBeats(String lang) {
  const t = {
    'ar': [
      ('تعرف ماذا تطبخ اليوم', 'وجبات اليوم بأوقاتها ومكوّناتها في مكان واحد.'),
      ('ينبّهك قبل كل وجبة', 'يصلك تنبيه بصوت واهتزاز قبل الموعد بـ45 دقيقة، وآخر عند الموعد.'),
      ('بلغتك', 'العربية أو English أو አማርኛ — الوجبات والتنبيهات والتعليمات بلغتك.'),
      ('اضغط «حُضّرت»', 'يعرف صاحب الخطة فورًا أن الوجبة جاهزة، بلا اتصال.'),
    ],
    'en': [
      ('Know what to cook today', "Today's meals with their times and ingredients, all in one place."),
      ('A reminder before every meal', 'You get an alert with sound and vibration 45 minutes before, and another at meal time.'),
      ('In your language', 'Arabic, English or Amharic — meals, alerts and instructions in the language you choose.'),
      ('Tap “Prepared”', 'The owner knows right away that the meal is ready — no phone call needed.'),
    ],
    'am': [
      ('ዛሬ ምን ማብሰል እንዳለብዎ ያውቃሉ', 'የዛሬው ምግቦች ከሰዓታቸውና ከሚያስፈልጉ ነገሮች ጋር በአንድ ቦታ ይታያሉ።'),
      ('ከእያንዳንዱ ምግብ በፊት ያስታውስዎታል', 'ከ45 ደቂቃ በፊት በድምፅና በንዝረት ማሳወቂያ ይደርስዎታል፤ በምግቡ ሰዓትም ሌላ ይደርስዎታል።'),
      ('በቋንቋዎ', 'አማርኛ፣ እንግሊዝኛ ወይም አረብኛ — ምግቦች፣ ማሳወቂያዎችና መመሪያዎች በመረጡት ቋንቋ ይታያሉ።'),
      ('«ተዘጋጅቷል» ይጫኑ', 'ባለቤቱ ምግቡ እንደተዘጋጀ ወዲያው ያውቃል፤ መደወል አያስፈልግም።'),
    ],
  };
  final l = t.containsKey(lang) ? lang : 'ar';
  final x = t[l]!;
  return [
    PitchBeat(x[0].$1, x[0].$2, (v) => CookTodayVisual(v, lang: l)),
    PitchBeat(x[1].$1, x[1].$2, (v) => NotifyVisual(v, lang: l)),
    PitchBeat(x[2].$1, x[2].$2, (v) => LanguageVisual(v)),
    PitchBeat(x[3].$1, x[3].$2, (v) => CookDoneVisual(v, lang: l)),
  ];
}
