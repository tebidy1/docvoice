import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../utils/window_manager_helper.dart';
import '../services/auth_service.dart';
import '../widgets/window_title_bar.dart';
import 'companies_list_screen.dart';
import 'users_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WindowManagerHelper.setTransparencyLocked(true); // Enforce full visibility
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _adminService.getStatistics();
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
            title: 'Admin Dashboard',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.grey),
                onPressed: _loadStatistics,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.grey),
                onPressed: () async {
                  await _authService.logout();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                tooltip: 'Logout',
              ),
            ],
          ),
          // Content
          Expanded(
            child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStatistics,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _statistics == null
                  ? const Center(child: Text('No data available'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quick Actions
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Companies',
                                  value: _statistics!['companies']?['total']?.toString() ?? '0',
                                  icon: Icons.business,
                                  color: Colors.blue,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const CompaniesListScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _StatCard(
                                  title: 'Users',
                                  value: _statistics!['users']?['total']?.toString() ?? '0',
                                  icon: Icons.people,
                                  color: Colors.green,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const UsersListScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Companies Statistics
                          _SectionCard(
                            title: 'Companies Statistics',
                            child: Column(
                              children: [
                                _StatRow(
                                  label: 'Total',
                                  value: _statistics!['companies']?['total']?.toString() ?? '0',
                                ),
                                _StatRow(
                                  label: 'Active',
                                  value: _statistics!['companies']?['active']?.toString() ?? '0',
                                  valueColor: Colors.green,
                                ),
                                _StatRow(
                                  label: 'Suspended',
                                  value: _statistics!['companies']?['suspended']?.toString() ?? '0',
                                  valueColor: Colors.orange,
                                ),
                                _StatRow(
                                  label: 'Created Today',
                                  value: _statistics!['companies']?['created_today']?.toString() ?? '0',
                                ),
                                _StatRow(
                                  label: 'Created This Week',
                                  value: _statistics!['companies']?['created_this_week']?.toString() ?? '0',
                                ),
                                _StatRow(
                                  label: 'Created This Month',
                                  value: _statistics!['companies']?['created_this_month']?.toString() ?? '0',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Users Statistics
                          _SectionCard(
                            title: 'Users Statistics',
                            child: Column(
                              children: [
                                _StatRow(
                                  label: 'Total',
                                  value: _statistics!['users']?['total']?.toString() ?? '0',
                                ),
                                _StatRow(
                                  label: 'Admins',
                                  value: _statistics!['users']?['admins']?.toString() ?? '0',
                                  valueColor: Colors.purple,
                                ),
                                _StatRow(
                                  label: 'Company Managers',
                                  value: _statistics!['users']?['company_managers']?.toString() ?? '0',
                                  valueColor: Colors.blue,
                                ),
                                _StatRow(
                                  label: 'Members',
                                  value: _statistics!['users']?['members']?.toString() ?? '0',
                                  valueColor: Colors.grey,
                                ),
                                _StatRow(
                                  label: 'Active',
                                  value: _statistics!['users']?['active']?.toString() ?? '0',
                                  valueColor: Colors.green,
                                ),
                                _StatRow(
                                  label: 'Online',
                                  value: _statistics!['users']?['online']?.toString() ?? '0',
                                  valueColor: Colors.teal,
                                ),
                                _StatRow(
                                  label: 'Created Today',
                                  value: _statistics!['users']?['created_today']?.toString() ?? '0',
                                ),
                                _StatRow(
                                  label: 'Created This Week',
                                  value: _statistics!['users']?['created_this_week']?.toString() ?? '0',
                                ),
                                _StatRow(
                                  label: 'Created This Month',
                                  value: _statistics!['users']?['created_this_month']?.toString() ?? '0',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
    );
  }

  @override
  void dispose() {
    WindowManagerHelper.setTransparencyLocked(false); // Restore transparency capability
    super.dispose();
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

