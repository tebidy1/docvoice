import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'features/auth/login_screen.dart';
import '../services/auth_service.dart';
import 'services/websocket_service.dart';
import 'services/macro_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final isAuthenticated = await AuthService().isAuthenticated();
  
  // Seed default macros to cloud if user is authenticated
  if (isAuthenticated) {
    final macroService = MacroService();
    try {
      // Migrate any local macros to cloud first
      await macroService.migrateLocalToCloud();
      
      // Check if cloud has macros - getMacros() tries API first
      final macros = await macroService.getMacros();
      
      // If still empty after migration, seed defaults
      if (macros.isEmpty) {
        debugPrint("No macros found, seeding defaults...");
        await macroService.seedDefaultMacrosToCloud();
      } else {
        debugPrint("Found ${macros.length} macros in cloud");
      }
    } catch (e) {
      debugPrint("Macro initialization failed: $e");
      // Don't block app launch
    }
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<WebSocketService>(create: (_) => WebSocketService()),
      ],
      child: ScribeFlowMobileApp(initialRoute: isAuthenticated ? '/' : '/login'),
    ),
  );
}

class ScribeFlowMobileApp extends StatelessWidget {
  final String initialRoute;
  const ScribeFlowMobileApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScribeFlow Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
      // Fallback for named routes not found, though we only use these two
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
           return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      },
    );
  }
}
