import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Centralized error handling utility
///
/// Provides consistent error handling and user feedback across the app.
///
/// Example usage:
/// ```dart
/// try {
///   await apiCall();
/// } catch (e) {
///   ErrorHandler.handle(context, e);
/// }
/// ```
class ErrorHandler {
  /// Handle an error and show appropriate feedback to the user
  ///
  /// [context] - BuildContext for showing SnackBar
  /// [error] - The error to handle
  /// [onUnauthorized] - Optional callback for unauthorized errors
  static void handle(
    BuildContext context,
    dynamic error, {
    VoidCallback? onUnauthorized,
  }) {
    String message = 'حدث خطأ غير متوقع';
    Color backgroundColor = Colors.red;
    IconData icon = Icons.error_outline;

    if (error is ApiException) {
      if (error.isUnauthorized) {
        message = 'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى';
        icon = Icons.lock_outline;

        // Execute callback or navigate to login
        if (onUnauthorized != null) {
          onUnauthorized();
        } else {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
        return;
      } else if (error.isValidationError) {
        message = error.message;
        backgroundColor = Colors.orange;
        icon = Icons.warning_amber_outlined;
      } else if (error.isNotFound) {
        message = 'العنصر المطلوب غير موجود';
        icon = Icons.search_off;
      } else if (error.isServerError) {
        message = 'خطأ في الخادم. يرجى المحاولة لاحقاً';
        icon = Icons.cloud_off;
      } else {
        message = error.message;
      }
    } else if (error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup')) {
      message = 'لا يوجد اتصال بالإنترنت';
      backgroundColor = Colors.grey[700]!;
      icon = Icons.wifi_off;
    } else if (error.toString().contains('TimeoutException') ||
        error.toString().contains('timeout')) {
      message = 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى';
      backgroundColor = Colors.orange;
      icon = Icons.access_time;
    }

    _showSnackBar(
      context,
      message: message,
      backgroundColor: backgroundColor,
      icon: icon,
      isError: true,
    );
  }

  /// Show a success message
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle_outline,
      duration: duration,
    );
  }

  /// Show an info message
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: Colors.blue,
      icon: Icons.info_outline,
      duration: duration,
    );
  }

  /// Show a warning message
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: Colors.orange,
      icon: Icons.warning_amber_outlined,
      duration: duration,
    );
  }

  /// Internal method to show SnackBar
  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'حسناً',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show a dialog for critical errors
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onAction();
              },
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }

  /// Get user-friendly error message from exception
  static String getErrorMessage(dynamic error) {
    if (error is ApiException) {
      return error.message;
    } else if (error.toString().contains('SocketException')) {
      return 'لا يوجد اتصال بالإنترنت';
    } else if (error.toString().contains('TimeoutException')) {
      return 'انتهت مهلة الطلب';
    } else {
      return 'حدث خطأ غير متوقع';
    }
  }

  /// Log error for debugging
  static void logError(String context, dynamic error,
      [StackTrace? stackTrace]) {
    debugPrint('❌ Error in $context: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }
}
