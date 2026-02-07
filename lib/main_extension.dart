import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Mobile features (compatible with Web)
import 'web_extension/screens/extension_home_screen.dart';
import 'web_extension/screens/extension_login_screen.dart';
import 'mobile_app/services/websocket_service.dart' as unified_ws;

import 'services/auth_service.dart';
import 'widgets/auth_guard.dart';
import 'services/theme_service.dart';
import 'models/app_theme.dart';

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
        home: Scaffold(
          backgroundColor: Colors.red.shade50,
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text("Startup Error", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
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
                Text("Initializing ScribeFlow...", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    // Success! Launch the Real App
    return MultiProvider(
      providers: [
        Provider<unified_ws.WebSocketService>(create: (_) => unified_ws.WebSocketService()),
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
            useMaterial3: true,
          ),
          home: _buildHomeScreen(),
        );
      },
    );
  }

  Widget _buildHomeScreen() {
    // Still checking auth? Show loading
    if (_isCheckingAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Auth check complete - show appropriate screen
    if (_isAuthenticated == true) {
      return AuthGuard(child: const ExtensionHomeScreen());
    } else {
      return const ExtensionLoginScreen();
    }
  }
}

