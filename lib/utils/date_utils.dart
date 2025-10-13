/// Utility functions for date formatting
class DateUtils {
  /// Format a date relative to now (e.g., "2h ago", "Yesterday", "15/3/2024")
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    // Normalize dates to compare calendar days (ignoring time)
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final daysDifference = today.difference(dateDay).inDays;

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (daysDifference == 0) {
      // Same calendar day
      return '${difference.inHours}h ago';
    } else if (daysDifference == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (daysDifference < 7) {
      // Within the last week
      return '${daysDifference}d ago';
    } else {
      // Older than a week
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Format time for minimalistic view (e.g., "now", "2h", "yesterday")
  static String formatMinimalisticTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    // Normalize dates to compare calendar days (ignoring time)
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final daysDifference = today.difference(dateDay).inDays;

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (daysDifference == 0) {
      // Same calendar day
      return '${difference.inHours}h';
    } else if (daysDifference == 1) {
      // Yesterday
      return 'yesterday';
    } else if (daysDifference < 7) {
      // Within the last week
      return '${daysDifference}d';
    } else {
      // Older than a week
      return '${date.day}/${date.month}';
    }
  }
}

