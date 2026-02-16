import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class CreateCompanyDialog extends StatefulWidget {
  const CreateCompanyDialog({super.key});

  @override
  State<CreateCompanyDialog> createState() => _CreateCompanyDialogState();
}

class _CreateCompanyDialogState extends State<CreateCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _adminService = AdminService();

  final _nameController = TextEditingController();
  final _domainController = TextEditingController();
  final _invitationCodeController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  String _planType = 'basic';
  String _status = 'active';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _domainController.dispose();
    _invitationCodeController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final company = await _adminService.createCompany(
        name: _nameController.text.trim(),
        domain: _domainController.text.trim().isEmpty
            ? null
            : _domainController.text.trim(),
        invitationCode: _invitationCodeController.text.trim().isEmpty
            ? null
            : _invitationCodeController.text.trim(),
        planType: _planType,
        status: _status,
        adminName: _adminNameController.text.trim(),
        adminEmail: _adminEmailController.text.trim(),
        adminPassword: _adminPasswordController.text,
      );

      if (mounted) {
        Navigator.pop(context, company);
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text(
        'Create New Company',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Company Information',
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name *',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _domainController,
                  decoration: const InputDecoration(
                    labelText: 'Domain (Optional)',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _invitationCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Invitation Code (Optional)',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _planType,
                        decoration: const InputDecoration(
                          labelText: 'Plan Type',
                          labelStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
                        ),
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(
                              value: 'basic', child: Text('Basic')),
                          DropdownMenuItem(
                              value: 'standard', child: Text('Standard')),
                          DropdownMenuItem(
                              value: 'premium', child: Text('Premium')),
                        ],
                        onChanged: (value) =>
                            setState(() => _planType = value!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          labelStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
                        ),
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'suspended', child: Text('Suspended')),
                        ],
                        onChanged: (value) => setState(() => _status = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Admin User Information',
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _adminNameController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Name *',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _adminEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Email *',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!value.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _adminPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Password *',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  validator: (value) => value == null || value.length < 8
                      ? 'Min 8 characters'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create Company'),
        ),
      ],
    );
  }
}
