import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_strategy/url_strategy.dart';

import 'core/di/service_locator.dart';
import 'core/repositories/i_auth_service.dart';
import 'core/entities/app_theme.dart';
import 'core/services/theme_service.dart';
import 'core/utils/window_manager_proxy.dart';
import 'presentation/landing_page/landing_page.dart';
import 'presentation/landing_page/theme/app_theme.dart';
import 'presentation/state/app_providers.dart';
import 'presentation/router/app_router.dart';

void main() async {
  setPathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await ServiceLocator.initialize();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();

      final authService = ServiceLocator.get<IAuthService>();
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
    const ProviderScope(
      child: ScribeFlowApp(),
    ),
  );
}

class ScribeFlowApp extends ConsumerStatefulWidget {
  const ScribeFlowApp({super.key});

  @override
  ConsumerState<ScribeFlowApp> createState() => _ScribeFlowAppState();
}

class _ScribeFlowAppState extends ConsumerState<ScribeFlowApp> {
  late final AppRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter(ref.read(authStateUseCaseProvider));
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ref.watch(themeProvider);

    return ValueListenableBuilder<ThemePreset>(
      valueListenable: themeService,
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
              primary: currentTheme.micIdleIcon,
              onPrimary: Colors.white,
              primaryContainer: currentTheme.micIdleBackground,
              onPrimaryContainer: currentTheme.iconColor,
              secondary: currentTheme.micIdleIcon,
              onSecondary: Colors.white,
              secondaryContainer: currentTheme.hoverColor,
              onSecondaryContainer: currentTheme.iconColor,
              surface: currentTheme.micIdleBackground,
              onSurface: currentTheme.iconColor,
              error: currentTheme.micRecordingBackground,
              onError: Colors.white,
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
                  : const Color(0xFFF4F6F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
              hintStyle: TextStyle(
                color: currentTheme.isDark
                    ? currentTheme.iconColor.withValues(alpha: 0.5)
                    : const Color(0xFF8A94A6),
              ),
            ),
            useMaterial3: true,
          ),
          onGenerateRoute: _router.onGenerateRoute,
          initialRoute: '/',
        );
      },
    );
  }
}
