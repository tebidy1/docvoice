import 'package:intl/intl.dart';

class DateHelper {
  static String formatGroupingDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return "Today";
    } else if (checkDate == yesterday) {
      return "Yesterday";
    } else {
      return DateFormat('MMMM d, y').format(date);
    }
  }

  static bool isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return false;
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }
}
