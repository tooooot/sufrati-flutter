import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'data/links.dart';
import 'screens/admin_screen.dart';
import 'screens/doctor_pending_screen.dart';
import 'screens/house_create_screen.dart';
import 'screens/household_screen.dart';
import 'screens/join_screen.dart';
import 'screens/profile_screen.dart';

import 'firebase_options.dart';
import 'data/i18n.dart';
import 'data/repository.dart';
import 'routing.dart';
import 'screens/coming_next_screen.dart';
import 'screens/cook_screen.dart';
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
  final library = await Library.load();
  final i18n = await CookI18n.load();
  // الجوال: Firebase حقيقي. الويب: تصفح الأنظمة فقط بلا دخول.
  AuthService auth = WebAuthService();
  LinkService links = MemoryLinkService();
  FirebaseFirestore? db;
  if (!kIsWeb) {
    await Firebase.initializeApp(options: SufratiFirebase.current);
    auth = FirebaseAuthService();
    db = FirebaseFirestore.instance;
    links = FirestoreLinkService(db, auth);
  }
  runApp(SufratiApp(library: library, i18n: i18n, auth: auth, links: links, db: db));
}

class SufratiApp extends StatelessWidget {
  final Library library;
  final CookI18n i18n;
  final AuthService auth;
  final LinkService links;
  final FirebaseFirestore? db;
  SufratiApp({super.key, required this.library, required this.i18n, required this.auth, required this.links, required this.db});

  // الجلسة: الدخول أولاً (Google/Apple) ثم الدور المستنتج من الارتباطات. التصفح يبقى متاحاً بلا حساب.
  late final _session = Session(auth, links);

  late final _router = GoRouter(
    refreshListenable: _session,
    redirect: (_, state) => appRedirect(_session, state.matchedLocation),
    routes: [
      GoRoute(path: '/loading', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/role', builder: (_, _) => RoleScreen(session: _session)),
      GoRoute(path: '/doctor-pending', builder: (_, _) => DoctorPendingScreen(session: _session)),
      GoRoute(path: '/admin', builder: (_, _) => AdminScreen(db: db)),
      GoRoute(path: '/browse', builder: (_, _) => StartScreen(library: library)),
      GoRoute(path: '/household', builder: (_, _) => HouseholdScreen(links: links, library: library)),
      GoRoute(path: '/profile', builder: (_, _) => ProfileScreen(session: _session, links: links)),
      GoRoute(path: '/join/:role',
          builder: (_, st) => JoinScreen(links: links, session: _session,
              role: st.pathParameters['role'] == 'doctor' ? Role.doctor : Role.cook)),
      GoRoute(path: '/login', builder: (_, s) => LoginScreen(auth: auth, next: s.uri.queryParameters['next'] ?? '/')),
      GoRoute(path: '/', builder: (_, _) => StartScreen(library: library)),
      GoRoute(path: '/programs/:id',
          builder: (_, s) => ProgramPreviewScreen(library: library, programId: s.pathParameters['id']!)),
      GoRoute(path: '/me',
          builder: (_, _) => StoreLoader(
                db: db, links: links, library: library,
                role: _session.role == Role.doctor ? Role.doctor : Role.owner,
                builder: (store) => PatientScreen(store: store, library: library),
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
        builder: (context, child) => ListenableBuilder(
          listenable: Listenable.merge([_session, _router.routeInformationProvider]),
          builder: (context, _) {
            final path = _router.routeInformationProvider.value.uri.path;
            final show = _session.signedIn && path != '/login' && path != '/profile';
            return Stack(children: [
              child ?? const SizedBox.shrink(),
              if (show)
                PositionedDirectional(
                  start: 10, // الجهة المقابلة لأزرار اللغات في لوحة الطاهي
                  top: MediaQuery.paddingOf(context).top + 6,
                  child: Material(
                    color: Colors.white24, shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'ملفي الشخصي',
                      icon: const Icon(Icons.account_circle, color: Colors.white, size: 30),
                      onPressed: () => _router.go('/profile'),
                    ),
                  ),
                ),
            ]);
          },
        ),
      );
}
