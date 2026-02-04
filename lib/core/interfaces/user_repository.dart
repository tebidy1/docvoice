import 'base_repository.dart';
import '../../models/user.dart';

/// Repository interface for User entities
abstract class UserRepository extends BaseRepository<User> {
  /// Get current authenticated user
  Future<User?> getCurrentUser();
  
  /// Update user profile
  Future<User> updateProfile(User user);
  
  /// Get users by company
  Future<List<User>> getByCompany(int companyId);
  
  /// Get users by role
  Future<List<User>> getByRole(String role);
  
  /// Get online users
  Future<List<User>> getOnlineUsers();
  
  /// Update online status
  Future<void> updateOnlineStatus(String userId, bool isOnline);
  
  /// Search users by name or email
  Future<List<User>> searchUsers(String query);
  
  /// Get user statistics
  Future<Map<String, dynamic>> getUserStats(String userId);
}