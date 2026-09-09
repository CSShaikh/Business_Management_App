import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ledger_transaction_model.dart';
import '../repositories/ledger_repository.dart';

class LedgerProvider extends ChangeNotifier {
  LedgerProvider({
    LedgerRepository? repository,
  }) : _repository = repository ?? LedgerRepository();

  final LedgerRepository _repository;

  // ===========================================================================
  // STATE
  // ===========================================================================

  List<LedgerTransactionModel> _transactions =
      <LedgerTransactionModel>[];

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;

  String _businessId = '';
  String _customerId = '';

  StreamSubscription<List<LedgerTransactionModel>>?
      _transactionsSubscription;

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  List<LedgerTransactionModel> get transactions =>
      List<LedgerTransactionModel>.unmodifiable(
        _transactions,
      );

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get hasTransactions => _transactions.isNotEmpty;

  bool get isEmpty => _transactions.isEmpty;

  String? get errorMessage => _errorMessage;

  String get businessId => _businessId;

  String get customerId => _customerId;

  int get transactionCount => _transactions.length;

  // ---------------------------------------------------------------------------
  // Debit / Credit totals
  // ---------------------------------------------------------------------------

  double get totalDebit {
    double total = 0;

    for (final LedgerTransactionModel transaction
        in _transactions) {
      if (_isDebit(transaction.transactionType)) {
        total += transaction.amount;
      }
    }

    return total;
  }

  double get totalCredit {
    double total = 0;

    for (final LedgerTransactionModel transaction
        in _transactions) {
      if (!_isDebit(transaction.transactionType)) {
        total += transaction.amount;
      }
    }

    return total;
  }

  double get totalAmount {
    double total = 0;

    for (final LedgerTransactionModel transaction
        in _transactions) {
      total += transaction.amount;
    }

    return total;
  }

  double get currentBalance {
    if (_transactions.isEmpty) {
      return 0;
    }

    final List<LedgerTransactionModel> sorted =
        List<LedgerTransactionModel>.from(
      _transactions,
    )..sort(
        (LedgerTransactionModel a,
                LedgerTransactionModel b) =>
            a.date.compareTo(b.date),
      );

    return sorted.last.balanceAfter;
  }

  LedgerTransactionModel? get latestTransaction {
    if (_transactions.isEmpty) {
      return null;
    }

    LedgerTransactionModel latest =
        _transactions.first;

    for (final LedgerTransactionModel transaction
        in _transactions.skip(1)) {
      if (transaction.date.isAfter(latest.date)) {
        latest = transaction;
      }
    }

    return latest;
  }

  // ===========================================================================
  // CONTEXT
  // ===========================================================================

  void setBusinessId(String businessId) {
    final String normalizedId = businessId.trim();

    if (_businessId == normalizedId) {
      return;
    }

    _businessId = normalizedId;
    notifyListeners();
  }

  void setCustomerId(String customerId) {
    final String normalizedId = customerId.trim();

    if (_customerId == normalizedId) {
      return;
    }

    _customerId = normalizedId;
    notifyListeners();
  }

  void setContext({
    required String businessId,
    required String customerId,
  }) {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedCustomerId =
        customerId.trim();

    bool changed = false;

    if (_businessId != normalizedBusinessId) {
      _businessId = normalizedBusinessId;
      changed = true;
    }

    if (_customerId != normalizedCustomerId) {
      _customerId = normalizedCustomerId;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  // ===========================================================================
  // LOAD CUSTOMER TRANSACTIONS
  // ===========================================================================

  Future<List<LedgerTransactionModel>>
      loadCustomerTransactions({
    required String businessId,
    required String customerId,
  }) async {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedCustomerId =
        customerId.trim();

    if (normalizedBusinessId.isEmpty) {
      _setError('Business ID is required.');
      return <LedgerTransactionModel>[];
    }

    if (normalizedCustomerId.isEmpty) {
      _setError('Customer ID is required.');
      return <LedgerTransactionModel>[];
    }

    _businessId = normalizedBusinessId;
    _customerId = normalizedCustomerId;

    _setLoading(true);
    _clearError();

    try {
      final List<LedgerTransactionModel> result =
          await _repository.getCustomerTransactions(
        businessId: normalizedBusinessId,
        customerId: normalizedCustomerId,
      );

      _transactions =
          List<LedgerTransactionModel>.from(result)
            ..sort(
              (
                LedgerTransactionModel a,
                LedgerTransactionModel b,
              ) =>
                  b.date.compareTo(a.date),
            );

      notifyListeners();

      return List<LedgerTransactionModel>.unmodifiable(
        _transactions,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to load customer ledger.',
        ),
      );

      return <LedgerTransactionModel>[];
    } finally {
      _setLoading(false);
    }
  }

  // ===========================================================================
  // WATCH CUSTOMER TRANSACTIONS
  // ===========================================================================

  void watchCustomerTransactions({
    required String businessId,
    required String customerId,
  }) {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedCustomerId =
        customerId.trim();

    if (normalizedBusinessId.isEmpty) {
      _setError('Business ID is required.');
      return;
    }

    if (normalizedCustomerId.isEmpty) {
      _setError('Customer ID is required.');
      return;
    }

    _businessId = normalizedBusinessId;
    _customerId = normalizedCustomerId;

    _transactionsSubscription?.cancel();

    _clearError();

    _transactionsSubscription =
        _repository.watchCustomerTransactions(
      businessId: normalizedBusinessId,
      customerId: normalizedCustomerId,
    ).listen(
      (
        List<LedgerTransactionModel> result,
      ) {
        _transactions =
            List<LedgerTransactionModel>.from(result)
              ..sort(
                (
                  LedgerTransactionModel a,
                  LedgerTransactionModel b,
                ) =>
                    b.date.compareTo(a.date),
              );

        notifyListeners();
      },
      onError: (Object error) {
        _setError(
          _formatError(
            error,
            fallback:
                'Unable to listen for ledger updates.',
          ),
        );
      },
    );
  }

  // ===========================================================================
  // LOAD + WATCH
  // ===========================================================================

  Future<void> loadAndWatchCustomerTransactions({
    required String businessId,
    required String customerId,
  }) async {
    await loadCustomerTransactions(
      businessId: businessId,
      customerId: customerId,
    );

    watchCustomerTransactions(
      businessId: businessId,
      customerId: customerId,
    );
  }

  // ===========================================================================
  // CREATE TRANSACTION
  // ===========================================================================

  Future<LedgerTransactionModel?> createTransaction({
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
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedCustomerId =
        customerId.trim();

    final String normalizedCustomerName =
        customerName.trim();

    final String normalizedTransactionType =
        transactionType.trim();

    if (normalizedBusinessId.isEmpty) {
      _setError('Business ID is required.');
      return null;
    }

    if (normalizedCustomerId.isEmpty) {
      _setError('Customer ID is required.');
      return null;
    }

    if (normalizedCustomerName.isEmpty) {
      _setError('Customer name is required.');
      return null;
    }

    if (normalizedTransactionType.isEmpty) {
      _setError('Transaction type is required.');
      return null;
    }

    if (!amount.isFinite || amount < 0) {
      _setError('Transaction amount is invalid.');
      return null;
    }

    if (!balanceBefore.isFinite) {
      _setError('Previous balance is invalid.');
      return null;
    }

    if (!balanceAfter.isFinite) {
      _setError('New balance is invalid.');
      return null;
    }

    _businessId = normalizedBusinessId;
    _customerId = normalizedCustomerId;

    _setSaving(true);
    _clearError();

    try {
      final DateTime transactionDate =
          date ?? DateTime.now();

      final LedgerTransactionModel transaction =
          LedgerTransactionModel(
        id: '',
        businessId: normalizedBusinessId,
        customerId: normalizedCustomerId,
        customerName: normalizedCustomerName,
        transactionType:
            normalizedTransactionType,
        amount: amount,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        referenceId: referenceId.trim(),
        date: transactionDate,
        notes: notes.trim(),
        createdAt: DateTime.now(),
      );

      // IMPORTANT:
      // LedgerRepository.createTransaction()
      // accepts LedgerTransactionModel as a
      // positional argument.
      final LedgerTransactionModel savedTransaction =
          await _repository.createTransaction(
        transaction,
      );

      _upsertLocalTransaction(
        savedTransaction,
      );

      return savedTransaction;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to create ledger transaction.',
        ),
      );

      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ===========================================================================
  // CUSTOMER BALANCE
  // ===========================================================================

  Future<double> getCustomerBalance({
    required String businessId,
    required String customerId,
  }) async {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedCustomerId =
        customerId.trim();

    if (normalizedBusinessId.isEmpty) {
      _setError('Business ID is required.');
      return 0;
    }

    if (normalizedCustomerId.isEmpty) {
      _setError('Customer ID is required.');
      return 0;
    }

    try {
      final double balance =
          await _repository.getCustomerBalance(
        businessId: normalizedBusinessId,
        customerId: normalizedCustomerId,
      );

      if (!balance.isFinite) {
        return 0;
      }

      return balance;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback:
              'Unable to load customer balance.',
        ),
      );

      return 0;
    }
  }

  // ===========================================================================
  // FILTER BY TRANSACTION TYPE
  // ===========================================================================

  List<LedgerTransactionModel>
      filterByTransactionType(
    String transactionType,
  ) {
    final String query =
        transactionType.trim().toLowerCase();

    if (query.isEmpty) {
      return transactions;
    }

    return _transactions
        .where(
          (LedgerTransactionModel transaction) =>
              transaction.transactionType
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
  }

  // ===========================================================================
  // FILTER BY DATE RANGE
  // ===========================================================================

  List<LedgerTransactionModel> filterByDateRange({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    DateTime? start;
    DateTime? end;

    if (startDate != null) {
      start = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
    }

    if (endDate != null) {
      end = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      );
    }

    return _transactions.where(
      (LedgerTransactionModel transaction) {
        if (start != null &&
            transaction.date.isBefore(start)) {
          return false;
        }

        if (end != null &&
            transaction.date.isAfter(end)) {
          return false;
        }

        return true;
      },
    ).toList();
  }

  // ===========================================================================
  // FIND TRANSACTION
  // ===========================================================================

  LedgerTransactionModel? findTransactionById(
    String transactionId,
  ) {
    final String id = transactionId.trim();

    if (id.isEmpty) {
      return null;
    }

    for (final LedgerTransactionModel transaction
        in _transactions) {
      if (transaction.id == id) {
        return transaction;
      }
    }

    return null;
  }

  // ===========================================================================
  // DEBIT TRANSACTIONS
  // ===========================================================================

  List<LedgerTransactionModel> get debitTransactions {
    return _transactions
        .where(
          (LedgerTransactionModel transaction) =>
              _isDebit(transaction.transactionType),
        )
        .toList();
  }

  // ===========================================================================
  // CREDIT TRANSACTIONS
  // ===========================================================================

  List<LedgerTransactionModel> get creditTransactions {
    return _transactions
        .where(
          (LedgerTransactionModel transaction) =>
              !_isDebit(transaction.transactionType),
        )
        .toList();
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  List<LedgerTransactionModel> searchTransactions(
    String query,
  ) {
    final String normalizedQuery =
        query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return transactions;
    }

    return _transactions
        .where(
          (LedgerTransactionModel transaction) {
            return transaction.customerName
                    .toLowerCase()
                    .contains(normalizedQuery) ||
                transaction.transactionType
                    .toLowerCase()
                    .contains(normalizedQuery) ||
                transaction.referenceId
                    .toLowerCase()
                    .contains(normalizedQuery) ||
                transaction.notes
                    .toLowerCase()
                    .contains(normalizedQuery) ||
                transaction.amount
                    .toString()
                    .contains(normalizedQuery);
          },
        )
        .toList();
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<List<LedgerTransactionModel>> refresh() async {
    if (_businessId.isEmpty ||
        _customerId.isEmpty) {
      return transactions;
    }

    return loadCustomerTransactions(
      businessId: _businessId,
      customerId: _customerId,
    );
  }

  // ===========================================================================
  // CLEAR
  // ===========================================================================

  void clearTransactions() {
    _transactionsSubscription?.cancel();
    _transactionsSubscription = null;

    _transactions =
        <LedgerTransactionModel>[];

    _businessId = '';
    _customerId = '';

    _clearError();

    notifyListeners();
  }

  // ===========================================================================
  // CLEAR ONLY ERROR
  // ===========================================================================

  void clearError() {
    _clearError();
  }

  // ===========================================================================
  // LOCAL UPSERT
  // ===========================================================================

  void _upsertLocalTransaction(
    LedgerTransactionModel transaction,
  ) {
    final String id = transaction.id.trim();

    if (id.isEmpty) {
      return;
    }

    final int existingIndex =
        _transactions.indexWhere(
      (LedgerTransactionModel item) =>
          item.id == id,
    );

    if (existingIndex >= 0) {
      _transactions[existingIndex] =
          transaction;
    } else {
      _transactions.add(transaction);
    }

    _transactions.sort(
      (
        LedgerTransactionModel a,
        LedgerTransactionModel b,
      ) =>
          b.date.compareTo(a.date),
    );

    notifyListeners();
  }

  // ===========================================================================
  // TRANSACTION TYPE HELPER
  // ===========================================================================

  bool _isDebit(String transactionType) {
    final String type =
        transactionType.trim().toLowerCase();

    return type == 'sale' ||
        type == 'debit' ||
        type == 'invoice' ||
        type == 'purchase' ||
        type == 'expense' ||
        type == 'adjustment debit' ||
        type == 'credit sale';
  }

  // ===========================================================================
  // LOADING STATE
  // ===========================================================================

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  // ===========================================================================
  // SAVING STATE
  // ===========================================================================

  void _setSaving(bool value) {
    if (_isSaving == value) {
      return;
    }

    _isSaving = value;
    notifyListeners();
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  void _clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  // ===========================================================================
  // ERROR FORMATTER
  // ===========================================================================

  String _formatError(
    Object error, {
    required String fallback,
  }) {
    final String message =
        error.toString().trim();

    if (message.isEmpty) {
      return fallback;
    }

    if (message.startsWith('Exception:')) {
      final String cleaned =
          message.replaceFirst(
        'Exception:',
        '',
      ).trim();

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return message;
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    _transactionsSubscription = null;

    super.dispose();
  }
}