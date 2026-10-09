# إجابات نماذج المتجرين (سفرتي Flutter 2.0) — للنسخ واللصق

> نماذج الكونسول لا تُعبَّأ بالـAPI. راجع كل إجابة قبل الإرسال؛ صُمّمت لتطابق ما يفعله التطبيق فعلاً (2026-10-09).
> البيانات: اسم وبريد من Google/Apple · بيانات البيت والخطة والمشتريات (غذائية/صحية) · معرّف مستخدم Firebase · تقارير أعطال (Crashlytics، بلا هوية) · لا إعلانات ولا تتبّع ولا بيع.

## 1) Apple — App Store Connect ← App Privacy
هل تجمع بيانات؟ **نعم**. التتبع (Tracking): **لا** (لا ربط بين تطبيقات ولا إعلانات).

| نوع البيانات | الاستخدام | مرتبطة بالهوية؟ | تتبّع؟ |
|---|---|---|---|
| Contact Info ← **Name** | App Functionality | نعم | لا |
| Contact Info ← **Email Address** | App Functionality | نعم | لا |
| Health & Fitness ← **Health** (النظام الغذائي والخطة) | App Functionality | نعم | لا |
| Identifiers ← **User ID** (Firebase UID) | App Functionality | نعم | لا |
| Diagnostics ← **Crash Data** | App Functionality (إصلاح الأعطال) | **لا** | لا |
| Diagnostics ← **Other Diagnostic Data** | App Functionality | **لا** | لا |

- Privacy Policy URL: `https://maeda.wardyat.net/privacy`
- Age rating: 4+ (لا محتوى حسّاس) — تأكد من إجابة «Medical/Treatment Information»: **No** (التطبيق لا يقدّم علاجاً).
- Sign-in required: **Yes** → Username `reviewer@wardyat.net` وكلمة السر من `/root/env/reviewer_credentials.txt`.
- Notes (الصق النص الإنجليزي من دستور-سفرتي.md قسم «حساب مراجعة المتاجر»).
- Account deletion: يوجد داخل التطبيق (الملف الشخصي ← حذف حسابي وبياناتي).

## 2) Google Play — Play Console ← App content
### Data safety
هل يجمع التطبيق أو يشارك بيانات مستخدم؟ **نعم**. البيانات مشفّرة أثناء النقل: **نعم**. يمكن للمستخدم طلب حذف بياناته: **نعم** — رابط الحذف: `https://maeda.wardyat.net/delete-account`.

| الفئة ← النوع | تُجمع | تُشارك | الغرض | إلزامية؟ |
|---|---|---|---|---|
| Personal info ← Name | نعم | **لا** | App functionality, Account management | نعم |
| Personal info ← Email address | نعم | **لا** | App functionality, Account management | نعم |
| Health and fitness ← Health info (خطة غذائية) | نعم | **لا** | App functionality | نعم |
| App activity / User-generated: (لا) | لا | — | — | — |
| App info and performance ← Crash logs | نعم | **لا** | Analytics (diagnostics) | لا |
| App info and performance ← Diagnostics | نعم | **لا** | Analytics (diagnostics) | لا |
| Device or other IDs ← (Firebase installation ID) | نعم | **لا** | App functionality | نعم |

«المشاركة»: Google Firebase مزوّد خدمة (Service provider) يعالج البيانات نيابة عنا، فلا يُعدّ مشاركة.

### Health apps
أُجب: التطبيق **تطبيق صحة/لياقة (تغذية)**؛ لا يقدّم تشخيصاً؛ لا يتصل بـHealth Connect. أرفق الإخلاء الطبي (موجود في الشاشات).

### App access
قيود الوصول: **نعم، يتطلب تسجيل الدخول** ← أضف تعليمات الدخول والبريد وكلمة السر نفسها.

### Declarations للأذونات
- **USE_FULL_SCREEN_INTENT:** الغرض: «تنبيه منبّه لموعد تحضير الوجبة يظهر فوق شاشة القفل للطاهي (مثل منبّه الساعة)». ⚠️ Google تحصره في المنبهات والمكالمات؛ قد يُرفض. البديل: إزالة الإذن والاكتفاء بنافذة علوية.
- **SCHEDULE_EXACT_ALARM:** الغرض: «تذكير بموعد الوجبة في وقت محدد». ⚠️ التطبيق يعمل بدونه بدقة أقل.
- **POST_NOTIFICATIONS:** إشعارات التذكير.
