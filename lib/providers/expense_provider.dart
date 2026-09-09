import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({
    ExpenseRepository? repository,
  }) : _repository = repository ?? ExpenseRepository();

  final ExpenseRepository _repository;

  final List<ExpenseModel> _expenses = <ExpenseModel>[];

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;
  String _businessId = '';

  StreamSubscription<List<ExpenseModel>>? _expenseSubscription;

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  List<ExpenseModel> get expenses =>
      List<ExpenseModel>.unmodifiable(_expenses);

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get hasExpenses => _expenses.isNotEmpty;

  bool get isEmpty => _expenses.isEmpty;

  String? get errorMessage => _errorMessage;

  String get businessId => _businessId;

  int get expenseCount => _expenses.length;

  double get totalExpenseAmount {
    return _expenses.fold<double>(
      0,
      (double total, ExpenseModel expense) {
        return total + expense.amount;
      },
    );
  }

  double get todayExpenseAmount {
    final DateTime now = DateTime.now();

    return _expenses.fold<double>(
      0,
      (double total, ExpenseModel expense) {
        final DateTime date = expense.date;

        final bool isToday =
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;

        if (!isToday) {
          return total;
        }

        return total + expense.amount;
      },
    );
  }

  List<ExpenseModel> get todayExpenses {
    final DateTime now = DateTime.now();

    return _expenses.where((ExpenseModel expense) {
      final DateTime date = expense.date;

      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
  }

  List<ExpenseModel> get transportationExpenses {
    return filterByCategory('Transportation');
  }

  List<ExpenseModel> get labourExpenses {
    return filterByCategory('Labour');
  }

  List<ExpenseModel> get electricityExpenses {
    return filterByCategory('Electricity');
  }

  List<ExpenseModel> get packagingExpenses {
    return filterByCategory('Packaging');
  }

  List<ExpenseModel> get rentExpenses {
    return filterByCategory('Rent');
  }

  List<ExpenseModel> get fuelExpenses {
    return filterByCategory('Fuel');
  }

  List<ExpenseModel> get maintenanceExpenses {
    return filterByCategory('Maintenance');
  }

  List<ExpenseModel> get otherExpenses {
    return filterByCategory('Other');
  }

  double get transportationTotal =>
      _calculateCategoryTotal('Transportation');

  double get labourTotal => _calculateCategoryTotal('Labour');

  double get electricityTotal =>
      _calculateCategoryTotal('Electricity');

  double get packagingTotal =>
      _calculateCategoryTotal('Packaging');

  double get rentTotal => _calculateCategoryTotal('Rent');

  double get fuelTotal => _calculateCategoryTotal('Fuel');

  double get maintenanceTotal =>
      _calculateCategoryTotal('Maintenance');

  double get otherTotal => _calculateCategoryTotal('Other');

  // ---------------------------------------------------------------------------
  // BUSINESS
  // ---------------------------------------------------------------------------

  void setBusinessId(String value) {
    final String id = value.trim();

    if (_businessId == id) {
      return;
    }

    _businessId = id;
    clearExpenses(notify: false);

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // LOAD
  // ---------------------------------------------------------------------------

  Future<List<ExpenseModel>> loadExpenses({
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return <ExpenseModel>[];
    }

    _businessId = id;

    _setLoading(true);
    _clearError();

    try {
      final List<ExpenseModel> result =
          await _repository.getExpenses(
        businessId: id,
      );

      _expenses
        ..clear()
        ..addAll(result);

      notifyListeners();

      return List<ExpenseModel>.unmodifiable(
        _expenses,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to load expenses.',
        ),
      );

      return <ExpenseModel>[];
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // WATCH
  // ---------------------------------------------------------------------------

  void watchExpenses({
    String? businessId,
  }) {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return;
    }

    _businessId = id;

    _expenseSubscription?.cancel();
    _clearError();

    _expenseSubscription =
        _repository.watchExpenses(
      businessId: id,
    ).listen(
      (List<ExpenseModel> values) {
        _expenses
          ..clear()
          ..addAll(values);

        notifyListeners();
      },
      onError: (Object error) {
        _setError(
          _formatError(
            error,
            fallback:
                'Unable to listen for expense updates.',
          ),
        );
      },
    );
  }

  Future<void> loadAndWatchExpenses({
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return;
    }

    await loadExpenses(
      businessId: id,
    );

    watchExpenses(
      businessId: id,
    );
  }

  // ---------------------------------------------------------------------------
  // GET SINGLE EXPENSE
  // ---------------------------------------------------------------------------

  Future<ExpenseModel?> getExpense({
    required String expenseId,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String expenseIdValue =
        expenseId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return null;
    }

    if (expenseIdValue.isEmpty) {
      _setError('Expense ID is required.');
      return null;
    }

    _clearError();

    try {
      return await _repository.getExpense(
        businessId: id,
        expenseId: expenseIdValue,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to load expense.',
        ),
      );

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  Future<ExpenseModel?> createExpense(
    ExpenseModel expense,
  ) async {
    final String id =
        expense.businessId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return null;
    }

    if (expense.amount <= 0) {
      _setError(
        'Expense amount must be greater than zero.',
      );
      return null;
    }

    _setSaving(true);
    _clearError();

    try {
      final ExpenseModel savedExpense =
          await _repository.createExpense(
        expense,
      );

      _businessId = id;

      _upsertLocalExpense(
        savedExpense,
      );

      return savedExpense;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to create expense.',
        ),
      );

      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<bool> updateExpense(
    ExpenseModel expense,
  ) async {
    final String id =
        expense.businessId.trim();

    final String expenseId =
        expense.id.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (expenseId.isEmpty) {
      _setError('Expense ID is required.');
      return false;
    }

    if (expense.amount <= 0) {
      _setError(
        'Expense amount must be greater than zero.',
      );
      return false;
    }

    _setSaving(true);
    _clearError();

    try {
      await _repository.updateExpense(
        expense,
      );

      _businessId = id;

      _upsertLocalExpense(
        expense,
      );

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to update expense.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<bool> deleteExpense({
    required String expenseId,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String expenseIdValue =
        expenseId.trim();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return false;
    }

    if (expenseIdValue.isEmpty) {
      _setError('Expense ID is required.');
      return false;
    }

    _setSaving(true);
    _clearError();

    try {
      await _repository.deleteExpense(
        businessId: id,
        expenseId: expenseIdValue,
      );

      _expenses.removeWhere(
        (ExpenseModel expense) =>
            expense.id == expenseIdValue,
      );

      notifyListeners();

      return true;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to delete expense.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  Future<List<ExpenseModel>> searchExpenses(
    String query, {
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String searchQuery =
        query.trim().toLowerCase();

    if (id.isEmpty) {
      _setError('Business ID is required.');
      return <ExpenseModel>[];
    }

    if (searchQuery.isEmpty) {
      return List<ExpenseModel>.unmodifiable(
        _expenses,
      );
    }

    try {
      final List<ExpenseModel> result =
          await _repository.searchExpenses(
        businessId: id,
        query: searchQuery,
      );

      return result;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to search expenses.',
        ),
      );

      return <ExpenseModel>[];
    }
  }

  // ---------------------------------------------------------------------------
  // FILTER
  // ---------------------------------------------------------------------------

  List<ExpenseModel> filterExpenses({
    String? query,
    String? category,
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final String search =
        query?.trim().toLowerCase() ?? '';

    final String categoryValue =
        category?.trim().toLowerCase() ?? '';

    final String methodValue =
        paymentMethod?.trim().toLowerCase() ?? '';

    DateTime? normalizedStart;

    if (startDate != null) {
      normalizedStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
    }

    DateTime? normalizedEnd;

    if (endDate != null) {
      normalizedEnd = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      );
    }

    return _expenses.where((ExpenseModel expense) {
      final bool matchesQuery =
          search.isEmpty ||
          expense.category
              .toLowerCase()
              .contains(search) ||
          expense.description
              .toLowerCase()
              .contains(search) ||
          expense.notes
              .toLowerCase()
              .contains(search) ||
          expense.paymentMethod
              .toLowerCase()
              .contains(search);

      final bool matchesCategory =
          categoryValue.isEmpty ||
          expense.category
              .toLowerCase() ==
              categoryValue;

      final bool matchesPaymentMethod =
          methodValue.isEmpty ||
          expense.paymentMethod
              .toLowerCase() ==
              methodValue;

      final bool matchesStartDate =
          normalizedStart == null ||
          !expense.date.isBefore(
            normalizedStart,
          );

      final bool matchesEndDate =
          normalizedEnd == null ||
          !expense.date.isAfter(
            normalizedEnd,
          );

      return matchesQuery &&
          matchesCategory &&
          matchesPaymentMethod &&
          matchesStartDate &&
          matchesEndDate;
    }).toList();
  }

  List<ExpenseModel> filterByCategory(
    String category,
  ) {
    final String value =
        category.trim().toLowerCase();

    if (value.isEmpty) {
      return <ExpenseModel>[];
    }

    return _expenses.where((ExpenseModel expense) {
      return expense.category
              .trim()
              .toLowerCase() ==
          value;
    }).toList();
  }

  List<ExpenseModel> filterByPaymentMethod(
    String paymentMethod,
  ) {
    final String value =
        paymentMethod.trim().toLowerCase();

    if (value.isEmpty) {
      return <ExpenseModel>[];
    }

    return _expenses.where((ExpenseModel expense) {
      return expense.paymentMethod
              .trim()
              .toLowerCase() ==
          value;
    }).toList();
  }

  List<ExpenseModel> filterByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final DateTime start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final DateTime end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    return _expenses.where((ExpenseModel expense) {
      return !expense.date.isBefore(start) &&
          !expense.date.isAfter(end);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // FIND
  // ---------------------------------------------------------------------------

  ExpenseModel? findExpenseById(
    String expenseId,
  ) {
    final String id = expenseId.trim();

    if (id.isEmpty) {
      return null;
    }

    for (final ExpenseModel expense in _expenses) {
      if (expense.id == id) {
        return expense;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // CATEGORY TOTAL
  // ---------------------------------------------------------------------------

  double calculateTotal({
    String? category,
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final List<ExpenseModel> filtered =
        filterExpenses(
      category: category,
      paymentMethod: paymentMethod,
      startDate: startDate,
      endDate: endDate,
    );

    return filtered.fold<double>(
      0,
      (double total, ExpenseModel expense) {
        return total + expense.amount;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<List<ExpenseModel>> refresh() {
    return loadExpenses();
  }

  // ---------------------------------------------------------------------------
  // CLEAR
  // ---------------------------------------------------------------------------

  void clearExpenses({
    bool notify = true,
  }) {
    _expenses.clear();

    if (notify) {
      notifyListeners();
    }
  }

  void clearError() {
    _clearError();
  }

  // ---------------------------------------------------------------------------
  // LOCAL HELPERS
  // ---------------------------------------------------------------------------

  void _upsertLocalExpense(
    ExpenseModel expense,
  ) {
    final int index = _expenses.indexWhere(
      (ExpenseModel item) =>
          item.id == expense.id,
    );

    if (index == -1) {
      _expenses.add(expense);
    } else {
      _expenses[index] = expense;
    }

    _expenses.sort(
      (ExpenseModel a, ExpenseModel b) {
        return b.date.compareTo(a.date);
      },
    );

    notifyListeners();
  }

  double _calculateCategoryTotal(
    String category,
  ) {
    return filterByCategory(
      category,
    ).fold<double>(
      0,
      (double total, ExpenseModel expense) {
        return total + expense.amount;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STATE HELPERS
  // ---------------------------------------------------------------------------

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    if (_isSaving == value) {
      return;
    }

    _isSaving = value;
    notifyListeners();
  }

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

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _expenseSubscription?.cancel();
    super.dispose();
  }
}