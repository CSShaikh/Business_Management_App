class LedgerTransactionModel {
  final String id;
  final String businessId;

  // ---------------------------------------------------------------------------
  // CUSTOMER
  // ---------------------------------------------------------------------------

  /// Existing customer ledger fields.
  ///
  /// These remain backward-compatible with all existing customer transactions.
  /// Supplier transactions leave these fields empty.
  final String customerId;
  final String customerName;

  // ---------------------------------------------------------------------------
  // PARTY TYPE
  // ---------------------------------------------------------------------------

  /// Identifies which type of party owns this ledger transaction.
  ///
  /// Existing Firestore documents created before supplier-ledger support may
  /// not contain this field. Such documents are treated as CUSTOMER.
  final String partyType;

  // ---------------------------------------------------------------------------
  // SUPPLIER
  // ---------------------------------------------------------------------------

  /// Supplier ledger fields.
  ///
  /// Customer transactions leave these fields empty.
  final String supplierId;
  final String supplierName;

  // ---------------------------------------------------------------------------
  // TRANSACTION
  // ---------------------------------------------------------------------------

  final String transactionType;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String referenceId;
  final DateTime date;
  final String notes;
  final DateTime createdAt;

  const LedgerTransactionModel({
    required this.id,
    required this.businessId,

    // Customer fields remain optional for backward compatibility.
    this.customerId = '',
    this.customerName = '',

    // Existing records without partyType are treated as CUSTOMER.
    this.partyType = 'CUSTOMER',

    // Supplier fields.
    this.supplierId = '',
    this.supplierName = '',

    required this.transactionType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.referenceId = '',
    required this.date,
    this.notes = '',
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // PARTY HELPERS
  // ---------------------------------------------------------------------------

  bool get isSupplierLedger {
    return partyType.trim().toUpperCase() == 'SUPPLIER';
  }

  bool get isCustomerLedger {
    return !isSupplierLedger;
  }

  /// Returns the ID of whichever party owns this transaction.
  String get partyId {
    if (isSupplierLedger) {
      return supplierId.trim();
    }

    return customerId.trim();
  }

  /// Returns the name of whichever party owns this transaction.
  String get partyName {
    if (isSupplierLedger) {
      return supplierName.trim();
    }

    return customerName.trim();
  }

  // ---------------------------------------------------------------------------
  // COPY WITH
  // ---------------------------------------------------------------------------

  LedgerTransactionModel copyWith({
    String? id,
    String? businessId,
    String? customerId,
    String? customerName,
    String? partyType,
    String? supplierId,
    String? supplierName,
    String? transactionType,
    double? amount,
    double? balanceBefore,
    double? balanceAfter,
    String? referenceId,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
  }) {
    return LedgerTransactionModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      partyType: partyType ?? this.partyType,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      referenceId: referenceId ?? this.referenceId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}