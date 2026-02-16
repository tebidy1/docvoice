import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../widgets/create_user_dialog.dart';
import '../widgets/window_title_bar.dart';
import 'user_detail_screen.dart';

class UsersListScreen extends StatefulWidget {
  final int? companyId;

  const UsersListScreen({super.key, this.companyId});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  List<User> _users = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  final TextEditingController _searchController = TextEditingController();
  String? _roleFilter;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({int? page}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _adminService.getUsers(
        page: page ?? _currentPage,
        perPage: 15,
        search: _searchController.text.isEmpty ? null : _searchController.text,
        companyId: widget.companyId,
        role: _roleFilter,
        status: _statusFilter,
      );

      final data = response['data'] as List;
      final meta = response['meta'] as Map<String, dynamic>;

      setState(() {
        _users = data
            .map((json) => User.fromJson(json as Map<String, dynamic>))
            .toList();
        _currentPage = meta['current_page'] as int;
        _totalPages = meta['last_page'] as int;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.deleteUser(user.id);
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Window Title Bar with Controls
          WindowTitleBar(
            title:
                widget.companyId != null ? 'Company Users' : 'Users Management',
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
                onPressed: () {
                  Navigator.pop(context);
                },
                tooltip: 'Back',
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.grey),
                onPressed: () async {
                  if (widget.companyId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select a company first')),
                    );
                    return;
                  }
                  final result = await showDialog<User>(
                    context: context,
                    builder: (context) =>
                        CreateUserDialog(companyId: widget.companyId!),
                  );
                  if (result != null) {
                    _loadUsers(page: 1);
                  }
                },
                tooltip: 'Add User',
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.grey),
                onPressed: () async {
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
                          child: const Text('إلغاء',
                              style: TextStyle(color: Colors.grey)),
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
                      if (mounted) {
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/', (route) => false);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('خطأ في تسجيل الخروج: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                tooltip: 'Logout',
              ),
            ],
          ),
          // Content
          Expanded(
            child: Column(
              children: [
                // Search and Filter Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1E293B),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search users...',
                                prefixIcon: Icon(Icons.search),
                                filled: true,
                                fillColor: Color(0xFF0F172A),
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(color: Colors.white),
                              onSubmitted: (_) => _loadUsers(page: 1),
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => _loadUsers(page: 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: _roleFilter,
                              hint: const Text('Role'),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                    value: null, child: Text('All Roles')),
                                DropdownMenuItem(
                                    value: 'admin', child: Text('Admin')),
                                DropdownMenuItem(
                                    value: 'company_manager',
                                    child: Text('Company Manager')),
                                DropdownMenuItem(
                                    value: 'member', child: Text('Member')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _roleFilter = value;
                                });
                                _loadUsers(page: 1);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _statusFilter,
                              hint: const Text('Status'),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                    value: null, child: Text('All Status')),
                                DropdownMenuItem(
                                    value: 'active', child: Text('Active')),
                                DropdownMenuItem(
                                    value: 'inactive', child: Text('Inactive')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _statusFilter = value;
                                });
                                _loadUsers(page: 1);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Users List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Error: $_error',
                                      style:
                                          const TextStyle(color: Colors.red)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => _loadUsers(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _users.isEmpty
                              ? const Center(child: Text('No users found'))
                              : ListView.builder(
                                  itemCount: _users.length,
                                  itemBuilder: (context, index) {
                                    final user = _users[index];
                                    return _UserCard(
                                      user: user,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                UserDetailScreen(
                                                    userId: user.id),
                                          ),
                                        );
                                      },
                                      onDelete: () => _deleteUser(user),
                                    );
                                  },
                                ),
                ),
                // Pagination
                if (_totalPages > 1)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF1E293B),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 1
                              ? () => _loadUsers(page: _currentPage - 1)
                              : null,
                        ),
                        Text(
                          'Page $_currentPage of $_totalPages',
                          style: const TextStyle(color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _currentPage < _totalPages
                              ? () => _loadUsers(page: _currentPage + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onDelete,
  });

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'company_manager':
        return Colors.blue;
      case 'member':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E293B),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          user.name,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user.email}',
                style: const TextStyle(color: Colors.grey)),
            Row(
              children: [
                Chip(
                  label: Text(
                    user.role.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: _getRoleColor(user.role).withOpacity(0.3),
                  padding: EdgeInsets.zero,
                ),
                if (user.isOnline)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.circle, color: Colors.green, size: 12),
                  ),
              ],
            ),
            if (user.companyName != null)
              Text('Company: ${user.companyName}',
                  style: const TextStyle(color: Colors.grey)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
          tooltip: 'Delete',
        ),
        onTap: onTap,
      ),
    );
  }
}
