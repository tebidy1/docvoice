import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../services/admin_service.dart';
import '../models/company.dart';
import '../models/user.dart';
import '../widgets/window_title_bar.dart';
import 'users_list_screen.dart';

class CompanyDetailScreen extends StatefulWidget {
  final int companyId;

  const CompanyDetailScreen({super.key, required this.companyId});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  final AdminService _adminService = AdminService();
  Company? _company;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final company = await _adminService.getCompany(widget.companyId);
      setState(() {
        _company = company;
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
            title: 'Company Details',
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
                onPressed: () {
                  Navigator.pop(context);
                },
                tooltip: 'Back',
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.grey),
                onPressed: _loadCompany,
                tooltip: 'Refresh',
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
                        onPressed: _loadCompany,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _company == null
                  ? const Center(child: Text('Company not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Company Info Card
                          Card(
                            color: const Color(0xFF1E293B),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _company!.name,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          _company!.status.toUpperCase(),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: _company!.isActive ? Colors.green : Colors.orange,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _DetailRow(label: 'ID', value: _company!.id.toString()),
                                  if (_company!.domain != null)
                                    _DetailRow(label: 'Domain', value: _company!.domain!),
                                  if (_company!.invitationCode != null)
                                    _DetailRow(label: 'Invitation Code', value: _company!.invitationCode!),
                                  if (_company!.code != null)
                                    _DetailRow(label: 'Code', value: _company!.code!),
                                  _DetailRow(label: 'Plan Type', value: _company!.planType),
                                  _DetailRow(label: 'Created At', value: _company!.createdAt.toString()),
                                  _DetailRow(label: 'Updated At', value: _company!.updatedAt.toString()),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UsersListScreen(companyId: _company!.id),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.people),
                                  label: const Text('View Users'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final updated = await _adminService.toggleCompanyStatus(_company!.id);
                                      setState(() {
                                        _company = updated;
                                      });
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Company ${updated.isActive ? "activated" : "suspended"} successfully',
                                            ),
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
                                  },
                                  icon: Icon(_company!.isActive ? Icons.pause : Icons.play_arrow),
                                  label: Text(_company!.isActive ? 'Suspend' : 'Activate'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _company!.isActive ? Colors.orange : Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

