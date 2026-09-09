import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense_model.dart';
import 'base_repository.dart';

class ExpenseRepository extends BaseRepository {
  ExpenseRepository({
    super.firestore,
  });

  CollectionReference<Map<String, dynamic>> _expenses(
    String businessId,
  ) {
    final normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    return firestore
        .collection('businesses')
        .doc(normalizedBusinessId)
        .collection('expenses');
  }

  Future<ExpenseModel> createExpense(
    ExpenseModel expense,
  ) async {
    _validateExpense(expense);

    final businessId =
        expense.businessId.trim();

    final collection =
        _expenses(businessId);

    final document = collection.doc();

    final savedExpense = ExpenseModel(
      id: document.id,
      businessId: businessId,
      category: expense.category.trim(),
      amount: expense.amount,
      date: expense.date,
      paymentMethod:
          expense.paymentMethod.trim(),
      description:
          expense.description.trim(),
      notes: expense.notes.trim(),
      receiptUrl:
          expense.receiptUrl.trim(),
      createdAt: expense.createdAt,
    );

    await document.set(
      _toMap(savedExpense),
    );

    return savedExpense;
  }

  Future<ExpenseModel?> getExpense({
    required String businessId,
    required String expenseId,
  }) async {
    final normalizedBusinessId =
        businessId.trim();

    final normalizedExpenseId =
        expenseId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedExpenseId.isEmpty) {
      throw ArgumentError(
        'Expense ID cannot be empty.',
      );
    }

    final snapshot = await _expenses(
      normalizedBusinessId,
    )
        .doc(normalizedExpenseId)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

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

  Future<List<ExpenseModel>> getExpenses({
    required String businessId,
  }) async {
    final normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    final snapshot = await _expenses(
      normalizedBusinessId,
    )
        .orderBy(
          'date',
          descending: true,
        )
        .get();

    return snapshot.docs
        .map(
          (document) => _fromMap(
            document.id,
            document.data(),
            fallbackBusinessId:
                normalizedBusinessId,
          ),
        )
        .toList();
  }

  Stream<List<ExpenseModel>> watchExpenses({
    required String businessId,
  }) {
    final normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    return _expenses(
      normalizedBusinessId,
    )
        .orderBy(
          'date',
          descending: true,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => _fromMap(
                  document.id,
                  document.data(),
                  fallbackBusinessId:
                      normalizedBusinessId,
                ),
              )
              .toList(),
        );
  }

  Future<void> updateExpense(
    ExpenseModel expense,
  ) async {
    _validateExpense(expense);

    final normalizedExpenseId =
        expense.id.trim();

    if (normalizedExpenseId.isEmpty) {
      throw ArgumentError(
        'Expense ID cannot be empty.',
      );
    }

    final normalizedBusinessId =
        expense.businessId.trim();

    final existingDocument =
        await _expenses(
      normalizedBusinessId,
    )
            .doc(normalizedExpenseId)
            .get();

    if (!existingDocument.exists) {
      throw StateError(
        'Expense not found.',
      );
    }

    final existingData =
        existingDocument.data();

    if (existingData == null) {
      throw StateError(
        'Expense data not found.',
      );
    }

    final existingExpense = _fromMap(
      existingDocument.id,
      existingData,
      fallbackBusinessId:
          normalizedBusinessId,
    );

    final updatedExpense = ExpenseModel(
      id: existingExpense.id,
      businessId:
          existingExpense.businessId.trim().isNotEmpty
              ? existingExpense.businessId.trim()
              : normalizedBusinessId,
      category: expense.category.trim(),
      amount: expense.amount,
      date: expense.date,
      paymentMethod:
          expense.paymentMethod.trim(),
      description:
          expense.description.trim(),
      notes: expense.notes.trim(),
      receiptUrl:
          expense.receiptUrl.trim(),
      createdAt: existingExpense.createdAt,
    );

    await _expenses(
      updatedExpense.businessId,
    )
        .doc(updatedExpense.id)
        .update(
          _toMap(updatedExpense),
        );
  }

  Future<void> deleteExpense({
    required String businessId,
    required String expenseId,
  }) async {
    final normalizedBusinessId =
        businessId.trim();

    final normalizedExpenseId =
        expenseId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedExpenseId.isEmpty) {
      throw ArgumentError(
        'Expense ID cannot be empty.',
      );
    }

    final document = await _expenses(
      normalizedBusinessId,
    )
        .doc(normalizedExpenseId)
        .get();

    if (!document.exists) {
      throw StateError(
        'Expense not found.',
      );
    }

    await document.reference.delete();
  }

  Future<List<ExpenseModel>> searchExpenses({
    required String businessId,
    required String query,
  }) async {
    final normalizedQuery =
        query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return getExpenses(
        businessId: businessId,
      );
    }

    final expenses = await getExpenses(
      businessId: businessId,
    );

    return expenses.where(
      (expense) {
        return expense.category
                .toLowerCase()
                .contains(normalizedQuery) ||
            expense.description
                .toLowerCase()
                .contains(normalizedQuery) ||
            expense.paymentMethod
                .toLowerCase()
                .contains(normalizedQuery) ||
            expense.notes
                .toLowerCase()
                .contains(normalizedQuery) ||
            expense.amount
                .toString()
                .contains(normalizedQuery);
      },
    ).toList();
  }

  Future<double> getTotalExpenses({
    required String businessId,
  }) async {
    final expenses = await getExpenses(
      businessId: businessId,
    );

    return expenses.fold<double>(
      0,
      (total, expense) =>
          total + expense.amount,
    );
  }

  Future<double> getTodayExpensesTotal({
    required String businessId,
  }) async {
    final expenses =
        await getTodayExpenses(
      businessId: businessId,
    );

    return expenses.fold<double>(
      0,
      (total, expense) =>
          total + expense.amount,
    );
  }

  Future<List<ExpenseModel>> getTodayExpenses({
    required String businessId,
  }) async {
    final normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    final now = DateTime.now();

    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final endOfDay = startOfDay.add(
      const Duration(days: 1),
    );

    final snapshot = await _expenses(
      normalizedBusinessId,
    )
        .where(
          'date',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(
            startOfDay,
          ),
        )
        .where(
          'date',
          isLessThan:
              Timestamp.fromDate(
            endOfDay,
          ),
        )
        .orderBy(
          'date',
          descending: true,
        )
        .get();

    return snapshot.docs
        .map(
          (document) => _fromMap(
            document.id,
            document.data(),
            fallbackBusinessId:
                normalizedBusinessId,
          ),
        )
        .toList();
  }

  Future<double> getMonthlyExpensesTotal({
    required String businessId,
  }) async {
    final expenses = await getExpenses(
      businessId: businessId,
    );

    final now = DateTime.now();

    return expenses
        .where(
          (expense) =>
              expense.date.year ==
                  now.year &&
              expense.date.month ==
                  now.month,
        )
        .fold<double>(
          0,
          (total, expense) =>
              total + expense.amount,
        );
  }

  Future<List<ExpenseModel>>
      getExpensesByCategory({
    required String businessId,
    required String category,
  }) async {
    final expenses = await getExpenses(
      businessId: businessId,
    );

    final normalizedCategory =
        category.trim().toLowerCase();

    if (normalizedCategory.isEmpty) {
      return [];
    }

    return expenses
        .where(
          (expense) =>
              expense.category
                  .trim()
                  .toLowerCase() ==
              normalizedCategory,
        )
        .toList();
  }

  Future<double> getCategoryTotal({
    required String businessId,
    required String category,
  }) async {
    final expenses =
        await getExpensesByCategory(
      businessId: businessId,
      category: category,
    );

    return expenses.fold<double>(
      0,
      (total, expense) =>
          total + expense.amount,
    );
  }

  Future<List<ExpenseModel>>
      getExpensesByPaymentMethod({
    required String businessId,
    required String paymentMethod,
  }) async {
    final expenses = await getExpenses(
      businessId: businessId,
    );

    final normalizedMethod =
        paymentMethod.trim().toLowerCase();

    if (normalizedMethod.isEmpty) {
      return [];
    }

    return expenses
        .where(
          (expense) =>
              expense.paymentMethod
                  .trim()
                  .toLowerCase() ==
              normalizedMethod,
        )
        .toList();
  }

  Future<List<ExpenseModel>>
      getExpensesBetweenDates({
    required String businessId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (endDate.isBefore(startDate)) {
      throw ArgumentError(
        'End date cannot be before start date.',
      );
    }

    final start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(
      const Duration(days: 1),
    );

    final snapshot = await _expenses(
      normalizedBusinessId,
    )
        .where(
          'date',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(start),
        )
        .where(
          'date',
          isLessThan:
              Timestamp.fromDate(end),
        )
        .orderBy(
          'date',
          descending: true,
        )
        .get();

    return snapshot.docs
        .map(
          (document) => _fromMap(
            document.id,
            document.data(),
            fallbackBusinessId:
                normalizedBusinessId,
          ),
        )
        .toList();
  }

  Map<String, dynamic> _toMap(
    ExpenseModel expense,
  ) {
    return {
      'businessId':
          expense.businessId.trim(),
      'category':
          expense.category.trim(),
      'amount': expense.amount,
      'date': Timestamp.fromDate(
        expense.date,
      ),
      'paymentMethod':
          expense.paymentMethod.trim(),
      'description':
          expense.description.trim(),
      'notes':
          expense.notes.trim(),
      'receiptUrl':
          expense.receiptUrl.trim(),
      'createdAt':
          Timestamp.fromDate(
        expense.createdAt,
      ),
    };
  }

  ExpenseModel _fromMap(
    String id,
    Map<String, dynamic> data, {
    String fallbackBusinessId = '',
  }) {
    final storedBusinessId =
        (data['businessId'] ?? '')
            .toString()
            .trim();

    return ExpenseModel(
      id: id.trim(),
      businessId:
          storedBusinessId.isNotEmpty
              ? storedBusinessId
              : fallbackBusinessId.trim(),
      category:
          (data['category'] ?? '')
              .toString()
              .trim(),
      amount:
          _toDouble(data['amount']),
      date:
          dateFromFirestore(
        data['date'],
      ),
      paymentMethod:
          (data['paymentMethod'] ?? '')
              .toString()
              .trim(),
      description:
          (data['description'] ?? '')
              .toString()
              .trim(),
      notes:
          (data['notes'] ?? '')
              .toString()
              .trim(),
      receiptUrl:
          (data['receiptUrl'] ?? '')
              .toString()
              .trim(),
      createdAt:
          dateFromFirestore(
        data['createdAt'],
      ),
    );
  }

  double _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      final result = value.toDouble();

      return result.isFinite
          ? result
          : 0;
    }

    if (value is String) {
      final result =
          double.tryParse(value.trim());

      if (result != null &&
          result.isFinite) {
        return result;
      }
    }

    return 0;
  }

  void _validateExpense(
    ExpenseModel expense,
  ) {
    final businessId =
        expense.businessId.trim();

    final category =
        expense.category.trim();

    final paymentMethod =
        expense.paymentMethod.trim();

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (category.isEmpty) {
      throw ArgumentError(
        'Expense category cannot be empty.',
      );
    }

    if (!expense.amount.isFinite) {
      throw ArgumentError(
        'Expense amount must be a valid number.',
      );
    }

    if (expense.amount <= 0) {
      throw ArgumentError(
        'Expense amount must be greater than zero.',
      );
    }

    if (paymentMethod.isEmpty) {
      throw ArgumentError(
        'Payment method cannot be empty.',
      );
    }
  }
}