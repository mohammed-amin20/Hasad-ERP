/// Money is stored as integer agorot (₪/¥minor unit) everywhere in the DB.
abstract final class Money {
  static int fromAmount(double amount) => (amount * 100).round();

  static double toAmount(int agorot) => agorot / 100;

  /// Display helper: 1250 → "12.50", 2000 → "20".
  static String format(int agorot) {
    final value = toAmount(agorot);
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}