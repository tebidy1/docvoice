import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'utils/window_manager_proxy.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'desktop/desktop_app.dart' if (dart.library.html) 'desktop/desktop_app_stub.dart';
import 'mobile_app/features/home/home_screen.dart' as unified_mobile;
import 'mobile_app/features/auth/login_screen.dart' as unified_login;
import 'mobile_app/features/auth/qr_scanner_screen.dart';
import 'mobile_app/services/websocket_service.dart' as unified_ws;
import 'screens/qr_login_screen.dart';
import 'screens/login_screen.dart' if (dart.library.html) 'mobile_app/features/auth/login_screen.dart' as desktop_login;
import 'screens/register_screen.dart' if (dart.library.html) 'desktop/desktop_app_stub.dart' as desktop_register;
import 'screens/admin_dashboard_screen.dart' if (dart.library.html) 'desktop/desktop_app_stub.dart' as desktop_admin;
import 'services/auth_service.dart';
import 'widgets/auth_guard.dart';
import 'widgets/admin_guard.dart';
import 'services/theme_service.dart';
import 'models/app_theme.dart';
import 'core/di/service_locator.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize API service first
  final apiService = ApiService();
  await apiService.init();

  // Initialize dependency injection with backend integration
  await ServiceLocator.initialize();

  // Only set up window manager on desktop platforms
  if (!kIsWeb) {
    try {
      await windowManager.ensureInitialized();
      
      // Check Auth State for Window Sizing
      final authService = AuthService();
      final bool isAuth = await authService.isAuthenticated();

      final Size initialSize = isAuth ? const Size(280, 56) : const Size(400, 720);
      
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
    MultiProvider(
      providers: [
        Provider<unified_ws.WebSocketService>(create: (_) => unified_ws.WebSocketService()),
      ],
      child: const ScribeFlowApp(),
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
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeService(),
      builder: (context, currentTheme, child) {
        return MaterialApp(
          title: 'ScribeFlow',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: currentTheme.isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: currentTheme.backgroundColor,
            fontFamily: 'Inter',
            colorScheme: ColorScheme.fromSeed(
              seedColor: currentTheme.micIdleIcon,
              brightness: currentTheme.isDark ? Brightness.dark : Brightness.light,
              surface: currentTheme.micIdleBackground,
              onSurface: currentTheme.iconColor,
              primary: currentTheme.micIdleIcon,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: currentTheme.micIdleIcon,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: currentTheme.isDark ? currentTheme.micIdleBackground : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
              hintStyle: TextStyle(color: currentTheme.iconColor.withOpacity(0.5)),
            ),
            useMaterial3: true,
          ),
          onGenerateRoute: (settings) {
            // Root route - check authentication
            if (settings.name == '/' || settings.name == null) {
              return MaterialPageRoute(
                builder: (context) => FutureBuilder<bool>(
                  future: _authService.isAuthenticated(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }
                    final isAuth = snapshot.data ?? false;
                    if (isAuth) {
                      return AuthGuard(
                        child: isDesktop ? const DesktopApp() : const unified_mobile.HomeScreen(),
                      );
                    }
                    return isDesktop ? const desktop_login.LoginScreen() : const unified_login.LoginScreen();
                  },
                ),
              );
            }
            
            if (settings.name == '/home') {
              return MaterialPageRoute(
                builder: (context) => AuthGuard(
                  child: isDesktop ? const DesktopApp() : const unified_mobile.HomeScreen(),
                ),
              );
            }
            
            if (settings.name == '/register') {
              return MaterialPageRoute(builder: (context) => const desktop_register.RegisterScreen());
            }
            
            if (settings.name == '/qr-login') {
              return MaterialPageRoute(builder: (context) => const QrLoginScreen());
            }

            if (settings.name == '/admin') {
              return MaterialPageRoute(builder: (context) => AdminGuard(child: const desktop_admin.AdminDashboardScreen()));
            }
            
            if (settings.name == '/login') {
              return MaterialPageRoute(
                builder: (context) => isDesktop ? const desktop_login.LoginScreen() : const unified_login.LoginScreen(),
              );
            }
            
            return MaterialPageRoute(
              builder: (context) => FutureBuilder<bool>(
                future: _authService.isAuthenticated(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  final isAuth = snapshot.data ?? false;
                  if (isAuth) {
                    return AuthGuard(child: isDesktop ? const DesktopApp() : const unified_mobile.HomeScreen());
                  }
                  return isDesktop ? const desktop_login.LoginScreen() : const unified_login.LoginScreen();
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
