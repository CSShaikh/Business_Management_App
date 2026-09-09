/// Application-wide constants.
///
/// Keep values that are shared across multiple features here.
/// Feature-specific constants should remain inside their respective
/// feature files.
class AppConstants {
  AppConstants._();

  // ============================================================
  // APP INFORMATION
  // ============================================================

  static const String appName = 'Business Management';

  static const String appVersion = '1.0.0';

  // ============================================================
  // DEFAULT VALUES
  // ============================================================

  static const String defaultCurrencySymbol = '₹';

  static const String defaultCurrencyCode = 'INR';

  static const String defaultCountryCode = 'IN';

  // ============================================================
  // PAGINATION / LIST LIMITS
  // ============================================================

  static const int defaultPageSize = 20;

  static const int maxPageSize = 100;

  // ============================================================
  // VALIDATION LIMITS
  // ============================================================

  static const int minBusinessNameLength = 2;

  static const int maxBusinessNameLength = 100;

  static const int minNameLength = 2;

  static const int maxNameLength = 100;

  static const int maxNotesLength = 1000;

  // ============================================================
  // DATE / TIME
  // ============================================================

  static const int millisecondsPerSecond = 1000;

  static const int secondsPerMinute = 60;

  static const int minutesPerHour = 60;

  static const int hoursPerDay = 24;

  // ============================================================
  // FIREBASE COLLECTION NAMES
  // ============================================================

  static const String businessesCollection = 'businesses';

  static const String customersCollection = 'customers';

  static const String suppliersCollection = 'suppliers';

  static const String productsCollection = 'products';

  static const String salesCollection = 'sales';

  static const String purchasesCollection = 'purchases';

  static const String expensesCollection = 'expenses';

  static const String paymentsCollection = 'payments';

  static const String stockTransactionsCollection =
      'stock_transactions';

  static const String ledgerTransactionsCollection =
      'ledger_transactions';

  // ============================================================
  // COMMON STATUS VALUES
  // ============================================================

  static const String activeStatus = 'active';

  static const String inactiveStatus = 'inactive';

  // ============================================================
  // PAYMENT METHODS
  // ============================================================

  static const String cashPaymentMethod = 'Cash';

  static const String upiPaymentMethod = 'UPI';

  static const String bankTransferPaymentMethod =
      'Bank Transfer';

  static const String chequePaymentMethod = 'Cheque';

  static const String otherPaymentMethod = 'Other';

  // ============================================================
  // PAYMENT STATUS
  // ============================================================

  static const String paidStatus = 'Paid';

  static const String partialStatus = 'Partial';

  static const String unpaidStatus = 'Unpaid';
}
