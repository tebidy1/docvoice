import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthGuard extends StatefulWidget {
  final Widget child;
  
  const AuthGuard({
    super.key,
    required this.child,
  });

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return FutureBuilder<bool>(
      future: authService.isAuthenticated(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final isAuthenticated = snapshot.data ?? false;
        
        if (!isAuthenticated) {
          // Redirect to login after frame is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final currentRoute = ModalRoute.of(context);
              if (currentRoute?.settings.name != '/') {
                Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              }
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        return widget.child;
      },
    );
  }
}

