import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../ui_screens/web_screens/web_ip_screen/home_screen.dart';
import '../ui_screens/web_screens/web_login_screen/intro_screen.dart';
import '../ui_screens/web_screens/web_login_screen/web_login_screen.dart';
import '../ui_screens/web_screens/main_dashboard_screen/main_dashboard_screen.dart';
import 'dart:html' as html;

class AppRoutes {
  static const root = '/';
  static const intro = '/intro';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const ipStatusCheck = '/ip_status_check';
}
//testjjkjk
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.root,
  debugLogDiagnostics: false,
  redirect: (context, state) {
    final token = html.window.sessionStorage['auth_token']?.trim();
    final isLoggedIn = token != null && token.split('.').length == 3;

    final location = state.uri.toString();

    final isRootRoute      = location == AppRoutes.root;
    final isIntroRoute     = location == AppRoutes.intro;
    final isLoginRoute     = location == AppRoutes.login;
    final isDashboardRoute = location == AppRoutes.dashboard;


    if (isRootRoute) {
      return isLoggedIn ? AppRoutes.dashboard : AppRoutes.intro;
    }

    if (isLoggedIn && (isIntroRoute || isLoginRoute)) {
      return AppRoutes.dashboard;
    }

    if (!isLoggedIn && isDashboardRoute) {
      return AppRoutes.intro;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.root,
      name: 'root',
      builder: (context, state) => const SizedBox.shrink(),
    ),
    GoRoute(
      path: AppRoutes.intro,
      name: 'intro',
      builder: (context, state) => const WebLandingScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      name: 'dashboard',
      builder: (context, state) => const MainDashboard(),
    ),

    GoRoute(
      path: AppRoutes.ipStatusCheck,
      name: 'ip_status_check',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);