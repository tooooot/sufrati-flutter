import 'package:flutter/foundation.dart';

/// ميزات الطبيب (تسجيل الطبيب وتعديله للسعرات) مخفية في iOS: Apple 5.1.1(ix) تشترط حساب مطوّر «منظمة» للتطبيقات التي تُعدّل فيها جهة مهنية بيانات صحية.
/// تبقى في Android والويب؛ تُفعَّل في iOS بتغيير هذا السطر بعد اعتماد حساب المنظمة.
bool get doctorFeaturesEnabled => kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;
