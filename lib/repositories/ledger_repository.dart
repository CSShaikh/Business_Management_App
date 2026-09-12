import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constant.dart';
import '../models/ledger_transaction_model.dart';
import 'base_repository.dart';

class LedgerRepository extends BaseRepository {
  LedgerRepository({
    super.firestore,
  });

  // ===========================================================================
  // LEDGER COLLECTION
  // ===========================================================================

  CollectionReference<Map<String, dynamic>> _ledger(
    String businessId,
  ) {
    final String normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    return firestore
        .collection(
          AppConstants.businessesCollection,
        )
        .doc(
          normalizedBusinessId,
        )
        .collection(
          AppConstants.ledgerTransactionsCollection,
        );
  }

  // ===========================================================================
  // CREATE
  // ===========================================================================

  Future<LedgerTransactionModel> createTransaction(
    LedgerTransactionModel transaction,
  ) async {
    _validateTransaction(
      transaction,
      requireId: false,
    );

    final String businessId =
        transaction.businessId.trim();

    final CollectionReference<Map<String, dynamic>>
        collectionRef =
        _ledger(
      businessId,
    );

    final DocumentReference<Map<String, dynamic>>
        documentRef =
        transaction.id.trim().isEmpty
            ? collectionRef.doc()
            : collectionRef.doc(
                transaction.id.trim(),
              );

    final LedgerTransactionModel
        transactionToSave =
        transaction.copyWith(
      id: documentRef.id,
      businessId: businessId,
      customerId:
          transaction.customerId.trim(),
      customerName:
          transaction.customerName.trim(),
      partyType:
          _normalizePartyType(
        transaction.partyType,
      ),
      supplierId:
          transaction.supplierId.trim(),
      supplierName:
          transaction.supplierName.trim(),
      transactionType:
          transaction.transactionType.trim(),
      referenceId:
          transaction.referenceId.trim(),
      notes:
          transaction.notes.trim(),
    );

    await documentRef.set(
      _toMap(
        transactionToSave,
      ),
    );

    return transactionToSave;
  }

  // ===========================================================================
  // GET SINGLE TRANSACTION
  // ===========================================================================

  Future<LedgerTransactionModel?> getTransaction({
    required String businessId,
    required String transactionId,
  }) async {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedTransactionId =
        transactionId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedTransactionId.isEmpty) {
      throw ArgumentError(
        'Transaction ID cannot be empty.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>>
        snapshot =
        await _ledger(
      normalizedBusinessId,
    ).doc(
      normalizedTransactionId,
    ).get();

    if (!snapshot.exists) {
      return null;
    }

    final Map<String, dynamic>? data =
        snapshot.data();

    if (data == null) {
      return null;
    }

    return _fromMap(
      snapshot.id,
      data,
      fallbackBusinessId:
          normalizedBusinessId,
    );
  }

  // ===========================================================================
  // GET ALL TRANSACTIONS
  // ===========================================================================

  Future<List<LedgerTransactionModel>>
      getTransactions({
    required String businessId,
  }) async {
    final String normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    final QuerySnapshot<Map<String, dynamic>>
        snapshot =
        await _ledger(
      normalizedBusinessId,
    ).orderBy(
      'date',
      descending: true,
    ).get();

    return snapshot.docs
        .map(
          (
            QueryDocumentSnapshot<
                Map<String, dynamic>> doc,
          ) =>
              _fromMap(
            doc.id,
            doc.data(),
            fallbackBusinessId:
                normalizedBusinessId,
          ),
        )
        .toList();
  }

  // ===========================================================================
  // WATCH ALL TRANSACTIONS
  // ===========================================================================

  Stream<List<LedgerTransactionModel>>
      watchTransactions({
    required String businessId,
  }) {
    final String normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    return _ledger(
      normalizedBusinessId,
    ).orderBy(
      'date',
      descending: true,
    ).snapshots().map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        return snapshot.docs
            .map(
              (
                QueryDocumentSnapshot<
                    Map<String, dynamic>> doc,
              ) =>
                  _fromMap(
                doc.id,
                doc.data(),
                fallbackBusinessId:
                    normalizedBusinessId,
              ),
            )
            .toList();
      },
    );
  }

  // ===========================================================================
  // CUSTOMER TRANSACTIONS
  // ===========================================================================

  Future<List<LedgerTransactionModel>>
      getCustomerTransactions({
    required String businessId,
    required String customerId,
  }) async {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedCustomerId =
        customerId.trim();

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

    final QuerySnapshot<Map<String, dynamic>>
        snapshot =
        await _ledger(
      normalizedBusinessId,
    ).where(
      'customerId',
      isEqualTo: normalizedCustomerId,
    ).orderBy(
      'date',
      descending: true,
    ).get();

    return snapshot.docs
        .map(
          (
            QueryDocumentSnapshot<
                Map<String, dynamic>> doc,
          ) =>
              _fromMap(
            doc.id,
            doc.data(),
            fallbackBusinessId:
                normalizedBusinessId,
          ),
        )
        .toList();
  }

  Stream<List<LedgerTransactionModel>>
      watchCustomerTransactions({
    required String businessId,
    required String customerId,
  }) {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedCustomerId =
        customerId.trim();

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

    return _ledger(
      normalizedBusinessId,
    ).where(
      'customerId',
      isEqualTo: normalizedCustomerId,
    ).orderBy(
      'date',
      descending: true,
    ).snapshots().map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        return snapshot.docs
            .map(
              (
                QueryDocumentSnapshot<
                    Map<String, dynamic>> doc,
              ) =>
                  _fromMap(
                doc.id,
                doc.data(),
                fallbackBusinessId:
                    normalizedBusinessId,
              ),
            )
            .toList();
      },
    );
  }

  // ===========================================================================
  // SUPPLIER TRANSACTIONS
  // ===========================================================================

  Future<List<LedgerTransactionModel>>
      getSupplierTransactions({
    required String businessId,
    required String supplierId,
  }) async {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedSupplierId =
        supplierId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedSupplierId.isEmpty) {
      throw ArgumentError(
        'Supplier ID cannot be empty.',
      );
    }

    final QuerySnapshot<Map<String, dynamic>>
        snapshot =
        await _ledger(
      normalizedBusinessId,
    ).where(
      'supplierId',
      isEqualTo: normalizedSupplierId,
    ).orderBy(
      'date',
      descending: true,
    ).get();

    return snapshot.docs
        .map(
          (
            QueryDocumentSnapshot<
                Map<String, dynamic>> doc,
          ) =>
              _fromMap(
            doc.id,
            doc.data(),
            fallbackBusinessId:
                normalizedBusinessId,
          ),
        )
        .toList();
  }

  Stream<List<LedgerTransactionModel>>
      watchSupplierTransactions({
    required String businessId,
    required String supplierId,
  }) {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedSupplierId =
        supplierId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedSupplierId.isEmpty) {
      throw ArgumentError(
        'Supplier ID cannot be empty.',
      );
    }

    return _ledger(
      normalizedBusinessId,
    ).where(
      'supplierId',
      isEqualTo: normalizedSupplierId,
    ).orderBy(
      'date',
      descending: true,
    ).snapshots().map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        return snapshot.docs
            .map(
              (
                QueryDocumentSnapshot<
                    Map<String, dynamic>> doc,
              ) =>
                  _fromMap(
                doc.id,
                doc.data(),
                fallbackBusinessId:
                    normalizedBusinessId,
              ),
            )
            .toList();
      },
    );
  }

  // ===========================================================================
  // TRANSACTIONS BY TYPE
  // ===========================================================================

  Future<List<LedgerTransactionModel>>
      getTransactionsByType({
    required String businessId,
    required String transactionType,
  }) async {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedTransactionType =
        transactionType.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedTransactionType.isEmpty) {
      throw ArgumentError(
        'Transaction type cannot be empty.',
      );
    }

    final QuerySnapshot<Map<String, dynamic>>
        snapshot =
        await _ledger(
      normalizedBusinessId,
    ).where(
      'transactionType',
      isEqualTo: normalizedTransactionType,
    ).orderBy(
      'date',
      descending: true,
    ).get();

    return snapshot.docs
        .map(
          (
            QueryDocumentSnapshot<
                Map<String, dynamic>> doc,
          ) =>
              _fromMap(
            doc.id,
            doc.data(),
            fallbackBusinessId:
                normalizedBusinessId,
          ),
        )
        .toList();
  }

  // ===========================================================================
  // UPDATE
  // ===========================================================================

  Future<void> updateTransaction(
    LedgerTransactionModel transaction,
  ) async {
    _validateTransaction(
      transaction,
      requireId: true,
    );

    final String transactionId =
        transaction.id.trim();

    final String businessId =
        transaction.businessId.trim();

    final DocumentReference<Map<String, dynamic>>
        documentRef =
        _ledger(
      businessId,
    ).doc(
      transactionId,
    );

    final DocumentSnapshot<Map<String, dynamic>>
        existingDocument =
        await documentRef.get();

    if (!existingDocument.exists) {
      throw StateError(
        'Ledger transaction not found.',
      );
    }

    final Map<String, dynamic>? existingData =
        existingDocument.data();

    if (existingData == null) {
      throw StateError(
        'Ledger transaction data not found.',
      );
    }

    final LedgerTransactionModel
        existingTransaction =
        _fromMap(
      existingDocument.id,
      existingData,
      fallbackBusinessId:
          businessId,
    );

    final LedgerTransactionModel
        updatedTransaction =
        transaction.copyWith(
      id: existingTransaction.id,
      businessId: businessId,
      customerId:
          transaction.customerId.trim(),
      customerName:
          transaction.customerName.trim(),
      partyType:
          _normalizePartyType(
        transaction.partyType,
      ),
      supplierId:
          transaction.supplierId.trim(),
      supplierName:
          transaction.supplierName.trim(),
      transactionType:
          transaction.transactionType.trim(),
      referenceId:
          transaction.referenceId.trim(),
      notes:
          transaction.notes.trim(),
      createdAt:
          existingTransaction.createdAt,
    );

    await documentRef.update(
      _toMap(
        updatedTransaction,
      ),
    );
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  Future<void> deleteTransaction({
    required String businessId,
    required String transactionId,
  }) async {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedTransactionId =
        transactionId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedTransactionId.isEmpty) {
      throw ArgumentError(
        'Transaction ID cannot be empty.',
      );
    }

    final DocumentReference<Map<String, dynamic>>
        documentRef =
        _ledger(
      normalizedBusinessId,
    ).doc(
      normalizedTransactionId,
    );

    final DocumentSnapshot<Map<String, dynamic>>
        document =
        await documentRef.get();

    if (!document.exists) {
      throw StateError(
        'Ledger transaction not found.',
      );
    }

    await documentRef.delete();
  }

  // ===========================================================================
  // CUSTOMER BALANCE
  // ===========================================================================

  Future<double> getCustomerBalance({
    required String businessId,
    required String customerId,
  }) async {
    final List<LedgerTransactionModel>
        transactions =
        await getCustomerTransactions(
      businessId: businessId,
      customerId: customerId,
    );

    if (transactions.isEmpty) {
      return 0;
    }

    return transactions.first.balanceAfter;
  }

  // ===========================================================================
  // SUPPLIER BALANCE
  // ===========================================================================

  Future<double> getSupplierBalance({
    required String businessId,
    required String supplierId,
  }) async {
    final List<LedgerTransactionModel>
        transactions =
        await getSupplierTransactions(
      businessId: businessId,
      supplierId: supplierId,
    );

    if (transactions.isEmpty) {
      return 0;
    }

    return transactions.first.balanceAfter;
  }

  // ===========================================================================
  // TOTAL CUSTOMER RECEIVABLE
  // ===========================================================================

  Future<double> getTotalReceivable({
    required String businessId,
  }) async {
    final List<LedgerTransactionModel>
        transactions =
        await getTransactions(
      businessId: businessId,
    );

    if (transactions.isEmpty) {
      return 0;
    }

    final Map<String, double>
        customerBalances =
        <String, double>{};

    for (final LedgerTransactionModel
        transaction in transactions) {
      if (!transaction.isCustomerLedger) {
        continue;
      }

      final String customerId =
          transaction.customerId.trim();

      if (customerId.isEmpty) {
        continue;
      }

      customerBalances[customerId] =
          transaction.balanceAfter;
    }

    return customerBalances.values.fold<double>(
      0,
      (
        double total,
        double balance,
      ) {
        if (balance > 0) {
          return total + balance;
        }

        return total;
      },
    );
  }

  // ===========================================================================
  // TOTAL SUPPLIER PAYABLE
  // ===========================================================================

  Future<double> getTotalPayable({
    required String businessId,
  }) async {
    final List<LedgerTransactionModel>
        transactions =
        await getTransactions(
      businessId: businessId,
    );

    if (transactions.isEmpty) {
      return 0;
    }

    final Map<String, double>
        supplierBalances =
        <String, double>{};

    for (final LedgerTransactionModel
        transaction in transactions) {
      if (!transaction.isSupplierLedger) {
        continue;
      }

      final String supplierId =
          transaction.supplierId.trim();

      if (supplierId.isEmpty) {
        continue;
      }

      supplierBalances[supplierId] =
          transaction.balanceAfter;
    }

    return supplierBalances.values.fold<double>(
      0,
      (
        double total,
        double balance,
      ) {
        if (balance > 0) {
          return total + balance;
        }

        return total;
      },
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Future<List<LedgerTransactionModel>>
      searchTransactions({
    required String businessId,
    required String query,
  }) async {
    final String normalizedQuery =
        query.trim().toLowerCase();

    final List<LedgerTransactionModel>
        transactions =
        await getTransactions(
      businessId: businessId,
    );

    if (normalizedQuery.isEmpty) {
      return transactions;
    }

    return transactions.where(
      (
        LedgerTransactionModel transaction,
      ) {
        final String partyName =
            transaction.partyName.toLowerCase();

        final String partyId =
            transaction.partyId.toLowerCase();

        final String transactionType =
            transaction.transactionType
                .toLowerCase();

        final String referenceId =
            transaction.referenceId
                .toLowerCase();

        final String notes =
            transaction.notes.toLowerCase();

        final String amount =
            transaction.amount
                .toStringAsFixed(2);

        return partyName.contains(
              normalizedQuery,
            ) ||
            partyId.contains(
              normalizedQuery,
            ) ||
            transactionType.contains(
              normalizedQuery,
            ) ||
            referenceId.contains(
              normalizedQuery,
            ) ||
            notes.contains(
              normalizedQuery,
            ) ||
            amount.contains(
              normalizedQuery,
            );
      },
    ).toList();
  }

  // ===========================================================================
  // FIRESTORE MAP
  // ===========================================================================

  Map<String, dynamic> _toMap(
    LedgerTransactionModel transaction,
  ) {
    return <String, dynamic>{
      'id': transaction.id.trim(),
      'businessId':
          transaction.businessId.trim(),

      // Existing customer fields.
      'customerId':
          transaction.customerId.trim(),
      'customerName':
          transaction.customerName.trim(),

      // New party information.
      'partyType':
          _normalizePartyType(
        transaction.partyType,
      ),

      // Supplier fields.
      'supplierId':
          transaction.supplierId.trim(),
      'supplierName':
          transaction.supplierName.trim(),

      'transactionType':
          transaction.transactionType.trim(),
      'amount':
          transaction.amount,
      'balanceBefore':
          transaction.balanceBefore,
      'balanceAfter':
          transaction.balanceAfter,
      'referenceId':
          transaction.referenceId.trim(),
      'date':
          Timestamp.fromDate(
        transaction.date,
      ),
      'notes':
          transaction.notes.trim(),
      'createdAt':
          Timestamp.fromDate(
        transaction.createdAt,
      ),
    };
  }

  // ===========================================================================
  // FROM FIRESTORE
  // ===========================================================================

  LedgerTransactionModel _fromMap(
    String documentId,
    Map<String, dynamic> data, {
    String fallbackBusinessId = '',
  }) {
    final String rawId =
        _string(
      data['id'],
    );

    final String rawBusinessId =
        _string(
      data['businessId'],
    );

    final String partyType =
        _normalizePartyType(
      _string(
        data['partyType'],
      ),
    );

    return LedgerTransactionModel(
      id: rawId.isEmpty
          ? documentId
          : rawId,
      businessId: rawBusinessId.isEmpty
          ? fallbackBusinessId.trim()
          : rawBusinessId,

      customerId:
          _string(
        data['customerId'],
      ),

      customerName:
          _string(
        data['customerName'],
      ),

      partyType:
          partyType,

      supplierId:
          _string(
        data['supplierId'],
      ),

      supplierName:
          _string(
        data['supplierName'],
      ),

      transactionType:
          _string(
        data['transactionType'],
      ),

      amount:
          _toDouble(
        data['amount'],
      ),

      balanceBefore:
          _toDouble(
        data['balanceBefore'],
      ),

      balanceAfter:
          _toDouble(
        data['balanceAfter'],
      ),

      referenceId:
          _string(
        data['referenceId'],
      ),

      date:
          dateFromFirestore(
        data['date'],
      ),

      notes:
          _string(
        data['notes'],
      ),

      createdAt:
          dateFromFirestore(
        data['createdAt'],
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _string(
    dynamic value,
  ) {
    return value?.toString().trim() ?? '';
  }

  String _normalizePartyType(
    String value,
  ) {
    if (value.trim().toUpperCase() ==
        'SUPPLIER') {
      return 'SUPPLIER';
    }

    return 'CUSTOMER';
  }

  double _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      final double result =
          value.toDouble();

      return result.isFinite
          ? result
          : 0;
    }

    if (value is String) {
      final double? result =
          double.tryParse(
        value.trim(),
      );

      if (result != null &&
          result.isFinite) {
        return result;
      }
    }

    return 0;
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  void _validateTransaction(
    LedgerTransactionModel transaction, {
    required bool requireId,
  }) {
    if (transaction.businessId
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (requireId &&
        transaction.id
            .trim()
            .isEmpty) {
      throw ArgumentError(
        'Transaction ID cannot be empty.',
      );
    }

    final bool isSupplier =
        _normalizePartyType(
          transaction.partyType,
        ) ==
        'SUPPLIER';

    final String partyId =
        isSupplier
            ? transaction.supplierId
            : transaction.customerId;

    final String partyName =
        isSupplier
            ? transaction.supplierName
            : transaction.customerName;

    if (partyId.trim().isEmpty) {
      throw ArgumentError(
        '${isSupplier ? 'Supplier' : 'Customer'} ID cannot be empty.',
      );
    }

    if (partyName.trim().isEmpty) {
      throw ArgumentError(
        '${isSupplier ? 'Supplier' : 'Customer'} name cannot be empty.',
      );
    }

    if (transaction.transactionType
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'Transaction type cannot be empty.',
      );
    }

    if (!transaction.amount.isFinite ||
        transaction.amount <= 0) {
      throw ArgumentError(
        'Transaction amount must be greater than zero.',
      );
    }

    if (!transaction.balanceBefore.isFinite) {
      throw ArgumentError(
        'Balance before must be a valid number.',
      );
    }

    if (!transaction.balanceAfter.isFinite) {
      throw ArgumentError(
        'Balance after must be a valid number.',
      );
    }
  }
}