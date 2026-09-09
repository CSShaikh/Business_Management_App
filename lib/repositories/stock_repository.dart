import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stock_transaction_model.dart';
import 'base_repository.dart';

class StockRepository extends BaseRepository {
  StockRepository({
    super.firestore,
  });

  static const String stockInType = 'IN';
  static const String stockOutType = 'OUT';
  static const String adjustmentType = 'ADJUSTMENT';

  CollectionReference<Map<String, dynamic>> _stockTransactions(
    String businessId,
  ) {
    return collection(
      'businesses/$businessId/stock_transactions',
    );
  }

  DocumentReference<Map<String, dynamic>> _product(
    String businessId,
    String productId,
  ) {
    return document(
      'businesses/$businessId/products/$productId',
    );
  }

  // ---------------------------------------------------------------------------
  // CREATE STOCK TRANSACTION
  // ---------------------------------------------------------------------------

  Future<StockTransactionModel> createStockTransaction(
    StockTransactionModel transaction,
  ) async {
    _validateTransaction(transaction);

    final collectionRef = _stockTransactions(
      transaction.businessId,
    );

    final docRef = collectionRef.doc();

    final savedTransaction = StockTransactionModel(
      id: docRef.id,
      businessId: transaction.businessId,
      productId: transaction.productId,
      productName: transaction.productName,
      transactionType: transaction.transactionType,
      quantity: transaction.quantity,
      stockBefore: transaction.stockBefore,
      stockAfter: transaction.stockAfter,
      unitCost: transaction.unitCost,
      referenceId: transaction.referenceId,
      date: transaction.date,
      notes: transaction.notes,
      createdAt: transaction.createdAt,
    );

    await docRef.set(
      _toMap(savedTransaction),
    );

    return savedTransaction;
  }

  // ---------------------------------------------------------------------------
  // GET SINGLE STOCK TRANSACTION
  // ---------------------------------------------------------------------------

  Future<StockTransactionModel?> getStockTransaction({
    required String businessId,
    required String transactionId,
  }) async {
    final snapshot = await _stockTransactions(
      businessId,
    ).doc(transactionId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.id,
      snapshot.data()!,
    );
  }

  // ---------------------------------------------------------------------------
  // GET ALL STOCK TRANSACTIONS
  // ---------------------------------------------------------------------------

  Future<List<StockTransactionModel>> getStockTransactions({
    required String businessId,
  }) async {
    final normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID is required.',
      );
    }

    final snapshot = await _stockTransactions(
      normalizedBusinessId,
    ).orderBy(
      'date',
      descending: true,
    ).get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // WATCH ALL STOCK TRANSACTIONS
  // ---------------------------------------------------------------------------

  Stream<List<StockTransactionModel>> watchStockTransactions({
    required String businessId,
  }) {
    final normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return Stream.error(
        ArgumentError(
          'Business ID is required.',
        ),
      );
    }

    return _stockTransactions(
      normalizedBusinessId,
    ).orderBy(
      'date',
      descending: true,
    ).snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map(
              (doc) => _fromMap(
                doc.id,
                doc.data(),
              ),
            )
            .toList();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // PRODUCT-WISE STOCK HISTORY
  // ---------------------------------------------------------------------------

  Future<List<StockTransactionModel>>
      getProductStockTransactions({
    required String businessId,
    required String productId,
  }) async {
    final normalizedBusinessId = businessId.trim();
    final normalizedProductId = productId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID is required.',
      );
    }

    if (normalizedProductId.isEmpty) {
      throw ArgumentError(
        'Product ID is required.',
      );
    }

    final snapshot = await _stockTransactions(
      normalizedBusinessId,
    ).where(
      'productId',
      isEqualTo: normalizedProductId,
    ).orderBy(
      'date',
      descending: true,
    ).get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // WATCH PRODUCT-WISE STOCK HISTORY
  // ---------------------------------------------------------------------------

  Stream<List<StockTransactionModel>>
      watchProductStockTransactions({
    required String businessId,
    required String productId,
  }) {
    final normalizedBusinessId = businessId.trim();
    final normalizedProductId = productId.trim();

    if (normalizedBusinessId.isEmpty) {
      return Stream.error(
        ArgumentError(
          'Business ID is required.',
        ),
      );
    }

    if (normalizedProductId.isEmpty) {
      return Stream.error(
        ArgumentError(
          'Product ID is required.',
        ),
      );
    }

    return _stockTransactions(
      normalizedBusinessId,
    ).where(
      'productId',
      isEqualTo: normalizedProductId,
    ).orderBy(
      'date',
      descending: true,
    ).snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map(
              (doc) => _fromMap(
                doc.id,
                doc.data(),
              ),
            )
            .toList();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH STOCK TRANSACTIONS
  // ---------------------------------------------------------------------------

  Future<List<StockTransactionModel>>
      searchStockTransactions({
    required String businessId,
    required String query,
  }) async {
    final transactions = await getStockTransactions(
      businessId: businessId,
    );

    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return transactions;
    }

    return transactions.where(
      (transaction) {
        return transaction.productName
                .toLowerCase()
                .contains(normalizedQuery) ||
            transaction.productId
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
                .contains(normalizedQuery);
      },
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // TODAY'S STOCK TRANSACTIONS
  // ---------------------------------------------------------------------------

  Future<List<StockTransactionModel>>
      getTodayStockTransactions({
    required String businessId,
  }) async {
    final transactions = await getStockTransactions(
      businessId: businessId,
    );

    final now = DateTime.now();

    return transactions.where(
      (transaction) {
        final date = transaction.date;

        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      },
    ).toList();
  }

  // ---------------------------------------------------------------------------
  // DATE RANGE
  // ---------------------------------------------------------------------------

  Future<List<StockTransactionModel>>
      getStockTransactionsBetweenDates({
    required String businessId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID is required.',
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
      23,
      59,
      59,
      999,
    );

    if (end.isBefore(start)) {
      throw ArgumentError(
        'End date cannot be before start date.',
      );
    }

    final snapshot = await _stockTransactions(
      normalizedBusinessId,
    ).where(
      'date',
      isGreaterThanOrEqualTo: Timestamp.fromDate(start),
    ).where(
      'date',
      isLessThanOrEqualTo: Timestamp.fromDate(end),
    ).orderBy(
      'date',
      descending: true,
    ).get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // STOCK IN
  // ---------------------------------------------------------------------------

  Future<StockTransactionModel> stockIn({
    required String businessId,
    required String productId,
    required double quantity,
    required double unitCost,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    if (quantity <= 0) {
      throw ArgumentError(
        'Stock quantity must be greater than zero.',
      );
    }

    return _adjustStock(
      businessId: businessId,
      productId: productId,
      quantity: quantity,
      transactionType: stockInType,
      unitCost: unitCost,
      referenceId: referenceId,
      date: date,
      notes: notes,
      forceIncrease: true,
    );
  }

  // ---------------------------------------------------------------------------
  // STOCK OUT
  // ---------------------------------------------------------------------------

  Future<StockTransactionModel> stockOut({
    required String businessId,
    required String productId,
    required double quantity,
    required double unitCost,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    if (quantity <= 0) {
      throw ArgumentError(
        'Stock quantity must be greater than zero.',
      );
    }

    return _adjustStock(
      businessId: businessId,
      productId: productId,
      quantity: quantity,
      transactionType: stockOutType,
      unitCost: unitCost,
      referenceId: referenceId,
      date: date,
      notes: notes,
      forceIncrease: false,
    );
  }

  // ---------------------------------------------------------------------------
  // STOCK ADJUSTMENT
  //
  // Positive quantity = stock increase
  // Negative quantity = stock decrease
  // ---------------------------------------------------------------------------

  Future<StockTransactionModel> adjustStock({
    required String businessId,
    required String productId,
    required double quantity,
    required double unitCost,
    String referenceId = '',
    DateTime? date,
    String notes = '',
  }) async {
    if (quantity == 0) {
      throw ArgumentError(
        'Stock adjustment quantity cannot be zero.',
      );
    }

    final transactionType = quantity > 0
        ? '$adjustmentType IN'
        : '$adjustmentType OUT';

    return _adjustStock(
      businessId: businessId,
      productId: productId,
      quantity: quantity.abs(),
      transactionType: transactionType,
      unitCost: unitCost,
      referenceId: referenceId,
      date: date,
      notes: notes,
      forceIncrease: quantity > 0,
    );
  }

  // ---------------------------------------------------------------------------
  // INTERNAL ATOMIC STOCK UPDATE
  // ---------------------------------------------------------------------------

  Future<StockTransactionModel> _adjustStock({
    required String businessId,
    required String productId,
    required double quantity,
    required String transactionType,
    required double unitCost,
    required String referenceId,
    required DateTime? date,
    required String notes,
    required bool forceIncrease,
  }) async {
    final normalizedBusinessId = businessId.trim();
    final normalizedProductId = productId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID is required.',
      );
    }

    if (normalizedProductId.isEmpty) {
      throw ArgumentError(
        'Product ID is required.',
      );
    }

    if (quantity <= 0) {
      throw ArgumentError(
        'Quantity must be greater than zero.',
      );
    }

    if (unitCost < 0) {
      throw ArgumentError(
        'Unit cost cannot be negative.',
      );
    }

    final normalizedTransactionType =
        transactionType.trim();

    if (normalizedTransactionType.isEmpty) {
      throw ArgumentError(
        'Transaction type is required.',
      );
    }

    final productRef = _product(
      normalizedBusinessId,
      normalizedProductId,
    );

    final transactionRef = _stockTransactions(
      normalizedBusinessId,
    ).doc();

    late StockTransactionModel result;

    await firestore.runTransaction(
      (transaction) async {
        final productSnapshot = await transaction.get(
          productRef,
        );

        if (!productSnapshot.exists ||
            productSnapshot.data() == null) {
          throw StateError(
            'Product not found.',
          );
        }

        final productData = productSnapshot.data()!;

        final productBusinessId =
            (productData['businessId'] ??
                    normalizedBusinessId)
                .toString()
                .trim();

        if (productBusinessId !=
            normalizedBusinessId) {
          throw StateError(
            'Product does not belong to this business.',
          );
        }

        final productName =
            (productData['name'] ?? '')
                .toString()
                .trim();

        if (productName.isEmpty) {
          throw StateError(
            'Product name is missing.',
          );
        }

        final currentStock = _toDouble(
          productData['currentStock'],
        );

        if (currentStock < 0) {
          throw StateError(
            'Product stock cannot be negative.',
          );
        }

        final productUnit =
            (productData['unit'] ?? '')
                .toString()
                .trim();

        final newStock = forceIncrease
            ? currentStock + quantity
            : currentStock - quantity;

        if (newStock < 0) {
          throw StateError(
            'Insufficient stock. '
            'Available stock: '
            '${_formatNumber(currentStock)}'
            '${productUnit.isEmpty ? '' : ' $productUnit'}',
          );
        }

        final now = DateTime.now();

        final transactionDate = date ?? now;

        final stockTransaction =
            StockTransactionModel(
          id: transactionRef.id,
          businessId: normalizedBusinessId,
          productId: normalizedProductId,
          productName: productName,
          transactionType:
              normalizedTransactionType,
          quantity: quantity,
          stockBefore: currentStock,
          stockAfter: newStock,
          unitCost: unitCost,
          referenceId: referenceId.trim(),
          date: transactionDate,
          notes: notes.trim(),
          createdAt: now,
        );

        transaction.update(
          productRef,
          {
            'currentStock': newStock,
            'updatedAt': Timestamp.fromDate(now),
          },
        );

        transaction.set(
          transactionRef,
          _toMap(stockTransaction),
        );

        result = stockTransaction;
      },
    );

    return result;
  }

  // ---------------------------------------------------------------------------
  // DELETE STOCK TRANSACTION
  //
  // Deleting a history record does NOT modify product stock.
  // Stock-changing operations must be handled separately.
  // ---------------------------------------------------------------------------

  Future<void> deleteStockTransaction({
    required String businessId,
    required String transactionId,
  }) async {
    final normalizedBusinessId = businessId.trim();
    final normalizedTransactionId =
        transactionId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID is required.',
      );
    }

    if (normalizedTransactionId.isEmpty) {
      throw ArgumentError(
        'Transaction ID is required.',
      );
    }

    await _stockTransactions(
      normalizedBusinessId,
    ).doc(normalizedTransactionId).delete();
  }

  // ---------------------------------------------------------------------------
  // TOTAL STOCK IN
  // ---------------------------------------------------------------------------

  Future<double> getTotalStockIn({
    required String businessId,
  }) async {
    final transactions = await getStockTransactions(
      businessId: businessId,
    );

    return transactions
        .where(
          (transaction) =>
              transaction.transactionType ==
                  stockInType ||
              transaction.transactionType ==
                  '$adjustmentType IN',
        )
        .fold<double>(
          0,
          (total, transaction) =>
              total + transaction.quantity,
        );
  }

  // ---------------------------------------------------------------------------
  // TOTAL STOCK OUT
  // ---------------------------------------------------------------------------

  Future<double> getTotalStockOut({
    required String businessId,
  }) async {
    final transactions = await getStockTransactions(
      businessId: businessId,
    );

    return transactions
        .where(
          (transaction) =>
              transaction.transactionType ==
                  stockOutType ||
              transaction.transactionType ==
                  '$adjustmentType OUT',
        )
        .fold<double>(
          0,
          (total, transaction) =>
              total + transaction.quantity,
        );
  }

  // ---------------------------------------------------------------------------
  // MAP
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _toMap(
    StockTransactionModel transaction,
  ) {
    return {
      'businessId': transaction.businessId,
      'productId': transaction.productId,
      'productName': transaction.productName,
      'transactionType':
          transaction.transactionType,
      'quantity': transaction.quantity,
      'stockBefore': transaction.stockBefore,
      'stockAfter': transaction.stockAfter,
      'unitCost': transaction.unitCost,
      'referenceId': transaction.referenceId,
      'date': Timestamp.fromDate(
        transaction.date,
      ),
      'notes': transaction.notes,
      'createdAt': Timestamp.fromDate(
        transaction.createdAt,
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // FROM MAP
  // ---------------------------------------------------------------------------

  StockTransactionModel _fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return StockTransactionModel(
      id: id,
      businessId:
          (data['businessId'] ?? '').toString(),
      productId:
          (data['productId'] ?? '').toString(),
      productName:
          (data['productName'] ?? '').toString(),
      transactionType:
          (data['transactionType'] ?? '')
              .toString(),
      quantity: _toDouble(
        data['quantity'],
      ),
      stockBefore: _toDouble(
        data['stockBefore'],
      ),
      stockAfter: _toDouble(
        data['stockAfter'],
      ),
      unitCost: _toDouble(
        data['unitCost'],
      ),
      referenceId:
          (data['referenceId'] ?? '').toString(),
      date: dateFromFirestore(
        data['date'],
      ),
      notes:
          (data['notes'] ?? '').toString(),
      createdAt: dateFromFirestore(
        data['createdAt'],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DOUBLE PARSER
  // ---------------------------------------------------------------------------

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }

  // ---------------------------------------------------------------------------
  // NUMBER FORMATTER
  // ---------------------------------------------------------------------------

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  void _validateTransaction(
    StockTransactionModel transaction,
  ) {
    if (transaction.businessId.trim().isEmpty) {
      throw ArgumentError(
        'Business ID is required.',
      );
    }

    if (transaction.productId.trim().isEmpty) {
      throw ArgumentError(
        'Product ID is required.',
      );
    }

    if (transaction.productName.trim().isEmpty) {
      throw ArgumentError(
        'Product name is required.',
      );
    }

    if (transaction.transactionType
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'Transaction type is required.',
      );
    }

    if (transaction.quantity <= 0) {
      throw ArgumentError(
        'Quantity must be greater than zero.',
      );
    }

    if (transaction.stockBefore < 0) {
      throw ArgumentError(
        'Stock before cannot be negative.',
      );
    }

    if (transaction.stockAfter < 0) {
      throw ArgumentError(
        'Stock after cannot be negative.',
      );
    }

    if (transaction.unitCost < 0) {
      throw ArgumentError(
        'Unit cost cannot be negative.',
      );
    }
  }
}