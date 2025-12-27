import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'services/websocket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<WebSocketService>(create: (_) => WebSocketService()),
      ],
      child: const ScribeFlowMobileApp(),
    ),
  );
}

class ScribeFlowMobileApp extends StatelessWidget {
  const ScribeFlowMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScribeFlow Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Force Dark Theme
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
