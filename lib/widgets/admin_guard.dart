import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AdminGuard extends StatefulWidget {
  final Widget child;

  const AdminGuard({
    super.key,
    required this.child,
  });

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return FutureBuilder<Map<String, dynamic>?>(
      future: authService.getCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        final isAdmin =
            user != null && user['role']?.toString().toLowerCase() == 'admin';

        if (!isAdmin) {
          // Redirect to login after frame is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access denied. Admin privileges required.'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.of(context, rootNavigator: true)
                  .pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            }
          });
          return const Scaffold(
            body: Center(
              child: Text(
                'Access Denied\nAdmin privileges required',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            ),
          );
        }

        return widget.child;
      },
    );
  }
}
