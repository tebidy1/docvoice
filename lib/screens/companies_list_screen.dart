import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../models/company.dart';
import '../widgets/window_title_bar.dart';
import 'company_detail_screen.dart';

class CompaniesListScreen extends StatefulWidget {
  const CompaniesListScreen({super.key});

  @override
  State<CompaniesListScreen> createState() => _CompaniesListScreenState();
}

class _CompaniesListScreenState extends State<CompaniesListScreen> {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  List<Company> _companies = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  final TextEditingController _searchController = TextEditingController();
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies({int? page}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _adminService.getCompanies(
        page: page ?? _currentPage,
        perPage: 15,
        search: _searchController.text.isEmpty ? null : _searchController.text,
        status: _statusFilter,
      );

      final data = response['data'] as List;
      final meta = response['meta'] as Map<String, dynamic>;

      setState(() {
        _companies = data.map((json) => Company.fromJson(json as Map<String, dynamic>)).toList();
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

  Future<void> _toggleCompanyStatus(Company company) async {
    try {
      final updated = await _adminService.toggleCompanyStatus(company.id);
      setState(() {
        final index = _companies.indexWhere((c) => c.id == company.id);
        if (index != -1) {
          _companies[index] = updated;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Company ${updated.isActive ? "activated" : "suspended"} successfully'),
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

  Future<void> _deleteCompany(Company company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Company'),
        content: Text('Are you sure you want to delete ${company.name}?'),
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
        await _adminService.deleteCompany(company.id);
        await _loadCompanies();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Company deleted successfully'),
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
            title: 'Companies Management',
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
                onPressed: () {
                  // TODO: Show create company dialog
                },
                tooltip: 'Add Company',
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
                      if (mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search companies...',
                            prefixIcon: Icon(Icons.search),
                            filled: true,
                            fillColor: Color(0xFF0F172A),
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(color: Colors.white),
                          onSubmitted: (_) => _loadCompanies(page: 1),
                        ),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _statusFilter,
                        hint: const Text('Status'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _statusFilter = value;
                          });
                          _loadCompanies(page: 1);
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => _loadCompanies(page: 1),
                      ),
                    ],
                  ),
                ),
                // Companies List
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
                                    onPressed: () => _loadCompanies(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _companies.isEmpty
                              ? const Center(child: Text('No companies found'))
                              : ListView.builder(
                                  itemCount: _companies.length,
                                  itemBuilder: (context, index) {
                                    final company = _companies[index];
                                    return _CompanyCard(
                                      company: company,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CompanyDetailScreen(companyId: company.id),
                                          ),
                                        );
                                      },
                                      onToggleStatus: () => _toggleCompanyStatus(company),
                                      onDelete: () => _deleteCompany(company),
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
                              ? () => _loadCompanies(page: _currentPage - 1)
                              : null,
                        ),
                        Text(
                          'Page $_currentPage of $_totalPages',
                          style: const TextStyle(color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _currentPage < _totalPages
                              ? () => _loadCompanies(page: _currentPage + 1)
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

class _CompanyCard extends StatelessWidget {
  final Company company;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const _CompanyCard({
    required this.company,
    required this.onTap,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E293B),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: company.isActive ? Colors.green : Colors.orange,
          child: Icon(
            company.isActive ? Icons.business : Icons.business_center,
            color: Colors.white,
          ),
        ),
        title: Text(
          company.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (company.domain != null) Text('Domain: ${company.domain}', style: const TextStyle(color: Colors.grey)),
            Text(
              'Status: ${company.status}',
              style: TextStyle(
                color: company.isActive ? Colors.green : Colors.orange,
              ),
            ),
            if (company.usersCount != null)
              Text('Users: ${company.usersCount}', style: const TextStyle(color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                company.isActive ? Icons.pause : Icons.play_arrow,
                color: company.isActive ? Colors.orange : Colors.green,
              ),
              onPressed: onToggleStatus,
              tooltip: company.isActive ? 'Suspend' : 'Activate',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

