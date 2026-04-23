import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'mobile_app/features/auth/login_screen.dart' as unified_login;
import 'web_extension/presentation/presentation/screens/extension_home_screen.dart'; // New Entry Point
import 'mobile_app/data/repositories/websocket_service.dart' as unified_ws;
import 'core/entities/app_theme.dart';
import 'data/repositories/auth_service.dart';
import 'data/repositories/theme_service.dart';
import 'presentation/presentation/widgets/auth_guard.dart';

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

final GlobalKey<NavigatorState> extensionNavigatorKey = GlobalKey<NavigatorState>();

class ScribeFlowExtensionApp extends StatefulWidget {
  const ScribeFlowExtensionApp({super.key});

  @override
  State<ScribeFlowExtensionApp> createState() => _ScribeFlowExtensionAppState();
}

class _ScribeFlowExtensionAppState extends State<ScribeFlowExtensionApp> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeService(),
      builder: (context, currentTheme, child) {
        return MaterialApp(
          navigatorKey: extensionNavigatorKey,
          title: 'ScribeFlow Extension',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return GlobalExtensionWrapper(child: child!);
          },
          theme: ThemeData(
            brightness:
                currentTheme.isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: currentTheme.backgroundColor,
            // Force system fonts only - block any web font attempts
            fontFamily: 'sans-serif',
            fontFamilyFallback: const ['Arial', 'Helvetica', 'sans-serif'],
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
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    fontFamily: 'sans-serif'),
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
              hintStyle: TextStyle(
                  color: currentTheme.iconColor.withValues(alpha: 0.5)),
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

final RouteObserver<ModalRoute<void>> extensionRouteObserver = RouteObserver<ModalRoute<void>>();

class GlobalExtensionWrapper extends StatefulWidget {
  final Widget child;
  const GlobalExtensionWrapper({super.key, required this.child});

  @override
  State<GlobalExtensionWrapper> createState() => _GlobalExtensionWrapperState();
}

class _GlobalExtensionWrapperState extends State<GlobalExtensionWrapper> with RouteAware {

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // In a global wrapper above MaterialApp, we cannot easily use RouteObserver 
    // because the context here is ABOVE the Navigator.
    // Instead of using RouteObserver here, we will just use a builder inside
    // the Stack that periodically checks, or we rely on the fact that we can 
    // inject a listener into the MaterialApp.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // To properly react to navigation changes when wrapped ABOVE the navigator,
    // we use a stream or a valuelistenable. 
    // A simpler approach for the back button in Flutter is to just rebuild 
    // when navigation happens, but Flutter doesn't notify generic wrappers.
    // We will build the button inside a specific widget that subscribes to the observer.
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          widget.child,
          // Floating Glassy Back Button (Only visible if we can pop)
          GlobalBackButton(navigatorKey: extensionNavigatorKey),
        ],
      ),
    );
  }
}

class GlobalBackButton extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const GlobalBackButton({super.key, required this.navigatorKey});

  @override
  State<GlobalBackButton> createState() => _GlobalBackButtonState();
}

class _GlobalBackButtonState extends State<GlobalBackButton> {
  bool _canPop = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // A simple, robust way to check navigation state from completely outside 
    // without complex RouteObserver setups in the extension wrapper:
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      final canPopNow = widget.navigatorKey.currentState?.canPop() ?? false;
      if (canPopNow != _canPop && mounted) {
        setState(() {
          _canPop = canPopNow;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canPop) return const SizedBox.shrink(); // Hide on Home Screen

    return Positioned(
      left: 10,
      top: MediaQuery.of(context).size.height / 2 - 25,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_canPop) {
              widget.navigatorKey.currentState?.pop();
            }
          },
          customBorder: const CircleBorder(),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1), // Glassy neutral effect
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.only(right: 4.0), // center slightly optical
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}



