import 'package:intl/intl.dart';

class AppUtils {
  static String formatCurrency(double amount) {
    final format = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  static String formatDate(DateTime date) {
    final format = DateFormat('MMM dd, yyyy');
    return format.format(date);
  }

  static String formatTime(DateTime date) {
    final format = DateFormat('hh:mm a');
    return format.format(date);
  }

  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} at ${formatTime(date)}';
  }

  static String getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    }
    if (hour < 17) {
      return 'Good Afternoon';
    }
    return 'Good Evening';
  }
}
