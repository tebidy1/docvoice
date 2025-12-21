import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class UserProfileHeader extends StatefulWidget {
  const UserProfileHeader({super.key});

  @override
  State<UserProfileHeader> createState() => _UserProfileHeaderState();
}

class _UserProfileHeaderState extends State<UserProfileHeader> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getUserInitials() {
    if (_user == null) return 'U';
    final name = _user!['name'] ?? _user!['email'] ?? 'User';
    final parts = name.toString().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.toString().substring(0, 1).toUpperCase();
  }

  String _getUserName() {
    if (_user == null) return 'User';
    return _user!['name'] ?? _user!['email'] ?? 'User';
  }

  String _getUserEmail() {
    if (_user == null) return '';
    return _user!['email'] ?? '';
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'هل أنت متأكد من تسجيل الخروج؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _authService.logout();
      } catch (e) {
        print('Logout error: $e');
      } finally {
        if (mounted) {
          // Navigate to login screen by removing all routes
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: const Color(0xFF1E293B),
      onOpened: () => setState(() => _isMenuOpen = true),
      onCanceled: () => setState(() => _isMenuOpen = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isMenuOpen
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User Avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getUserInitials(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // User Name
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getUserName(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_getUserEmail().isNotEmpty)
                  Text(
                    _getUserEmail(),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              _isMenuOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person, color: Colors.white70, size: 18),
              const SizedBox(width: 12),
              const Text(
                'الملف الشخصي',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, color: Colors.red, size: 18),
              const SizedBox(width: 12),
              const Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'logout') {
          _handleLogout();
        } else if (value == 'profile') {
          // TODO: Navigate to profile page
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('صفحة الملف الشخصي قريباً'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }
}

