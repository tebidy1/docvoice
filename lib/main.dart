import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';

import 'core/di/service_locator.dart';
import 'platform/desktop/desktop_app.dart'
    if (dart.library.html) 'platform/desktop/desktop_app_stub.dart';
import 'landing_page/landing_page.dart';
import 'landing_page/theme/app_theme.dart';
import 'mobile_app/features/auth/login_screen.dart' as unified_login;
import 'mobile_app/features/home/home_screen.dart' as unified_mobile;
import 'mobile_app/features/splash/splash_screen.dart' as unified_splash;
import 'mobile_app/services/websocket_service.dart' as unified_ws;
import 'core/entities/app_theme.dart';
import 'presentation/screens/admin_dashboard_screen.dart'
    if (dart.library.html) 'platform/desktop/desktop_app_stub.dart'
    as desktop_admin;
import 'presentation/screens/login_screen.dart'
    if (dart.library.html) 'mobile_app/features/auth/login_screen.dart'
    as desktop_login;
import 'presentation/screens/qr_login_screen.dart';
import 'presentation/screens/register_screen.dart'
    if (dart.library.html) 'platform/desktop/desktop_app_stub.dart'
    as desktop_register;
import 'core/network/api_client.dart';
import 'core/services/auth_service.dart';
import 'core/services/theme_service.dart';
import 'core/utils/window_manager_proxy.dart';
import 'presentation/widgets/admin_guard.dart';
import 'presentation/widgets/auth_guard.dart';

void main() async {
  setPathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize API service first
  final apiClient = ApiClient();
  await apiClient.init();

  // Initialize dependency injection with backend integration
  await ServiceLocator.initialize();

  // Only set up window manager on desktop platforms
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();

      // Check Auth State for Window Sizing
      final authService = AuthService();
      final bool isAuth = await authService.isAuthenticated();

      final Size initialSize =
          isAuth ? const Size(300, 56) : const Size(400, 720);

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
    ProviderScope(
      child: MultiProvider(
        providers: [
          Provider<unified_ws.WebSocketService>(
              create: (_) => unified_ws.WebSocketService()),
        ],
        child: const ScribeFlowApp(),
      ),
    ),
  );
}

class ScribeFlowApp extends StatefulWidget {
  const ScribeFlowApp({super.key});

  @override
  State<ScribeFlowApp> createState() => _ScribeFlowAppState();
}

class _ScribeFlowAppState extends State<ScribeFlowApp> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    // Desktop check (Windows/MacOS/Linux and NOT Web)
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeService(),
      builder: (context, currentTheme, child) {
        return MaterialApp(
          title: 'ScribeFlow',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness:
                currentTheme.isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: currentTheme.backgroundColor,
            fontFamily: 'Inter',
            colorScheme: ColorScheme(
              brightness:
                  currentTheme.isDark ? Brightness.dark : Brightness.light,
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
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
                  : const Color(0xFFF4F6F9), // Light grey input fields
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
              hintStyle: TextStyle(
                color: currentTheme.isDark
                    ? currentTheme.iconColor.withValues(alpha: 0.5)
                    : const Color(0xFF8A94A6), // Muted text for hints
              ),
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
                  builder: (context) =>
                      const desktop_register.RegisterScreen());
            }

            if (settings.name == '/qr-login') {
              return MaterialPageRoute(
                  builder: (context) => const QrLoginScreen());
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
                future: _authService.isAuthenticated(),
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
      },
    );
  }
}
