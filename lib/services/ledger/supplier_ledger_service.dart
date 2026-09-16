import '../../models/ledger_transaction_model.dart';
import '../../models/purchase_model.dart';
import '../../models/supplier_model.dart';
import '../../repositories/ledger_repository.dart';

/// Handles supplier payable ledger operations.
///
/// Supplier balance meaning:
///
///   Positive balance  = Business owes supplier.
///   Zero balance      = Nothing outstanding.
///   Negative balance  = Supplier has an advance/credit balance.
///
/// Purchase:
///   balance increases.
///
/// Supplier payment:
///   balance decreases.
///
/// Purchase reversal:
///   balance decreases.
///
/// Supplier payment reversal:
///   balance increases.
class SupplierLedgerService {
  // ===========================================================================
  // TRANSACTION TYPES
  // ===========================================================================

  static const String purchaseType =
      'PURCHASE';

  static const String purchaseReversalType =
      'PURCHASE_REVERSAL';

  static const String supplierPaymentType =
      'SUPPLIER_PAYMENT';

  static const String supplierPaymentReversalType =
      'SUPPLIER_PAYMENT_REVERSAL';

  // ===========================================================================
  // REPOSITORY
  // ===========================================================================

  final LedgerRepository _repository;

  SupplierLedgerService({
    LedgerRepository? repository,
  }) : _repository =
            repository ?? LedgerRepository();

  // ===========================================================================
  // GET SUPPLIER BALANCE
  // ===========================================================================

  Future<double> getSupplierBalance({
    required String businessId,
    required String supplierId,
  }) {
    return _repository.getSupplierBalance(
      businessId: businessId,
      supplierId: supplierId,
    );
  }

  // ===========================================================================
  // GET SUPPLIER TRANSACTIONS
  // ===========================================================================

  Future<List<LedgerTransactionModel>>
      getSupplierTransactions({
    required String businessId,
    required String supplierId,
  }) {
    return _repository.getSupplierTransactions(
      businessId: businessId,
      supplierId: supplierId,
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
  // TOTAL PAYABLE
  // ===========================================================================

  Future<double> getTotalPayable({
    required String businessId,
  }) {
    return _repository.getTotalPayable(
      businessId: businessId,
    );
  }

  // ===========================================================================
  // PURCHASE → SUPPLIER LEDGER
  // ===========================================================================

  /// Creates a supplier payable entry for the outstanding portion of a
  /// purchase.
  ///
  /// Example:
  ///
  /// Purchase = ₹10,000
  /// Paid     = ₹3,000
  /// Payable  = ₹7,000
  ///
  /// Only ₹7,000 is added to the supplier ledger.
  Future<LedgerTransactionModel>
      createPurchaseLedgerEntry({
    required PurchaseModel purchase,
    required SupplierModel supplier,
  }) async {
    final double outstanding =
        purchase.total -
            purchase.paidAmount;

    if (outstanding <= 0.000001) {
      throw StateError(
        'Purchase has no outstanding supplier amount.',
      );
    }

    return createPurchaseOutstandingEntry(
      businessId:
          purchase.businessId,
      supplierId:
          supplier.id,
      supplierName:
          supplier.name,
      amount:
          outstanding,
      referenceId:
          purchase.id,
      date:
          purchase.date,
      notes:
          'Outstanding payable for purchase ${purchase.id}.',
    );
  }

  // ===========================================================================
  // CREATE PURCHASE OUTSTANDING
  // ===========================================================================

  Future<LedgerTransactionModel>
      createPurchaseOutstandingEntry({
    required String businessId,
    required String supplierId,
    required String supplierName,
    required double amount,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    _validateParty(
      businessId:
          businessId,
      supplierId:
          supplierId,
      supplierName:
          supplierName,
      amount:
          amount,
    );

    final double balanceBefore =
        await getSupplierBalance(
      businessId:
          businessId,
      supplierId:
          supplierId,
    );

    final double balanceAfter =
        balanceBefore + amount;

    return _repository.createTransaction(
      LedgerTransactionModel(
        id: '',
        businessId:
            businessId.trim(),

        partyType:
            'SUPPLIER',

        supplierId:
            supplierId.trim(),

        supplierName:
            supplierName.trim(),

        transactionType:
            purchaseType,

        amount:
            amount,

        balanceBefore:
            balanceBefore,

        balanceAfter:
            balanceAfter,

        referenceId:
            referenceId.trim(),

        date:
            date ?? DateTime.now(),

        notes:
            notes.isEmpty
                ? 'Supplier payable created.'
                : notes,

        createdAt:
            DateTime.now(),
      ),
    );
  }

  // ===========================================================================
  // PURCHASE REVERSAL
  // ===========================================================================

  Future<LedgerTransactionModel>
      createPurchaseReversal({
    required String businessId,
    required String supplierId,
    required String supplierName,
    required double amount,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    _validateParty(
      businessId:
          businessId,
      supplierId:
          supplierId,
      supplierName:
          supplierName,
      amount:
          amount,
    );

    final double balanceBefore =
        await getSupplierBalance(
      businessId:
          businessId,
      supplierId:
          supplierId,
    );

    final double balanceAfter =
        balanceBefore - amount;

    return _repository.createTransaction(
      LedgerTransactionModel(
        id: '',
        businessId:
            businessId.trim(),

        partyType:
            'SUPPLIER',

        supplierId:
            supplierId.trim(),

        supplierName:
            supplierName.trim(),

        transactionType:
            purchaseReversalType,

        amount:
            amount,

        balanceBefore:
            balanceBefore,

        balanceAfter:
            balanceAfter,

        referenceId:
            referenceId.trim(),

        date:
            date ?? DateTime.now(),

        notes:
            notes.isEmpty
                ? 'Supplier payable reversed.'
                : notes,

        createdAt:
            DateTime.now(),
      ),
    );
  }

  // ===========================================================================
  // SUPPLIER PAYMENT
  // ===========================================================================

  /// Creates a supplier payment ledger transaction.
  ///
  /// Example:
  ///
  /// Supplier balance before = ₹7,000
  /// Payment                = ₹3,000
  /// Supplier balance after = ₹4,000
  Future<LedgerTransactionModel>
      createSupplierPaymentLedgerEntry({
    required String businessId,
    required String supplierId,
    required String supplierName,
    required double paymentAmount,
    double? balanceBefore,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    _validateParty(
      businessId:
          businessId,
      supplierId:
          supplierId,
      supplierName:
          supplierName,
      amount:
          paymentAmount,
    );

    final double resolvedBalanceBefore =
        balanceBefore ??
        await getSupplierBalance(
          businessId: businessId,
          supplierId: supplierId,
        );

    if (!resolvedBalanceBefore.isFinite ||
        resolvedBalanceBefore < 0) {
      throw StateError('Supplier outstanding balance is invalid.');
    }

    if (paymentAmount >
        resolvedBalanceBefore + 0.000001) {
      throw StateError(
        'Supplier payment cannot be greater than the outstanding payable.',
      );
    }

    final double balanceAfter =
        (resolvedBalanceBefore - paymentAmount).abs() <= 0.01
            ? 0
            : resolvedBalanceBefore - paymentAmount;

    return _repository.createTransaction(
      LedgerTransactionModel(
        id: '',
        businessId:
            businessId.trim(),

        partyType:
            'SUPPLIER',

        supplierId:
            supplierId.trim(),

        supplierName:
            supplierName.trim(),

        transactionType:
            supplierPaymentType,

        amount:
            paymentAmount,

        balanceBefore:
            resolvedBalanceBefore,

        balanceAfter:
            balanceAfter,

        referenceId:
            referenceId.trim(),

        date:
            date ?? DateTime.now(),

        notes:
            notes.isEmpty
                ? 'Supplier payment made.'
                : notes,

        createdAt:
            DateTime.now(),
      ),
    );
  }

  // ===========================================================================
  // SUPPLIER PAYMENT REVERSAL
  // ===========================================================================

  Future<LedgerTransactionModel>
      createSupplierPaymentReversal({
    required String businessId,
    required String supplierId,
    required String supplierName,
    required double paymentAmount,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    _validateParty(
      businessId:
          businessId,
      supplierId:
          supplierId,
      supplierName:
          supplierName,
      amount:
          paymentAmount,
    );

    final double balanceBefore =
        await getSupplierBalance(
      businessId:
          businessId,
      supplierId:
          supplierId,
    );

    final double balanceAfter =
        balanceBefore + paymentAmount;

    return _repository.createTransaction(
      LedgerTransactionModel(
        id: '',
        businessId:
            businessId.trim(),

        partyType:
            'SUPPLIER',

        supplierId:
            supplierId.trim(),

        supplierName:
            supplierName.trim(),

        transactionType:
            supplierPaymentReversalType,

        amount:
            paymentAmount,

        balanceBefore:
            balanceBefore,

        balanceAfter:
            balanceAfter,

        referenceId:
            referenceId.trim(),

        date:
            date ?? DateTime.now(),

        notes:
            notes.isEmpty
                ? 'Supplier payment reversed.'
                : notes,

        createdAt:
            DateTime.now(),
      ),
    );
  }

  // ===========================================================================
  // REVERSE ACTIVE PURCHASE LEDGER
  // ===========================================================================

  /// Finds the currently active PURCHASE ledger entry for a purchase and
  /// creates exactly one reversal for it.
  ///
  /// This is important when a purchase has been edited multiple times.
  /// Historical PURCHASE entries must not all be reversed again.
  Future<void> reverseActivePurchaseLedger({
    required PurchaseModel purchase,
  }) async {
    final String supplierId =
        purchase.supplierId.trim();

    final String purchaseId =
        purchase.id.trim();

    if (supplierId.isEmpty ||
        purchaseId.isEmpty) {
      return;
    }

    final List<LedgerTransactionModel>
        transactions =
        await getSupplierTransactions(
      businessId:
          purchase.businessId,
      supplierId:
          supplierId,
    );

    final List<LedgerTransactionModel>
        history =
        transactions.where(
      (
        LedgerTransactionModel transaction,
      ) {
        final String type =
            transaction.transactionType
                .trim()
                .toUpperCase();

        return transaction.referenceId
                    .trim() ==
                purchaseId &&
            (type ==
                    purchaseType ||
                type ==
                    purchaseReversalType);
      },
    ).toList();

    if (history.isEmpty) {
      return;
    }

    // Repository returns newest first.
    final LedgerTransactionModel
        latest =
        history.first;

    final String latestType =
        latest.transactionType
            .trim()
            .toUpperCase();

    // Already reversed.
    if (latestType != purchaseType) {
      return;
    }

    if (latest.amount <=
        0.000001) {
      return;
    }

    await createPurchaseReversal(
      businessId:
          purchase.businessId,
      supplierId:
          supplierId,
      supplierName:
          purchase.supplierName,
      amount:
          latest.amount,
      referenceId:
          purchaseId,
      date:
          DateTime.now(),
      notes:
          'Reversal for purchase $purchaseId.',
    );
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  void _validateParty({
    required String businessId,
    required String supplierId,
    required String supplierName,
    required double amount,
  }) {
    if (businessId.trim().isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (supplierId.trim().isEmpty) {
      throw ArgumentError(
        'Supplier ID cannot be empty.',
      );
    }

    if (supplierName.trim().isEmpty) {
      throw ArgumentError(
        'Supplier name cannot be empty.',
      );
    }

    if (!amount.isFinite ||
        amount <= 0) {
      throw ArgumentError(
        'Amount must be greater than zero.',
      );
    }
  }
}