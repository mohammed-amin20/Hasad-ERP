/// 12-hour time formatting with Arabic AM/PM labels (Western numerals).
abstract final class TimeFormat {
  /// `14:05` → `"2:05 م"`, `09:30` → `"9:30 ص"`.
  static String hour12(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'ص' : 'م';
    return '$hour:$minute $period';
  }
}