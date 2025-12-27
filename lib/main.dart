import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'desktop/desktop_app.dart';
import 'mobile/mobile_app.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'widgets/auth_guard.dart';
import 'widgets/admin_guard.dart';
import 'services/theme_service.dart';
import 'models/app_theme.dart';

// Conditional import for Platform
import 'dart:io' if (dart.library.html) 'dart:html' as platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Only set up window manager on desktop platforms
  if (!kIsWeb) {
    try {
      await windowManager.ensureInitialized();
      
      // Get screen size for auto-positioning
      WindowOptions windowOptions = const WindowOptions(
        size: Size(280, 56), // Native Utility size (Tight Fit)

        center: true, // Center the window on first launch
        backgroundColor: Colors.transparent, // Transparent for frameless mode
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        alwaysOnTop: false, // Allow window to be behind other applications
      );
      
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setBackgroundColor(Colors.transparent);
        await windowManager.setResizable(false); // Lock size for capsule
        await windowManager.show();
        await windowManager.focus();
        
        // Auto-position to right
        // Note: We can't get screen size easily here without context or extra packages in main()
        // But we can try to use windowManager.getPrimaryDisplay() if available, 
        // or just rely on the app's first frame to dock itself.
        // However, the user asked to do it here. 
        // Let's try to get the display info.
        try {
           // This might fail if getPrimaryDisplay is not available as seen before.
           // But wait, the previous error was "The method 'getPrimaryDisplay' isn't defined".
           // So we CANNOT use it here.
           // We will rely on a fixed offset for now, or better, 
           // let the DesktopApp's initState handle the precise docking.
           // But to satisfy "Default Size", we set 400x800 above.
        } catch (e) {
          print("Error getting display: $e");
        }
      });
    } catch (e) {
      print("Error initializing window manager: $e");
    }
  }

  runApp(const ScribeFlowApp());
}

class ScribeFlowApp extends StatefulWidget {
  const ScribeFlowApp({super.key});

  @override
  State<ScribeFlowApp> createState() => _ScribeFlowAppState();
}

class _ScribeFlowAppState extends State<ScribeFlowApp> {
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final authenticated = await _authService.isAuthenticated();
      setState(() {
        _isAuthenticated = authenticated;
        _isLoading = false;
      });
    } catch (e) {
      print('Auth check error: $e');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple Platform Check
    // On web, always show mobile app
    // On desktop, show desktop app
    final isDesktop = !kIsWeb;

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
            
            // App Colors
            colorScheme: ColorScheme.fromSeed(
              seedColor: currentTheme.micIdleIcon,
              brightness: currentTheme.isDark ? Brightness.dark : Brightness.light,
              surface: currentTheme.micIdleBackground,
              onSurface: currentTheme.iconColor,
              primary: currentTheme.micIdleIcon,
            ),

            // Button Theme
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: currentTheme.micIdleIcon, // Use theme primary
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            
            // Input Decoration (Editor)
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
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final isAuth = snapshot.data ?? false;
                if (isAuth) {
                  return AuthGuard(
                    child: isDesktop ? const DesktopApp() : const MobileApp(),
                  );
                }
                return const LoginScreen();
              },
            ),
          );
        }
        
        // Home route - protected, requires authentication
        if (settings.name == '/home') {
          return MaterialPageRoute(
            builder: (context) => AuthGuard(
              child: isDesktop ? const DesktopApp() : const MobileApp(),
            ),
          );
        }
        
        // Register route - public
        if (settings.name == '/register') {
          return MaterialPageRoute(
            builder: (context) => const RegisterScreen(),
          );
        }
        
        // Admin Dashboard route - protected, requires admin role
        if (settings.name == '/admin') {
          return MaterialPageRoute(
            builder: (context) => AdminGuard(
              child: const AdminDashboardScreen(),
            ),
          );
        }
        
        // Login route - public
        if (settings.name == '/login') {
          return MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          );
        }
        
        // Default: redirect to root
        return MaterialPageRoute(
          builder: (context) => FutureBuilder<bool>(
            future: _authService.isAuthenticated(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final isAuth = snapshot.data ?? false;
              if (isAuth) {
                return AuthGuard(
                  child: isDesktop ? const DesktopApp() : const MobileApp(),
                );
              }
              return const LoginScreen();
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
