import 'package:flutter/material.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'desktop/desktop_app.dart';
import 'mobile/mobile_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    
    // Get screen size for auto-positioning
    WindowOptions windowOptions = const WindowOptions(
      size: Size(300, 60), // Small Pill Mode as default
      center: false,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
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
  }

  runApp(const ScribeFlowApp());
}

class ScribeFlowApp extends StatelessWidget {
  const ScribeFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Simple Platform Check
    // In a real app, we might want more robust checking or separate entry points.
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return MaterialApp(
      title: 'ScribeFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        fontFamily: 'Inter',
        
        // App Colors
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),    // Sky Blue
          secondary: Color(0xFF10B981),  // Emerald Green (Success)
          surface: Color(0xFF1E293B),    // Slate 800 (Cards)
          onSurface: Color(0xFFF1F5F9),  // Slate 100 (Text)
        ),

        // Card Theme
        cardTheme: CardTheme(
          color: const Color(0xFF1E293B),
          elevation: 0, // Flat design
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
        ),

        // Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981), // Emerald Green
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
          fillColor: Colors.white, // White paper feel
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(16),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        
        useMaterial3: true,
      ),
      home: isDesktop ? const DesktopApp() : const MobileApp(),
    );
  }
}
