import 'package:flutter/material.dart';

import 'pitch_visuals.dart';

/// لقطة في عرض حركي: عنوان وشرح ورسم متحرك يأخذ تقدّمه من 0 إلى 1.
class PitchBeat {
  final String title, sub;
  final Widget Function(double t) visual;
  const PitchBeat(this.title, this.sub, this.visual);
}

/// لقطات كل عرض بحسب النوع: user (مدير البيت) · home (ربّة بيت تطبخ) · doctor (طبيب/أخصائي/صاحب جروب — دور واحد، وgroup اسم قديم له) · cook (الطاهي).
/// [name] اختياري: اسم الطبيب يظهر في بطاقة بروفايله.
List<PitchBeat> beatsFor(String kind, {String name = '', String lang = 'ar'}) => switch (kind) {
      'cook' => cookBeats(lang),
      // طبيب/أخصائي/صاحب جروب دورٌ واحد: يجمع جمهوره (غالباً خارج الدوام) ويتابع من ينضمّ إليه
      'doctor' || 'group' => [
          PitchBeat('ملفك المهني في سفرتي', 'اسمك وتخصصك ومدينتك، وشارة «معتمد» بعد أن تراجع الإدارة بياناتك ورقم ترخيصك.', (t) => DoctorProfileVisual(t, name: name)),
          PitchBeat('تجمع جمهورك خارج الدوام؟ رابط واحد يكفي', 'بدل إرسال جدول الوجبات صورة في الجروب، أرسل رابطك فيرتّب لكل عضو خطته.', (t) => GroupChatVisual(t)),
          PitchBeat('أعضاؤك ينضمّون بنقرة', 'من يفتح رابطك يشاهد عرضًا قصيرًا، ثم يسجّل بنقرة ويختار نظامه.', (t) => MembersJoinVisual(t)),
          PitchBeat('تتابع من يوافق', 'كل مريض يرسل لك طلب ربط، وبقبولك ترى خطته ووجباته.', (t) => PatientsVisual(t)),
          PitchBeat('تعدّل وتتابع', 'غيّر وجبة أو نظامًا بنقرة، ويصل التغيير لمريضك وطاهيه. الخدمة مجانية الآن.', (t) => EditPlanVisual(t)),
        ],
      // ربّة البيت التي تطبخ: ألمها الحقيقي «وش أطبخ؟» + النسيان + المشتريات + التكرار
      'home' => [
          PitchBeat('وش نطبخ اليوم؟ انتهت الحيرة', 'كل يوم أمامك وجبات الفطور والغداء وجلسة المغرب والعشاء، من أطباقنا الشعبية: كبسة، مقلوبة، مندي، جريش…', (t) => MealsVisual(t)),
          PitchBeat('تذكيرك قبل أن تنسي', 'أخرجي الدجاج من الفريزر، انقعي الأرز، ابدئي الطبخ: تنبيه في وقته بلا أن تضبطي منبهًا.', (t) => CookVisual(t)),
          PitchBeat('مشتريات جاهزة للزوج أو السائق', 'قائمة مصنّفة بأقسام السوق بكميات أسرتك، يعلّم فيها «اشتريتُ» من رابط بلا تطبيق.', (t) => ShoppingVisual(t)),
          PitchBeat('تنويع بلا تكرار، وحصة تناسب أسرتك', 'تتجنب ما قُدّم الأسبوع الماضي، وتخفين ما لا يحبه أولادك، وتختارين حجم الحصة.', (t) => HouseVisual(t)),
        ],
      // عروض لكل هدف: ألم ← حل ← راحة (ثلاث لقطات)، تنتهي بالرحلة مباشرة
      'weight' => [
          PitchBeat('جرّبت حميات وتوقفت؟', 'لا تعرف كم تأكل ولا ماذا؟ هذا ما يوقف أغلب الناس.', (t) => MealsVisual(t)),
          PitchBeat('سعراتك محسوبة من جسمك', 'من طولك ووزنك وهدفك، ووجبات بحصص مضبوطة وقائمة مشتريات.', (t) => ShoppingVisual(t)),
          PitchBeat('خطتك جاهزة في دقيقة', 'اضغط بضعة أزرار فقط، بلا كتابة.', (t) => EditPlanVisual(t)),
        ],
      'muscle' => [
          PitchBeat('تحسب البروتين بيدك؟', 'وتمل نفس العلبة كل يوم؟', (t) => MealsVisual(t)),
          PitchBeat('سعرات وبروتين لهدفك', 'بناء عضل أو تنشيف، بوجبات متنوعة تناسب تمرينك.', (t) => ShoppingVisual(t)),
          PitchBeat('ابدأ بدقيقة', 'أجب بالأزرار وتصلك خطتك.', (t) => EditPlanVisual(t)),
        ],
      'medical' => [
          PitchBeat('ورقة الحمية صعبة الفهم؟', 'تخاف أن تخطئ في طعامك؟', (t) => MealsVisual(t)),
          PitchBeat('وجبات خفيفة وبسيطة', 'النظام الخفيف يرتّب أسبوعك بوجبات معتدلة. لا يغني عن طبيبك.', (t) => PatientsVisual(t)),
          PitchBeat('اعرضه على طبيبك', 'ابدأ بدقيقة وشاركه معه برابط.', (t) => LinkShareVisual(t)),
        ],
      'withcook' => [
          PitchBeat('طاهيك يسألك كل يوم؟', 'وينسى فك اللحم ولا يفهم العربية؟', (t) => CookVisual(t)),
          PitchBeat('جدول يومه بلغته مع تنبيه', 'تنبيه قبل الموعد، وزر «حُضّرت» يطمئنك.', (t) => NotifyVisual(t, lang: 'ar')),
          PitchBeat('ادعُه برابط واحد', 'عبر واتساب، وكلٌّ يرى ما يخصه فقط.', (t) => LinkShareVisual(t)),
        ],
      _ => [
          PitchBeat('وجباتك كلها في مكان واحد', 'اختر نظامك الغذائي فتصلك وجبات كل يوم بأوقاتها.', (t) => MealsVisual(t)),
          PitchBeat('قائمة مشتريات تُبنى وحدها', 'من وجبات الأسبوع إلى أصناف تشتريها، مع التكلفة التقديرية.', (t) => ShoppingVisual(t)),
          PitchBeat('الطاهي يعرف ماذا يطبخ ومتى', 'تنبيه قبل الموعد وزر «حُضّرت» يطمئنك أن الوجبة جاهزة.', (t) => CookVisual(t)),
        ],
    };

/// نصوص إطار العرض بكل لغة: تخطَّ · المس للتالي · زر الختام. والأمهرية/الإنجليزية من اليسار لليمين.
class PitchChrome {
  final String skip, tap, cta;
  final bool rtl;
  const PitchChrome(this.skip, this.tap, this.cta, this.rtl);
}

const pitchLangs = {
  'ar': 'العربية', 'en': 'English', 'am': 'አማርኛ', 'tl': 'Filipino', 'so': 'Soomaali', 'bn': 'বাংলা', 'hi': 'हिन्दी',
};

PitchChrome chromeFor(String lang) => switch (lang) {
      'en' => const PitchChrome('Skip', 'Tap to continue', 'Get started', false),
      'am' => const PitchChrome('ዝለል', 'ለቀጣዩ ማያ ገጹን ይንኩ', 'ጀምር', false),
      'tl' => const PitchChrome('Laktawan', 'I-tap para magpatuloy', 'Magsimula', false),
      'so' => const PitchChrome('Ka bood', 'Taabo si aad u sii socoto', 'Bilow', false),
      'bn' => const PitchChrome('এড়িয়ে যান', 'পরের ধাপে যেতে স্পর্শ করুন', 'শুরু করুন', false),
      'hi' => const PitchChrome('छोड़ें', 'आगे बढ़ने के लिए टैप करें', 'शुरू करें', false),
      _ => const PitchChrome('تخطَّ', 'المس الشاشة للتالي', 'ابدأ الآن', true),
    };

/// عرض الطاهي: كيف يستعمل التطبيق وكيف تصله التنبيهات، بلغته (ar/en/am/tl/so/bn/hi).
List<PitchBeat> cookBeats(String lang) {
  const t = {
    'ar': [
      ('تعرف ماذا تطبخ اليوم', 'وجبات اليوم بأوقاتها ومكوّناتها في مكان واحد.'),
      ('ينبّهك قبل كل وجبة', 'يصلك تنبيه بصوت واهتزاز قبل الموعد بـ45 دقيقة، وآخر عند الموعد.'),
      ('بلغتك', 'العربية أو English أو አማርኛ — الوجبات والتنبيهات والتعليمات بلغتك.'),
      ('اضغط «حُضّرت»', 'يعرف مدير البيت فورًا أن الوجبة جاهزة، بلا اتصال.'),
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
    'tl': [
      ('Alamin kung ano ang lulutuin ngayon', 'Ang mga pagkain ngayon, kasama ang oras at mga sangkap, ay nasa iisang lugar.'),
      ('May paalala bago ang bawat pagkain', 'May alert na may tunog at vibration 45 minuto bago, at isa pa sa oras ng pagkain.'),
      ('Sa wika mo', 'Piliin ang English o አማርኛ sa loob ng app — ang mga pagkain, alert at tagubilin ay sa napili mong wika.'),
      ('Pindutin ang “Naihanda na”', 'Agad malalaman ng may-ari na handa na ang pagkain — hindi na kailangang tumawag.'),
    ],
    'so': [
      ('Ogow maxaad kariso maanta', 'Cuntooyinka maanta iyo wakhtigooda iyo waxyaabaha lagu sameeyo hal meel ayay ku jiraan.'),
      ('Wuxuu ku xusuusinayaa cunto kasta ka hor', 'Waxaad heleysaa ogeysiis cod iyo gariir leh 45 daqiiqo ka hor, mid kalena marka cuntada la gaadho.'),
      ('Luuqaddaada', 'Dooro English ama አማርኛ gudaha app-ka — cuntooyinka, ogeysiisyada iyo tilmaamaha waxay ku soo muuqan doonaan luuqaddaas.'),
      ('Taabo “La diyaariyay”', 'Mulkiilaha guriga isla markiiba wuu ogaanayaa in cuntadu diyaar tahay — wicitaan looma baahna.'),
    ],
    'bn': [
      ('আজ কী রান্না করবেন জানুন', 'আজকের খাবার, সময় ও উপকরণসহ সবকিছু এক জায়গায়।'),
      ('প্রতি বেলার আগে মনে করিয়ে দেবে', '৪৫ মিনিট আগে শব্দ ও কম্পনসহ একটি সতর্কবার্তা পাবেন, আর খাবারের সময়েও একটি।'),
      ('আপনার ভাষায়', 'অ্যাপের ভেতরে English বা አማርኛ বেছে নিন — খাবার, সতর্কবার্তা ও নির্দেশনা সেই ভাষায় দেখাবে।'),
      ('«প্রস্তুত» চাপুন', 'বাড়ির মালিক সঙ্গে সঙ্গে জানতে পারবেন খাবার তৈরি — ফোন করতে হবে না।'),
    ],
    'hi': [
      ('जानिए आज क्या पकाना है', 'आज के भोजन, उनका समय और सामग्री — सब एक जगह।'),
      ('हर भोजन से पहले याद दिलाता है', '45 मिनट पहले आवाज़ और कंपन के साथ अलर्ट मिलेगा, और भोजन के समय पर एक और।'),
      ('आपकी भाषा में', 'ऐप के अंदर English या አማርኛ चुनें — भोजन, अलर्ट और निर्देश उसी भाषा में दिखेंगे।'),
      ('«तैयार है» दबाएँ', 'घर के मालिक को तुरंत पता चल जाता है कि भोजन तैयार है — फ़ोन करने की ज़रूरत नहीं।'),
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
