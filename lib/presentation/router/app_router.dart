import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

import '../../core/usecases/auth_state_usecase.dart';
import '../../platform/desktop/desktop_app.dart'
    if (dart.library.html) '../../platform/desktop/desktop_app_stub.dart';
import '../../platform/android/features/auth/login_screen.dart'
    as unified_login;
import '../../platform/android/features/home/home_screen.dart'
    as unified_mobile;
import '../../platform/android/features/splash/splash_screen.dart'
    as unified_splash;
import '../screens/admin_dashboard_screen.dart'
    if (dart.library.html) '../../platform/desktop/desktop_app_stub.dart'
    as desktop_admin;
import '../screens/login_screen.dart'
    if (dart.library.html) '../../platform/android/features/auth/login_screen.dart'
    as desktop_login;
import '../screens/qr_login_screen.dart';
import '../screens/register_screen.dart'
    if (dart.library.html) '../../platform/desktop/desktop_app_stub.dart'
    as desktop_register;
import '../widgets/admin_guard.dart';
import '../widgets/auth_guard.dart';

class AppRouter {
  final AuthStateUseCase authUseCase;

  AppRouter(this.authUseCase);

  bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == '/' || settings.name == null) {
      return MaterialPageRoute(
        builder: (_) => const unified_splash.SplashScreen(),
      );
    }

    if (settings.name == '/home') {
      return MaterialPageRoute(
        builder: (context) => AuthGuard(
          child: isDesktop
              ? const DesktopApp()
              : const unified_mobile.HomeScreen(),
        ),
      );
    }

    if (settings.name == '/register') {
      return MaterialPageRoute(
          builder: (context) => const desktop_register.RegisterScreen());
    }

    if (settings.name == '/qr-login') {
      return MaterialPageRoute(builder: (context) => const QrLoginScreen());
    }

    if (settings.name == '/admin') {
      return MaterialPageRoute(
          builder: (context) =>
              const AdminGuard(child: desktop_admin.AdminDashboardScreen()));
    }

    if (settings.name == '/login') {
      return MaterialPageRoute(
        builder: (context) => isDesktop
            ? const desktop_login.LoginScreen()
            : const unified_login.LoginScreen(),
      );
    }

    return MaterialPageRoute(
      builder: (context) => FutureBuilder<bool>(
        future: authUseCase.isAuthenticated(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final isAuth = snapshot.data ?? false;
          if (isAuth) {
            return AuthGuard(
                child: isDesktop
                    ? const DesktopApp()
                    : const unified_mobile.HomeScreen());
          }
          return isDesktop
              ? const desktop_login.LoginScreen()
              : const unified_login.LoginScreen();
        },
      ),
    );
  }
}
