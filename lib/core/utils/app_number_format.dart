import 'package:intl/intl.dart';

/// App-wide formatting helpers for amounts shown inside the application UI.
///
/// Whole-number amounts are displayed without trailing .00 while meaningful
/// decimal values are preserved (up to two decimal places).
class AppNumberFormat {
  AppNumberFormat._();

  static final NumberFormat _number = NumberFormat(
    '#,##,##0.##',
    'en_IN',
  );

  static String amount(double value, {String symbol = '₹'}) {
    if (!value.isFinite) {
      return '${symbol}0';
    }

    final double normalized = value.abs() < 0.000001 ? 0 : value;
    return '$symbol${_number.format(normalized)}';
  }
}
