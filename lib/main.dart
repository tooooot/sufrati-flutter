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
import 'data/links.dart';
import 'screens/house_create_screen.dart';
import 'screens/household_screen.dart';
import 'screens/join_screen.dart';
import 'screens/profile_screen.dart';

import 'firebase_options.dart';
import 'data/household.dart';
import 'data/i18n.dart';
import 'data/repository.dart';
import 'data/store.dart';
import 'screens/coming_next_screen.dart';
import 'screens/cook_screen.dart';
import 'screens/demo_screen.dart';
import 'screens/login_screen.dart';
import 'screens/patient_screen.dart';
import 'screens/program_preview_screen.dart';
import 'screens/role_screen.dart';
import 'screens/start_screen.dart';
import 'theme.dart';

Future<void> main() async {
  usePathUrlStrategy(); // روابط نظيفة على الويب (/programs/keto_general) بدل #/
  WidgetsFlutterBinding.ensureInitialized();
  final library = await Library.load();
  final i18n = await CookI18n.load();
  // الجوال: Firebase حقيقي. الويب (معاينة التصفح) بلا Firebase — دخول وهمي.
  AuthService auth = FakeAuthService();
  if (!kIsWeb) {
    await Firebase.initializeApp(options: SufratiFirebase.current);
    auth = FirebaseAuthService();
  }
  runApp(SufratiApp(library: library, i18n: i18n, auth: auth));
}

class SufratiApp extends StatelessWidget {
  final Library library;
  final CookI18n i18n;
  final AuthService auth;
  SufratiApp({super.key, required this.library, required this.i18n, required this.auth});

  // بيت تجريبي للمعاينة — يُستبدل بـFirestoreStore في المرحلة 2
  late final _demo = LocalStore(library,
      Household(id: 'demo', label: 'بيت تجريبي', programId: 'kidney_salama', eaters: 2, cookName: 'ماريا'));

  // الجلسة: الدخول أولاً (Google/Apple) ثم اختيار الدور. التصفح والمعاينة يبقيان متاحين بلا حساب.
  late final _session = Session(auth);
  final _links = LinkService();

  static bool _isPublic(String p) =>
      p == '/login' || p == '/browse' || p.startsWith('/programs/') || p.startsWith('/demo');

  late final _router = GoRouter(refreshListenable: _session, redirect: (_, state) {
    final p = state.matchedLocation;
    if (!_session.signedIn) return _isPublic(p) ? null : '/login';
    if (p == '/login') return _session.needsRole ? '/role' : '/';
    if (_session.needsRole && !_isPublic(p) && p != '/role') return '/role';
    return null;
  }, routes: [
    GoRoute(path: '/role', builder: (_, _) => RoleScreen(session: _session)),
    GoRoute(path: '/browse', builder: (_, _) => StartScreen(library: library)),
    GoRoute(path: '/household', builder: (_, _) => HouseholdScreen(links: _links, library: library)),
    GoRoute(path: '/profile', builder: (_, _) => ProfileScreen(session: _session, links: _links)),
    GoRoute(path: '/join/:role',
        builder: (_, st) => JoinScreen(links: _links, session: _session,
            role: st.pathParameters['role'] == 'doctor' ? Role.doctor : Role.cook)),
    GoRoute(path: '/login', builder: (_, s) => LoginScreen(auth: auth, next: s.uri.queryParameters['next'] ?? '/')),
    GoRoute(path: '/', builder: (_, _) => StartScreen(library: library)),
    GoRoute(path: '/programs/:id',
        builder: (_, s) => ProgramPreviewScreen(library: library, programId: s.pathParameters['id']!)),
    GoRoute(path: '/demo', builder: (_, _) => const DemoScreen()),
    GoRoute(path: '/demo/me', builder: (_, _) => PatientScreen(store: _demo, library: library)),
    GoRoute(path: '/demo/cook', builder: (_, _) => CookScreen(store: _demo, library: library, i18n: i18n)),
    GoRoute(path: '/signup/custom', builder: (_, _) => const ComingNextScreen(title: 'نظامك الخاص')),
    GoRoute(path: '/signup/:id',
        builder: (_, s) => HouseCreateScreen(library: library, links: _links, programId: s.pathParameters['id']!)),
  ]);

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
                  end: 10,
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
