# خطوات تجهيز Firebase لسفرتي (تنفّذها أنت، نحو 20 دقيقة)

اسم الحزمة في Android وiOS: `net.wardyat.sufrati`

## 1) إنشاء المشروع
1. افتح https://console.firebase.google.com بحساب Google الخاص بك ← **Create a project** (أو Add project).
2. الاسم: `sufrati`. أطفئ Google Analytics (غير لازم).

## 2) إضافة التطبيقين
3. من الصفحة الرئيسية للمشروع اضغط أيقونة Android ← Package name: `net.wardyat.sufrati` ← Register app. نزّل `google-services.json` وأرسله لي.
4. اضغط **Add app** ← iOS ← Bundle ID: `net.wardyat.sufrati` ← Register. نزّل `GoogleService-Info.plist` وأرسله لي.
   (يكفي التسجيل، تجاهل خطوات الكود في المعالج.)

## 3) تفعيل الدخول
5. من القائمة اليسرى: **Build ← Authentication ← Get started ← Sign-in method**.
6. فعّل **Google** (اختر إيميل الدعم، Save).
7. فعّل **Apple** (Enable ثم Save). سأطلب منك لاحقاً مفتاح Sign in with Apple من حساب Apple Developer وسأرشدك لموضعه.

## 4) قاعدة البيانات والملفات
8. **Build ← Firestore Database ← Create database** ← الوضع **Production** ← المنطقة: `europe-west1` أو أقرب منطقة متاحة لك (لا تتغير بعدها).
9. **لا تُنشئ Storage** (قرار 2026-10-09): الملفات والصور تُخزَّن على سيرفرنا، وبهذا لا نحتاج خطة Blaze.

## 5) الخطة
ابقَ على الخطة المجانية **Spark**. لا ترقية ولا بطاقة دفع. (إن تجاوز الاستخدام الحصة المجانية يتوقف الوصول لباقي اليوم دون أي رسوم.)

## 6) حساب الخدمة (ليتصل به السيرفر)
12. **Project settings (الترس) ← Service accounts ← Generate new private key**. يُنزَّل ملف JSON.
13. أرسل لي الملفات الثلاثة: `google-services.json` و`GoogleService-Info.plist` وملف الخدمة JSON.

## تنبيهات أمان
- ملف الخدمة JSON يعطي صلاحية كاملة على المشروع. أرسله لي مباشرة ولا تنشره في مكان عام.
- لا تفعّل أي مزوّد دخول غير Google وApple.
