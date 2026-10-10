import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'features/auth/application/auth_controllers.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screens.dart';
import 'features/home/home_screen.dart';
import 'features/ledger/debts_screen.dart';
import 'features/ledger/new_operation_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier(ref.read(sessionProvider));
  ref.listen(sessionProvider, (_, next) => session.value = next);
  ref.onDispose(session.dispose);

  return GoRouter(
    initialLocation: '/signup',
    refreshListenable: session,
    redirect: (context, state) {
      final loggedIn = session.value != null;
      final location = state.matchedLocation;
      final onAuth = location.startsWith('/signup') || location == '/login';
      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/signup',
        builder: (_, _) => const SignupPhoneScreen(),
        routes: [
          GoRoute(path: 'otp', builder: (_, _) => const SignupOtpScreen()),
          GoRoute(path: 'password', builder: (_, _) => const SignupPasswordScreen()),
          GoRoute(path: 'business', builder: (_, _) => const SignupBusinessScreen()),
        ],
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/operation/:kind',
        builder: (_, state) => NewOperationScreen(kind: state.pathParameters['kind']!),
      ),
      GoRoute(path: '/debts', builder: (_, _) => const DebtsScreen()),
    ],
  );
});

class CaissoApp extends ConsumerWidget {
  const CaissoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Caisso',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: ref.watch(localeProvider),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
