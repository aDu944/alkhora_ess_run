import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/attendance/attendance_page.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/home/home_page.dart';
import '../features/leave/leave_page.dart';
import '../features/more/more_page.dart';
import '../features/payslip/payslip_page.dart';
import '../features/placeholders/placeholder_page.dart';
import '../features/splash/splash_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _GoRouterRefresh(ref),
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';
      final authed = auth.valueOrNull != null;

      if (auth.isLoading) return isSplash ? null : '/splash';

      if (!authed && !isLoggingIn) return '/login';
      if (authed && isLoggingIn) return '/home';
      if (authed && isSplash) return '/home';
      if (!authed && isSplash) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomePage(),
        routes: [
          GoRoute(
            path: 'leave',
            builder: (_, __) => const LeavePage(),
          ),
          GoRoute(
            path: 'attendance',
            builder: (_, __) => const AttendancePage(),
          ),
          GoRoute(
            path: 'payslips',
            builder: (_, __) => const PayslipPage(),
          ),
          GoRoute(
            path: 'expenses',
            builder: (_, __) => const PlaceholderPage(title: 'Expenses'),
          ),
          GoRoute(
            path: 'announcements',
            builder: (_, __) => const PlaceholderPage(title: 'Announcements'),
          ),
          GoRoute(
            path: 'profile',
            builder: (_, __) => const PlaceholderPage(title: 'Profile'),
          ),
          GoRoute(
            path: 'holidays',
            builder: (_, __) => const PlaceholderPage(title: 'Holidays'),
          ),
          GoRoute(
            path: 'documents',
            builder: (_, __) => const PlaceholderPage(title: 'Documents'),
          ),
          GoRoute(
            path: 'approvals',
            builder: (_, __) => const PlaceholderPage(title: 'Approvals'),
          ),
          GoRoute(
            path: 'more',
            builder: (_, __) => const MorePage(),
          ),
        ],
      ),
    ],
  );
});

class _GoRouterRefresh extends ChangeNotifier {
  _GoRouterRefresh(this.ref) {
    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}

