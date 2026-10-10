import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_service.dart';
import 'auth/firebase_auth_service.dart';
import 'auth/session.dart';
import 'auth/roles.dart';
import 'data/firestore_links.dart';
import 'data/growth.dart';
import 'data/links.dart';
import 'screens/admin_screen.dart';
import 'screens/doctor_join_screen.dart';
import 'screens/doctor_pending_screen.dart';
import 'screens/doctor_profile_screen.dart';
import 'screens/doctor_public_screen.dart';
import 'screens/pitch_screen.dart';
import 'screens/house_create_screen.dart';
import 'screens/household_screen.dart';
import 'screens/invite_join_screen.dart';
import 'screens/join_screen.dart';
import 'screens/new_house_screen.dart';
import 'screens/profile_screen.dart';

import 'firebase_options.dart';
import 'data/i18n.dart';
import 'data/repository.dart';
import 'routing.dart';
import 'screens/coming_next_screen.dart';
import 'screens/cook_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/patient_screen.dart';
import 'screens/program_preview_screen.dart';
import 'screens/role_screen.dart';
import 'screens/start_screen.dart';
import 'theme.dart';
import 'widgets/store_loader.dart';

Future<void> main() async {
  usePathUrlStrategy(); // روابط نظيفة على الويب (/programs/keto_general) بدل #/
  WidgetsFlutterBinding.ensureInitialized();
  // تحميل البيانات وتهيئة Firebase معاً (لا تتتابعان) لتقصير الوقت حتى أول شاشة.
  final libraryF = Library.load();
  final i18nF = CookI18n.load();
  // Firebase حقيقي على الجوال والويب. على الويب: لا Crashlytics ولا App Check ولا إشعارات محلية ولا دخول Apple.
  await Firebase.initializeApp(options: SufratiFirebase.current);
  final library = await libraryF;
  final i18n = await i18nF;
  if (!kIsWeb) {
    // App Check: يثبت أن الطلبات من تطبيقنا الحقيقي (Play Integrity / App Attest) لا من سكربت بمفتاحنا.
    // الإنفاذ على Firestore معطّل عمداً حتى نتأكد من الأجهزة؛ وفشل التفعيل لا يوقف التطبيق.
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
        providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    } catch (_) {}
    // Crashlytics: أعطال الجوال الحقيقية (بلا بيانات شخصية: لا نضبط معرّف مستخدم).
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  final AuthService auth = FirebaseAuthService();
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final LinkService links = FirestoreLinkService(db, auth);
  // نستعيد الجلسة المحفوظة قبل رسم أي شاشة: لا وميض لشاشة الدخول، ولا تضيع الروابط العميقة.
  await auth.initialized.timeout(const Duration(seconds: 6), onTimeout: () {});
  final GrowthService growth = FirestoreGrowthService(db, auth, links);
  runApp(SufratiApp(library: library, i18n: i18n, auth: auth, links: links, db: db, growth: growth));
}

class SufratiApp extends StatelessWidget {
  final Library library;
  final CookI18n i18n;
  final AuthService auth;
  final LinkService links;
  final FirebaseFirestore? db;
  final GrowthService growth;
  SufratiApp({super.key, required this.library, required this.i18n, required this.auth, required this.links, required this.db, required this.growth});

  // الجلسة: الدخول أولاً (Google/Apple) ثم الدور المستنتج من الارتباطات. التصفح يبقى متاحاً بلا حساب.
  late final _session = Session(auth, links);

  late final _router = GoRouter(
    refreshListenable: _session,
    redirect: (_, state) => appRedirect(_session, state.matchedLocation,
        full: state.uri.toString(), next: state.uri.queryParameters['next'], landingForGuests: true),
    routes: [
      GoRoute(path: '/loading', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/role', builder: (_, _) => RoleScreen(session: _session)),
      GoRoute(path: '/doctor-pending', builder: (_, _) => DoctorPendingScreen(session: _session)),
      GoRoute(path: '/admin', builder: (_, _) => AdminScreen(db: db)),
      GoRoute(path: '/browse', builder: (_, _) => StartScreen(library: library)),
      GoRoute(path: '/intro', builder: (_, _) => IntroScreen()),
      GoRoute(path: '/new-house',
          builder: (_, st) => NewHouseScreen(library: library, links: links, session: _session, growth: growth, doctorCode: st.uri.queryParameters['dr'])),
      GoRoute(path: '/p/:token', builder: (_, st) => PitchScreen(growth: growth, token: st.pathParameters['token'])),
      GoRoute(path: '/pitch/:kind', builder: (_, st) => PitchScreen(growth: growth, kind: st.pathParameters['kind'])),
      GoRoute(path: '/dr/:code', builder: (_, st) => DoctorPublicScreen(growth: growth, code: st.pathParameters['code']!)),
      GoRoute(path: '/dr/:code/join',
          builder: (_, st) => DoctorJoinScreen(session: _session, growth: growth, code: st.pathParameters['code']!)),
      GoRoute(path: '/doctor/profile', builder: (_, _) => DoctorProfileScreen(growth: growth, links: links)),
      GoRoute(path: '/household', builder: (_, _) => HouseholdScreen(links: links, library: library)),
      GoRoute(path: '/profile', builder: (_, _) => ProfileScreen(session: _session, links: links)),
      GoRoute(path: '/i/:code',
          builder: (_, st) => InviteJoinScreen(session: _session, links: links, code: st.pathParameters['code']!)),
      GoRoute(path: '/join/:role',
          builder: (_, st) => JoinScreen(links: links, session: _session,
              role: st.pathParameters['role'] == 'doctor' ? Role.doctor : Role.cook)),
      GoRoute(path: '/login', builder: (_, s) => LoginScreen(auth: auth, next: s.uri.queryParameters['next'] ?? '/')),
      GoRoute(path: '/', builder: (_, _) => kIsWeb ? LandingScreen(library: library) : IntroScreen()),
      GoRoute(path: '/programs/:id',
          builder: (_, s) => ProgramPreviewScreen(library: library, programId: s.pathParameters['id']!)),
      GoRoute(path: '/me',
          builder: (_, _) => StoreLoader(
                db: db, links: links, library: library,
                role: _session.role == Role.doctor ? Role.doctor : Role.owner,
                builder: (store) => PatientScreen(store: store, library: library, links: links,
                    userName: _session.user?.name ?? '', showHome: _session.role != Role.doctor),
              )),
      GoRoute(path: '/cook',
          builder: (_, _) => StoreLoader(
                db: db, links: links, library: library, role: Role.cook,
                builder: (store) => CookScreen(store: store, library: library, i18n: i18n),
              )),
      GoRoute(path: '/signup/custom', builder: (_, _) => const ComingNextScreen(title: 'نظامك الخاص')),
      GoRoute(path: '/signup/:id',
          builder: (_, s) => HouseCreateScreen(library: library, links: links, programId: s.pathParameters['id']!)),
    ],
  );

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'سفرتي',
        debugShowCheckedModeBanner: false,
        theme: sufratiTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: _router,
      );
}
