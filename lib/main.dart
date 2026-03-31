import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_strategy/url_strategy.dart';

import 'package:soutnote/desktop/desktop_app.dart'
    if (dart.library.html) 'package:soutnote/desktop/desktop_app_stub.dart';

import 'package:soutnote/features/auth/presentation/screens/login_screen.dart' as unified_login;
import 'package:soutnote/features/home/home_screen.dart' as unified_mobile;
import 'package:soutnote/features/splash/splash_screen.dart' as unified_splash;
import 'package:soutnote/features/admin/presentation/screens/admin_dashboard_screen.dart'
    if (dart.library.html) 'package:soutnote/desktop/desktop_app_stub.dart' as desktop_admin;
import 'package:soutnote/features/auth/presentation/screens/login_screen.dart'
    if (dart.library.html) 'package:soutnote/features/auth/presentation/screens/login_screen.dart'
    as desktop_login;
import 'package:soutnote/features/auth/presentation/screens/qr_login_screen.dart';
import 'package:soutnote/features/auth/presentation/screens/register_screen.dart'
    if (dart.library.html) 'package:soutnote/desktop/desktop_app_stub.dart' as desktop_register;
import 'package:soutnote/core/services/theme_service.dart';
import 'package:soutnote/utils/window_manager_proxy.dart';
import 'package:soutnote/shared/widgets/admin_guard.dart';
import 'package:soutnote/shared/widgets/auth_guard.dart';
import 'package:soutnote/core/providers/common_providers.dart';

void main() async {
  setPathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialization of core services via Riverpod
  final container = ProviderContainer();

  // Initialize all repositories (Isar, API, etc.)
  await container.read(initializeRepositoriesProvider.future);

  // Only set up window manager on desktop platforms
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();

      // Check Auth State for Window Sizing
      final authService = container.read(authServiceProvider);
      final bool isAuth = await authService.isAuthenticated();

      final Size initialSize =
          isAuth ? const Size(280, 56) : const Size(400, 720);

      WindowOptions windowOptions = WindowOptions(
        size: initialSize,
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        alwaysOnTop: isAuth,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setBackgroundColor(Colors.transparent);
        await windowManager.setResizable(!isAuth);
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      print("Error initializing window manager: $e");
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ScribeFlowApp(),
    ),
  );
}

class ScribeFlowApp extends ConsumerWidget {
  const ScribeFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Desktop check (Windows/MacOS/Linux and NOT Web)
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    final currentTheme = ref.watch(themeServiceProvider);
    final authService = ref.watch(authServiceProvider);

    return MaterialApp(
      title: 'ScribeFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: currentTheme.isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: currentTheme.backgroundColor,
        fontFamily: 'Inter',
        colorScheme: ColorScheme(
          brightness: currentTheme.isDark ? Brightness.dark : Brightness.light,
          // Primary — used for active icons, header text accents
          primary: currentTheme.micIdleIcon,
          onPrimary: Colors.white,
          primaryContainer: currentTheme.micIdleBackground,
          onPrimaryContainer: currentTheme.iconColor,
          // Secondary
          secondary: currentTheme.micIdleIcon,
          onSecondary: Colors.white,
          secondaryContainer: currentTheme.hoverColor,
          onSecondaryContainer: currentTheme.iconColor,
          // Surface — used for Cards, BottomAppBar, FAB
          surface: currentTheme.micIdleBackground,
          onSurface: currentTheme.iconColor,
          // Error
          error: currentTheme.micRecordingBackground,
          onError: Colors.white,
          // Outline — used for card borders, text field borders, FAB border
          outline: currentTheme.borderColor,
          outlineVariant: currentTheme.dividerColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: currentTheme.micIdleIcon,
            foregroundColor: Colors.white,
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        cardTheme: CardThemeData(
          color: currentTheme.micIdleBackground,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: currentTheme.borderColor.withValues(alpha: 0.4)),
          ),
        ),
        iconTheme: IconThemeData(
          color: currentTheme.iconColor,
        ),
        dividerTheme: DividerThemeData(
          color: currentTheme.dividerColor,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: currentTheme.isDark
              ? currentTheme.micIdleBackground
              : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(16),
          hintStyle:
              TextStyle(color: currentTheme.iconColor.withValues(alpha: 0.5)),
        ),
        useMaterial3: true,
      ),
      onGenerateRoute: (settings) {
        // Root route - always start with the Splash Screen
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
              builder: (context) => const AdminGuard(
                  child: desktop_admin.AdminDashboardScreen()));
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
            future: authService.isAuthenticated(),
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
      },
      initialRoute: '/',
    );
  }
}
