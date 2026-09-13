import '../../models/ledger_transaction_model.dart';
import '../../repositories/ledger_repository.dart';

/// Central service for all customer-ledger operations.
///
/// Ledger direction:
///
/// DEBIT  = increases customer outstanding.
/// CREDIT = decreases customer outstanding.
///
/// Supported transaction types:
///
/// SALE
///     Customer owes more because of a sale.
///
/// SALE_PAYMENT
///     Amount already paid as part of a sale.
///
/// SALE_REVERSAL
///     Reversal of a previous sale. Outstanding decreases.
///
/// SALE_PAYMENT_REVERSAL
///     Reversal of the payment that was included in a sale.
///     Outstanding increases again.
///
/// PAYMENT
///     Separate customer payment. Outstanding decreases.
///
/// PAYMENT_REVERSAL
///     Reversal of a separate customer payment.
///     Outstanding increases again.
///
/// Other legacy transaction types are also supported by the existing
/// LedgerRepository / LedgerProvider implementation.
class LedgerService {
  LedgerService({
    LedgerRepository? repository,
  }) : _repository = repository ?? LedgerRepository();

  final LedgerRepository _repository;

  // ===========================================================================
  // TRANSACTION TYPE CONSTANTS
  // ===========================================================================

  /// Increases customer outstanding.
  static const String saleType = 'SALE';

  /// Decreases customer outstanding.
  ///
  /// This represents the amount paid at the time of creating the sale.
  static const String salePaymentType = 'SALE_PAYMENT';

  /// Decreases customer outstanding because a previous sale is reversed.
  static const String saleReversalType = 'SALE_REVERSAL';

  /// Increases customer outstanding because an included sale payment is
  /// reversed.
  static const String salePaymentReversalType =
      'SALE_PAYMENT_REVERSAL';

  /// Decreases customer outstanding because the customer made a separate
  /// payment.
  static const String paymentType = 'PAYMENT';

  /// Increases customer outstanding because a separate payment is reversed.
  static const String paymentReversalType = 'PAYMENT_REVERSAL';

  // ===========================================================================
  // GENERIC CREATE TRANSACTION
  // ===========================================================================

  Future<LedgerTransactionModel> createTransaction({
    required String businessId,
    required String customerId,
    required String customerName,
    required String transactionType,
    required double amount,
    required double balanceBefore,
    required double balanceAfter,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    final String normalizedBusinessId = businessId.trim();

    final String normalizedCustomerId = customerId.trim();

    final String normalizedCustomerName = customerName.trim();

    final String normalizedTransactionType = transactionType.trim();

    final String normalizedReferenceId = referenceId.trim();

    final String normalizedNotes = notes.trim();

    // -------------------------------------------------------------------------
    // VALIDATION
    // -------------------------------------------------------------------------

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedCustomerId.isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    if (normalizedCustomerName.isEmpty) {
      throw ArgumentError(
        'Customer name cannot be empty.',
      );
    }

    if (normalizedTransactionType.isEmpty) {
      throw ArgumentError(
        'Transaction type cannot be empty.',
      );
    }

    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError(
        'Amount must be greater than zero.',
      );
    }

    if (!balanceBefore.isFinite || balanceBefore < 0) {
      throw ArgumentError(
        'Balance before must be a finite non-negative number.',
      );
    }

    if (!balanceAfter.isFinite || balanceAfter < 0) {
      throw ArgumentError(
        'Balance after must be a finite non-negative number.',
      );
    }

    _validateBalanceTransition(
      transactionType: normalizedTransactionType,
      amount: amount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
    );

    final DateTime now = DateTime.now();

    final LedgerTransactionModel transaction =
        LedgerTransactionModel(
      id: '',
      businessId: normalizedBusinessId,
      customerId: normalizedCustomerId,
      customerName: normalizedCustomerName,
      transactionType: normalizedTransactionType,
      amount: amount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      referenceId: normalizedReferenceId,
      date: date ?? now,
      notes: normalizedNotes,
      createdAt: now,
    );

    return _repository.createTransaction(
      transaction,
    );
  }

  // ===========================================================================
  // SALE LEDGER
  // ===========================================================================

  /// Creates the debit entry for a customer sale.
  ///
  /// Example:
  ///
  /// Previous balance = 2,000
  /// Sale             = 5,000
  /// New balance      = 7,000
  ///
  /// The [referenceId] should normally be the SaleModel.id.
  Future<LedgerTransactionModel> createSaleLedgerEntry({
    required String businessId,
    required String customerId,
    required String customerName,
    required double saleAmount,
    required double balanceBefore,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    _validateLedgerInputs(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      amount: saleAmount,
      balanceBefore: balanceBefore,
    );

    final double balanceAfter = balanceBefore + saleAmount;

    return createTransaction(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      transactionType: saleType,
      amount: saleAmount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      referenceId: referenceId,
      date: date,
      notes: notes.isEmpty ? 'Sale recorded.' : notes,
    );
  }

  // ===========================================================================
  // SALE PAYMENT LEDGER
  // ===========================================================================

  /// Creates the credit entry for the amount already paid inside a sale.
  ///
  /// Example:
  ///
  /// Sale debit        = 5,000
  /// Sale payment      = 2,000
  /// Outstanding       = 3,000
  ///
  /// The [referenceId] should normally be the SaleModel.id so both entries
  /// can be found together when the sale is edited or deleted.
  Future<LedgerTransactionModel> createSalePaymentLedgerEntry({
    required String businessId,
    required String customerId,
    required String customerName,
    required double paymentAmount,
    required double balanceBefore,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    _validateLedgerInputs(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      amount: paymentAmount,
      balanceBefore: balanceBefore,
    );

    final double calculatedBalanceAfter =
        balanceBefore - paymentAmount;

    final double balanceAfter =
        calculatedBalanceAfter.abs() <= 0.000001
            ? 0
            : calculatedBalanceAfter;

    return createTransaction(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      transactionType: salePaymentType,
      amount: paymentAmount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      referenceId: referenceId,
      date: date,
      notes: notes.isEmpty
          ? 'Payment received with sale.'
          : notes,
    );
  }

  // ===========================================================================
  // SALE REVERSAL
  // ===========================================================================

  /// Creates the credit entry required when an existing sale is reversed.
  ///
  /// Example:
  ///
  /// Current balance = 7,000
  /// Sale reversed    = 5,000
  /// New balance      = 2,000
  ///
  /// This does not delete the original SALE entry. It creates an auditable
  /// reversal transaction instead.
  Future<LedgerTransactionModel> createSaleReversal({
    required String businessId,
    required String customerId,
    required String customerName,
    required double saleAmount,
    required double balanceBefore,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    _validateLedgerInputs(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      amount: saleAmount,
      balanceBefore: balanceBefore,
    );

    final double calculatedBalanceAfter =
        balanceBefore - saleAmount;

    final double balanceAfter =
        calculatedBalanceAfter.abs() <= 0.000001
            ? 0
            : calculatedBalanceAfter;

    return createTransaction(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      transactionType: saleReversalType,
      amount: saleAmount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      referenceId: referenceId,
      date: date,
      notes: notes.isEmpty ? 'Sale reversed.' : notes,
    );
  }

  // ===========================================================================
  // SALE PAYMENT REVERSAL
  // ===========================================================================

  /// Reverses the payment that was originally included inside a sale.
  ///
  /// Example:
  ///
  /// Current balance = 3,000
  /// Included payment reversed = 2,000
  /// New balance = 5,000
  Future<LedgerTransactionModel> createSalePaymentReversal({
    required String businessId,
    required String customerId,
    required String customerName,
    required double paymentAmount,
    required double balanceBefore,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    _validateLedgerInputs(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      amount: paymentAmount,
      balanceBefore: balanceBefore,
    );

    final double balanceAfter =
        balanceBefore + paymentAmount;

    return createTransaction(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      transactionType: salePaymentReversalType,
      amount: paymentAmount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      referenceId: referenceId,
      date: date,
      notes: notes.isEmpty
          ? 'Sale payment reversed.'
          : notes,
    );
  }

  // ===========================================================================
  // SEPARATE CUSTOMER PAYMENT
  // ===========================================================================

  /// Creates a normal customer payment ledger entry.
  ///
  /// This is used for payments created from the Payments module, not for the
  /// payment already included in a sale.
  Future<LedgerTransactionModel> createPaymentLedgerEntry({
    required String businessId,
    required String customerId,
    required String customerName,
    required double paymentAmount,
    required double balanceBefore,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    _validateLedgerInputs(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      amount: paymentAmount,
      balanceBefore: balanceBefore,
    );

    final double calculatedBalanceAfter =
        balanceBefore - paymentAmount;

    final double balanceAfter =
        calculatedBalanceAfter.abs() <= 0.000001
            ? 0
            : calculatedBalanceAfter;

    return createTransaction(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      transactionType: paymentType,
      amount: paymentAmount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      referenceId: referenceId,
      date: date,
      notes: notes.isEmpty
          ? 'Customer payment received.'
          : notes,
    );
  }

  // ===========================================================================
  // PAYMENT REVERSAL
  // ===========================================================================

  /// Reverses a normal customer payment.
  ///
  /// This is different from SALE_PAYMENT_REVERSAL because this payment was
  /// created independently from the sale.
  Future<LedgerTransactionModel> createPaymentReversal({
    required String businessId,
    required String customerId,
    required String customerName,
    required double paymentAmount,
    required double balanceBefore,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    _validateLedgerInputs(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      amount: paymentAmount,
      balanceBefore: balanceBefore,
    );

    final double balanceAfter =
        balanceBefore + paymentAmount;

    return createTransaction(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      transactionType: paymentReversalType,
      amount: paymentAmount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      referenceId: referenceId,
      date: date,
      notes: notes.isEmpty
          ? 'Customer payment reversed.'
          : notes,
    );
  }

  // ===========================================================================
  // FIND TRANSACTIONS BY REFERENCE
  // ===========================================================================

  /// Returns all ledger transactions associated with a specific reference.
  ///
  /// For sales, the reference will normally be the SaleModel.id.
  ///
  /// For payments, the reference will normally be the PaymentModel.id.
  Future<List<LedgerTransactionModel>>
      getTransactionsByReferenceId({
    required String businessId,
    required String customerId,
    required String referenceId,
  }) async {
    final String normalizedBusinessId = businessId.trim();

    final String normalizedCustomerId = customerId.trim();

    final String normalizedReferenceId = referenceId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedCustomerId.isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    if (normalizedReferenceId.isEmpty) {
      throw ArgumentError(
        'Reference ID cannot be empty.',
      );
    }

    final List<LedgerTransactionModel> transactions =
        await _repository.getCustomerTransactions(
      businessId: normalizedBusinessId,
      customerId: normalizedCustomerId,
    );

    return transactions
        .where(
          (LedgerTransactionModel transaction) =>
              transaction.referenceId.trim() ==
              normalizedReferenceId,
        )
        .toList();
  }

  // ===========================================================================
  // BASIC REPOSITORY ACCESS
  // ===========================================================================

  Future<LedgerTransactionModel?> getTransaction({
    required String businessId,
    required String transactionId,
  }) {
    return _repository.getTransaction(
      businessId: businessId,
      transactionId: transactionId,
    );
  }

  Future<List<LedgerTransactionModel>> getTransactions({
    required String businessId,
  }) {
    return _repository.getTransactions(
      businessId: businessId,
    );
  }

  Stream<List<LedgerTransactionModel>> watchTransactions({
    required String businessId,
  }) {
    return _repository.watchTransactions(
      businessId: businessId,
    );
  }

  Future<List<LedgerTransactionModel>> getCustomerTransactions({
    required String businessId,
    required String customerId,
  }) {
    return _repository.getCustomerTransactions(
      businessId: businessId,
      customerId: customerId,
    );
  }

  Stream<List<LedgerTransactionModel>> watchCustomerTransactions({
    required String businessId,
    required String customerId,
  }) {
    return _repository.watchCustomerTransactions(
      businessId: businessId,
      customerId: customerId,
    );
  }

  Future<List<LedgerTransactionModel>> getTransactionsByType({
    required String businessId,
    required String transactionType,
  }) {
    return _repository.getTransactionsByType(
      businessId: businessId,
      transactionType: transactionType,
    );
  }

  Future<void> updateTransaction(
    LedgerTransactionModel transaction,
  ) {
    return _repository.updateTransaction(
      transaction,
    );
  }

  Future<void> deleteTransaction({
    required String businessId,
    required String transactionId,
  }) {
    return _repository.deleteTransaction(
      businessId: businessId,
      transactionId: transactionId,
    );
  }

  // ===========================================================================
  // BALANCE
  // ===========================================================================

  Future<double> getCustomerBalance({
    required String businessId,
    required String customerId,
  }) {
    return _repository.getCustomerBalance(
      businessId: businessId,
      customerId: customerId,
    );
  }

  Future<double> getTotalReceivable({
    required String businessId,
  }) {
    return _repository.getTotalReceivable(
      businessId: businessId,
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Future<List<LedgerTransactionModel>> searchTransactions({
    required String businessId,
    required String query,
  }) {
    return _repository.searchTransactions(
      businessId: businessId,
      query: query,
    );
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  void _validateLedgerInputs({
    required String businessId,
    required String customerId,
    required String customerName,
    required double amount,
    required double balanceBefore,
  }) {
    final String normalizedBusinessId = businessId.trim();

    final String normalizedCustomerId = customerId.trim();

    final String normalizedCustomerName = customerName.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedCustomerId.isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    if (normalizedCustomerName.isEmpty) {
      throw ArgumentError(
        'Customer name cannot be empty.',
      );
    }

    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError(
        'Amount must be greater than zero.',
      );
    }

    if (!balanceBefore.isFinite || balanceBefore < 0) {
      throw ArgumentError(
        'Previous balance must be a finite non-negative number.',
      );
    }
  }

  // ===========================================================================
  // BALANCE TRANSITION VALIDATION
  // ===========================================================================

  void _validateBalanceTransition({
    required String transactionType,
    required double amount,
    required double balanceBefore,
    required double balanceAfter,
  }) {
    final String type =
        transactionType.trim().toUpperCase();

    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError(
        'Amount must be greater than zero.',
      );
    }

    if (!balanceBefore.isFinite || balanceBefore < 0) {
      throw ArgumentError(
        'Balance before must be a finite non-negative number.',
      );
    }

    if (!balanceAfter.isFinite || balanceAfter < 0) {
      throw ArgumentError(
        'Balance after must be a finite non-negative number.',
      );
    }

    final bool decreasesBalance =
        type == salePaymentType ||
        type == saleReversalType ||
        type == paymentType;

    final bool increasesBalance =
        type == saleType ||
        type == salePaymentReversalType ||
        type == paymentReversalType;

    const double tolerance = 0.000001;

    // -------------------------------------------------------------------------
    // CREDIT TRANSACTIONS
    // -------------------------------------------------------------------------
    //
    // These transactions decrease customer outstanding.
    //
    // A credit can never be larger than the current outstanding balance.
    //
    if (decreasesBalance) {
      if (amount > balanceBefore + tolerance) {
        throw ArgumentError(
          'Transaction amount cannot be greater than the current '
          'customer outstanding balance.',
        );
      }

      final double expectedBalanceAfter =
          balanceBefore - amount;

      if ((balanceAfter - expectedBalanceAfter).abs() >
          tolerance) {
        throw ArgumentError(
          'Invalid ledger balance transition for $type.',
        );
      }

      return;
    }

    // -------------------------------------------------------------------------
    // DEBIT TRANSACTIONS
    // -------------------------------------------------------------------------
    //
    // These transactions increase customer outstanding.
    //
    if (increasesBalance) {
      final double expectedBalanceAfter =
          balanceBefore + amount;

      if ((balanceAfter - expectedBalanceAfter).abs() >
          tolerance) {
        throw ArgumentError(
          'Invalid ledger balance transition for $type.',
        );
      }

      return;
    }

    // -------------------------------------------------------------------------
    // UNKNOWN / LEGACY TRANSACTION TYPES
    // -------------------------------------------------------------------------
    //
    // Unknown legacy transaction types are intentionally not forced into the
    // debit/credit rules above. Their existing behavior remains compatible
    // with the repository and older data.
  }
}