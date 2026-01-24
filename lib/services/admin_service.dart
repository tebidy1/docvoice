import 'api_service.dart';
import '../models/company.dart';
import '../models/user.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final ApiService _apiService = ApiService();

  // Dashboard Statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final response = await _apiService.get('/admin/dashboard/statistics');
    return response['payload'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCompaniesStatistics() async {
    final response = await _apiService.get('/admin/dashboard/companies-statistics');
    return response['payload'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getUsersStatistics() async {
    final response = await _apiService.get('/admin/dashboard/users-statistics');
    return response['payload'] as Map<String, dynamic>;
  }

  // Companies Management
  Future<Map<String, dynamic>> getCompanies({
    int? page,
    int? perPage,
    String? search,
    String? status,
    String? sortBy,
    String? sortDirection,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();
    if (perPage != null) queryParams['per_page'] = perPage.toString();
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (sortBy != null) queryParams['sort_by'] = sortBy;
    if (sortDirection != null) queryParams['sort_direction'] = sortDirection;
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;

    final response = await _apiService.get('/admin/companies', queryParams: queryParams);
    return response['payload'] as Map<String, dynamic>;
  }

  Future<Company> getCompany(int id) async {
    final response = await _apiService.get('/admin/companies/$id');
    return Company.fromJson(response['payload'] as Map<String, dynamic>);
  }

  Future<Company> createCompany({
    required String name,
    String? domain,
    String? invitationCode,
    String? planType,
    String? status,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
  }) async {
    final response = await _apiService.post('/admin/companies', body: {
      'name': name,
      if (domain != null) 'domain': domain,
      if (invitationCode != null) 'invitation_code': invitationCode,
      if (planType != null) 'plan_type': planType,
      if (status != null) 'status': status,
      'admin_name': adminName,
      'admin_email': adminEmail,
      'admin_password': adminPassword,
    });
    return Company.fromJson(response['payload'] as Map<String, dynamic>);
  }

  Future<Company> updateCompany(int id, {
    String? name,
    String? domain,
    String? invitationCode,
    String? planType,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (domain != null) body['domain'] = domain;
    if (invitationCode != null) body['invitation_code'] = invitationCode;
    if (planType != null) body['plan_type'] = planType;
    if (status != null) body['status'] = status;

    final response = await _apiService.put('/admin/companies/$id', body: body);
    return Company.fromJson(response['payload'] as Map<String, dynamic>);
  }

  Future<void> deleteCompany(int id) async {
    await _apiService.delete('/admin/companies/$id');
  }

  Future<Company> toggleCompanyStatus(int id) async {
    final response = await _apiService.patch('/admin/companies/$id/toggle-status', body: {});
    return Company.fromJson(response['payload'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getCompanyUsers(int companyId, {
    int? page,
    int? perPage,
  }) async {
    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();
    if (perPage != null) queryParams['per_page'] = perPage.toString();

    final response = await _apiService.get('/admin/companies/$companyId/users', queryParams: queryParams);
    return response['payload'] as Map<String, dynamic>;
  }

  // Users Management
  Future<Map<String, dynamic>> getUsers({
    int? page,
    int? perPage,
    String? search,
    int? companyId,
    String? role,
    String? status,
    String? sortBy,
    String? sortDirection,
  }) async {
    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();
    if (perPage != null) queryParams['per_page'] = perPage.toString();
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (companyId != null) queryParams['company_id'] = companyId.toString();
    if (role != null && role.isNotEmpty) queryParams['role'] = role;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (sortBy != null) queryParams['sort_by'] = sortBy;
    if (sortDirection != null) queryParams['sort_direction'] = sortDirection;

    final response = await _apiService.get('/admin/users', queryParams: queryParams);
    return response['payload'] as Map<String, dynamic>;
  }

  Future<User> getUser(int id) async {
    final response = await _apiService.get('/admin/users/$id');
    return User.fromJson(response['payload'] as Map<String, dynamic>);
  }

  Future<User> createUser({
    required String name,
    required String email,
    required String password,
    required int companyId,
    String? role,
    String? status,
    String? phone,
  }) async {
    final response = await _apiService.post('/admin/users', body: {
      'name': name,
      'email': email,
      'password': password,
      'company_id': companyId,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (phone != null) 'phone': phone,
    });
    return User.fromJson(response['payload'] as Map<String, dynamic>);
  }

  Future<User> updateUser(int id, {
    String? name,
    String? email,
    String? password,
    int? companyId,
    String? role,
    String? status,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (password != null) body['password'] = password;
    if (companyId != null) body['company_id'] = companyId;
    if (role != null) body['role'] = role;
    if (status != null) body['status'] = status;
    if (phone != null) body['phone'] = phone;

    final response = await _apiService.put('/admin/users/$id', body: body);
    return User.fromJson(response['payload'] as Map<String, dynamic>);
  }

  Future<void> deleteUser(int id) async {
    await _apiService.delete('/admin/users/$id');
  }

  Future<User> updateUserRole(int id, String role) async {
    final response = await _apiService.patch('/admin/users/$id/role', body: {
      'role': role,
    });
    return User.fromJson(response['payload'] as Map<String, dynamic>);
  }

  Future<User> resetUserPassword(int id, String newPassword) async {
    final response = await _apiService.post('/admin/users/$id/reset-password', body: {
      'password': newPassword,
    });
    return User.fromJson(response['payload'] as Map<String, dynamic>);
  }
}

