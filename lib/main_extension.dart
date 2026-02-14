import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'mobile_app/features/auth/login_screen.dart' as unified_login;
// Mobile features (compatible with Web)
import 'mobile_app/features/home/home_screen.dart' as unified_mobile;
import 'web_extension/screens/extension_home_screen.dart'; // New Entry Point
import 'mobile_app/services/websocket_service.dart' as unified_ws;
import 'models/app_theme.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'widgets/auth_guard.dart';

void main() {
  // 1. Run App Immediately (Don't await anything here to ensure UI shows up)
  runApp(const SafeExtensionLauncher());
}

class SafeExtensionLauncher extends StatefulWidget {
  const SafeExtensionLauncher({super.key});

  @override
  State<SafeExtensionLauncher> createState() => _SafeExtensionLauncherState();
}

class _SafeExtensionLauncherState extends State<SafeExtensionLauncher> {
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      print("SafeLauncher: Initializing...");
      WidgetsFlutterBinding.ensureInitialized();

      // Try loading .env, but don't crash if it fails
      try {
        await dotenv.load(fileName: ".env");
        print("SafeLauncher: DotEnv loaded.");
      } catch (e) {
        print("SafeLauncher: DotEnv warning (non-fatal): $e");
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, stack) {
      print("SafeLauncher: CRITICAL ERROR: $e");
      print(stack);
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have a startup error, show it plainly
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamilyFallback: const ['sans-serif'],
        ),
        home: Scaffold(
          backgroundColor: Colors.red.shade50,
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text("Startup Error",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.red,
                        fontFamily: 'sans-serif')),
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'sans-serif')),
              ],
            ),
          ),
        ),
      );
    }

    // Still initializing? Show spinner
    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Initializing ScribeFlow...",
                    style: TextStyle(
                        color: Colors.grey, fontFamily: 'sans-serif')),
              ],
            ),
          ),
        ),
      );
    }

    // Success! Launch the Real App
    return MultiProvider(
      providers: [
        Provider<unified_ws.WebSocketService>(
            create: (_) => unified_ws.WebSocketService()),
      ],
      child: const ScribeFlowExtensionApp(),
    );
  }
}

class ScribeFlowExtensionApp extends StatefulWidget {
  const ScribeFlowExtensionApp({super.key});

  @override
  State<ScribeFlowExtensionApp> createState() => _ScribeFlowExtensionAppState();
}

class _ScribeFlowExtensionAppState extends State<ScribeFlowExtensionApp> {
  final AuthService _authService = AuthService();
  bool? _isAuthenticated; // Cached auth state
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final isAuth = await _authService.isAuthenticated().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print("Auth Check Timeout!");
          return false;
        },
      );
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
          _isCheckingAuth = false;
        });
      }
    } catch (e) {
      print("Auth check error: $e");
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isCheckingAuth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeService(),
      builder: (context, currentTheme, child) {
        return MaterialApp(
          title: 'ScribeFlow Extension',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness:
                currentTheme.isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: currentTheme.backgroundColor,
            // Force system fonts only - block any web font attempts
            fontFamily: 'sans-serif',
            fontFamilyFallback: const ['Arial', 'Helvetica', 'sans-serif'],
            colorScheme: ColorScheme.fromSeed(
              seedColor: currentTheme.micIdleIcon,
              brightness:
                  currentTheme.isDark ? Brightness.dark : Brightness.light,
              surface: currentTheme.micIdleBackground,
              onSurface: currentTheme.iconColor,
              primary: currentTheme.micIdleIcon,
              onPrimary: Colors.white,
            ),
            useMaterial3: true,
            textTheme: const TextTheme(
              bodyLarge: TextStyle(fontFamily: 'sans-serif'),
              bodyMedium: TextStyle(fontFamily: 'sans-serif'),
              titleLarge: TextStyle(fontFamily: 'sans-serif'),
            ),
          ),
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => FutureBuilder<bool>(
                future: _authService.isAuthenticated().timeout(
                  const Duration(seconds: 5),
                  onTimeout: () {
                    print("Auth Check Timeout!");
                    return false; // Default to login on timeout
                  },
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }

                  if (snapshot.hasError) {
                    return Scaffold(
                        body: Center(
                            child: Text("Auth Error: ${snapshot.error}",
                                style: const TextStyle(
                                    fontFamily: 'sans-serif'))));
                  }

                  final isAuth = snapshot.data ?? false;

                  if (isAuth) {
                    return const AuthGuard(child: ExtensionHomeScreen());
                  } else {
                    return const unified_login.LoginScreen();
                  }
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
