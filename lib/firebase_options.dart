// إعدادات Firebase لمشروع sufrati-8555a — مأخوذة من google-services.json وGoogleService-Info.plist (ليست أسراراً).
// الويب غير مسجَّل في Firebase: الويب بلا دخول (WebAuthService) ولا يحمّل Firebase.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class SufratiFirebase {
  /// عميل الويب (client_type 3) — يلزم google_sign_in لاستخراج idToken ليقبله Firebase.
  static const googleServerClientId = '316270990440-1ib2j1c8ntuakk3jt9c3kf571sipej89.apps.googleusercontent.com';

  static FirebaseOptions get current {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Firebase غير مفعّل لهذه المنصة');
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyBb-AGnqglLk8r9pNJ1v6cxcw3WY1ogiJM',
    appId: '1:316270990440:android:c20f155059ca77f10417dd',
    messagingSenderId: '316270990440',
    projectId: 'sufrati-8555a',
    storageBucket: 'sufrati-8555a.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyC6iML1lC3tUzIaQnxU6wjoIQUQDx7i8bU',
    appId: '1:316270990440:ios:04264744474c3b8a0417dd',
    messagingSenderId: '316270990440',
    projectId: 'sufrati-8555a',
    storageBucket: 'sufrati-8555a.firebasestorage.app',
    iosBundleId: 'net.wardyat.sufrati',
    iosClientId: '316270990440-ka10806tdhrcqgfp9o93e5r464m77ftc.apps.googleusercontent.com',
  );
}
