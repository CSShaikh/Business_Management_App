import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/purchase_model.dart';
import 'base_repository.dart';

class PurchaseRepository extends BaseRepository {
  PurchaseRepository({
    super.firestore,
  });

  CollectionReference<Map<String, dynamic>> _purchases(
    String businessId,
  ) {
    return firestore
        .collection('businesses')
        .doc(businessId)
        .collection('purchases');
  }

  Future<PurchaseModel> createPurchase(
    PurchaseModel purchase,
  ) async {
    if (purchase.businessId.trim().isEmpty) {
      throw ArgumentError('Business ID is required.');
    }

    if (purchase.items.isEmpty) {
      throw ArgumentError(
        'At least one purchase item is required.',
      );
    }

    if (purchase.total < 0) {
      throw ArgumentError(
        'Purchase total cannot be negative.',
      );
    }

    if (purchase.paidAmount < 0) {
      throw ArgumentError(
        'Paid amount cannot be negative.',
      );
    }

    if (purchase.paidAmount > purchase.total) {
      throw ArgumentError(
        'Paid amount cannot be greater than purchase total.',
      );
    }

    final collection = _purchases(
      purchase.businessId,
    );

    final document = purchase.id.trim().isEmpty
        ? collection.doc()
        : collection.doc(purchase.id);

    final paymentStatus = _calculatePaymentStatus(
      total: purchase.total,
      paidAmount: purchase.paidAmount,
    );

    final savedPurchase = PurchaseModel(
      id: document.id,
      businessId: purchase.businessId,
      supplierId: purchase.supplierId,
      supplierName: purchase.supplierName,
      items: purchase.items,
      subtotal: purchase.subtotal,
      discount: purchase.discount,
      tax: purchase.tax,
      total: purchase.total,
      paidAmount: purchase.paidAmount,
      paymentStatus: paymentStatus,
      paymentMethod: purchase.paymentMethod,
      date: purchase.date,
      notes: purchase.notes,
      createdAt: purchase.createdAt,
    );

    await document.set(
      _toMap(savedPurchase),
    );

    return savedPurchase;
  }

  Future<PurchaseModel?> getPurchase({
    required String businessId,
    required String purchaseId,
  }) async {
    final snapshot = await _purchases(
      businessId,
    ).doc(purchaseId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.data()!,
      snapshot.id,
    );
  }

  Future<List<PurchaseModel>> getPurchases({
    required String businessId,
  }) async {
    final snapshot = await _purchases(
      businessId,
    )
        .orderBy(
          'date',
          descending: true,
        )
        .get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.data(),
            doc.id,
          ),
        )
        .toList();
  }

  Stream<List<PurchaseModel>> watchPurchases({
    required String businessId,
  }) {
    return _purchases(
      businessId,
    )
        .orderBy(
          'date',
          descending: true,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<List<PurchaseModel>> getSupplierPurchases({
    required String businessId,
    required String supplierId,
  }) async {
    final snapshot = await _purchases(
      businessId,
    )
        .where(
          'supplierId',
          isEqualTo: supplierId,
        )
        .orderBy(
          'date',
          descending: true,
        )
        .get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.data(),
            doc.id,
          ),
        )
        .toList();
  }

  Stream<List<PurchaseModel>> watchSupplierPurchases({
    required String businessId,
    required String supplierId,
  }) {
    return _purchases(
      businessId,
    )
        .where(
          'supplierId',
          isEqualTo: supplierId,
        )
        .orderBy(
          'date',
          descending: true,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<void> updatePurchase(
    PurchaseModel purchase,
  ) async {
    if (purchase.businessId.trim().isEmpty) {
      throw ArgumentError('Business ID is required.');
    }

    if (purchase.id.trim().isEmpty) {
      throw ArgumentError('Purchase ID is required.');
    }

    if (purchase.items.isEmpty) {
      throw ArgumentError(
        'At least one purchase item is required.',
      );
    }

    if (purchase.total < 0) {
      throw ArgumentError(
        'Purchase total cannot be negative.',
      );
    }

    if (purchase.paidAmount < 0) {
      throw ArgumentError(
        'Paid amount cannot be negative.',
      );
    }

    if (purchase.paidAmount > purchase.total) {
      throw ArgumentError(
        'Paid amount cannot be greater than purchase total.',
      );
    }

    final paymentStatus = _calculatePaymentStatus(
      total: purchase.total,
      paidAmount: purchase.paidAmount,
    );

    final updatedPurchase = PurchaseModel(
      id: purchase.id,
      businessId: purchase.businessId,
      supplierId: purchase.supplierId,
      supplierName: purchase.supplierName,
      items: purchase.items,
      subtotal: purchase.subtotal,
      discount: purchase.discount,
      tax: purchase.tax,
      total: purchase.total,
      paidAmount: purchase.paidAmount,
      paymentStatus: paymentStatus,
      paymentMethod: purchase.paymentMethod,
      date: purchase.date,
      notes: purchase.notes,
      createdAt: purchase.createdAt,
    );

    await _purchases(
      purchase.businessId,
    )
        .doc(purchase.id)
        .update(
      _toMap(
        updatedPurchase,
      ),
    );
  }

  Future<void> deletePurchase({
    required String businessId,
    required String purchaseId,
  }) async {
    await _purchases(
      businessId,
    )
        .doc(purchaseId)
        .delete();
  }

  Future<void> updatePaidAmount({
    required String businessId,
    required String purchaseId,
    required double paidAmount,
  }) async {
    if (paidAmount < 0) {
      throw ArgumentError(
        'Paid amount cannot be negative.',
      );
    }

    final purchase = await getPurchase(
      businessId: businessId,
      purchaseId: purchaseId,
    );

    if (purchase == null) {
      throw StateError(
        'Purchase not found.',
      );
    }

    if (paidAmount > purchase.total) {
      throw ArgumentError(
        'Paid amount cannot be greater than purchase total.',
      );
    }

    final paymentStatus = _calculatePaymentStatus(
      total: purchase.total,
      paidAmount: paidAmount,
    );

    await _purchases(
      businessId,
    )
        .doc(purchaseId)
        .update({
      'paidAmount': paidAmount,
      'paymentStatus': paymentStatus,
    });
  }

  Future<List<PurchaseModel>> searchPurchases({
    required String businessId,
    required String query,
  }) async {
    final purchases = await getPurchases(
      businessId: businessId,
    );

    final normalizedQuery =
        query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return purchases;
    }

    return purchases.where((purchase) {
      final supplierName =
          purchase.supplierName.toLowerCase();

      final supplierId =
          purchase.supplierId.toLowerCase();

      final paymentMethod =
          purchase.paymentMethod.toLowerCase();

      final paymentStatus =
          purchase.paymentStatus.toLowerCase();

      final notes =
          purchase.notes.toLowerCase();

      final itemNames = purchase.items
          .map(
            (item) => item.productName.toLowerCase(),
          )
          .join(' ');

      return supplierName.contains(normalizedQuery) ||
          supplierId.contains(normalizedQuery) ||
          paymentMethod.contains(normalizedQuery) ||
          paymentStatus.contains(normalizedQuery) ||
          notes.contains(normalizedQuery) ||
          itemNames.contains(normalizedQuery);
    }).toList();
  }

  Future<double> getTotalPurchases({
    required String businessId,
  }) async {
    final purchases = await getPurchases(
      businessId: businessId,
    );

    return purchases.fold<double>(
      0,
      (total, purchase) => total + purchase.total,
    );
  }

  Future<double> getTotalPaid({
    required String businessId,
  }) async {
    final purchases = await getPurchases(
      businessId: businessId,
    );

    return purchases.fold<double>(
      0,
      (total, purchase) =>
          total + purchase.paidAmount,
    );
  }

  Future<double> getTotalOutstanding({
    required String businessId,
  }) async {
    final purchases = await getPurchases(
      businessId: businessId,
    );

    return purchases.fold<double>(
      0,
      (total, purchase) =>
          total + (purchase.total - purchase.paidAmount),
    );
  }

  Future<List<PurchaseModel>> getTodayPurchases({
    required String businessId,
  }) async {
    final purchases = await getPurchases(
      businessId: businessId,
    );

    final now = DateTime.now();

    return purchases.where((purchase) {
      return purchase.date.year == now.year &&
          purchase.date.month == now.month &&
          purchase.date.day == now.day;
    }).toList();
  }

  Future<double> getTodayPurchasesTotal({
    required String businessId,
  }) async {
    final purchases = await getTodayPurchases(
      businessId: businessId,
    );

    return purchases.fold<double>(
      0,
      (total, purchase) => total + purchase.total,
    );
  }

  String _calculatePaymentStatus({
    required double total,
    required double paidAmount,
  }) {
    const tolerance = 0.000001;

    if (total <= tolerance) {
      return 'Paid';
    }

    if (paidAmount <= tolerance) {
      return 'Unpaid';
    }

    if (paidAmount >= total - tolerance) {
      return 'Paid';
    }

    return 'Partial';
  }

  Map<String, dynamic> _toMap(
    PurchaseModel purchase,
  ) {
    return {
      'id': purchase.id,
      'businessId': purchase.businessId,
      'supplierId': purchase.supplierId,
      'supplierName': purchase.supplierName,
      'items': purchase.items
          .map(_purchaseItemToMap)
          .toList(),
      'subtotal': purchase.subtotal,
      'discount': purchase.discount,
      'tax': purchase.tax,
      'total': purchase.total,
      'paidAmount': purchase.paidAmount,
      'paymentStatus': _calculatePaymentStatus(
        total: purchase.total,
        paidAmount: purchase.paidAmount,
      ),
      'paymentMethod': purchase.paymentMethod,
      'date': Timestamp.fromDate(
        purchase.date,
      ),
      'notes': purchase.notes,
      'createdAt': Timestamp.fromDate(
        purchase.createdAt,
      ),
    };
  }

  Map<String, dynamic> _purchaseItemToMap(
    PurchaseItemModel item,
  ) {
    return {
      'productId': item.productId,
      'productName': item.productName,
      'quantity': item.quantity,
      'unit': item.unit,
      'purchaseRate': item.purchaseRate,
      'total': item.total,
    };
  }

  PurchaseModel _fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final rawItems = data['items'];

    final items = <PurchaseItemModel>[];

    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is Map) {
          items.add(
            _purchaseItemFromMap(
              Map<String, dynamic>.from(
                rawItem,
              ),
            ),
          );
        }
      }
    }

    return PurchaseModel(
      id: data['id'] as String? ?? documentId,
      businessId:
          data['businessId'] as String? ?? '',
      supplierId:
          data['supplierId'] as String? ?? '',
      supplierName:
          data['supplierName'] as String? ?? '',
      items: items,
      subtotal: _toDouble(
        data['subtotal'],
      ),
      discount: _toDouble(
        data['discount'],
      ),
      tax: _toDouble(
        data['tax'],
      ),
      total: _toDouble(
        data['total'],
      ),
      paidAmount: _toDouble(
        data['paidAmount'],
      ),
      paymentStatus:
          data['paymentStatus'] as String? ??
              'Unpaid',
      paymentMethod:
          data['paymentMethod'] as String? ??
              '',
      date: dateFromFirestore(
        data['date'],
      ),
      notes: data['notes'] as String? ?? '',
      createdAt: dateFromFirestore(
        data['createdAt'],
      ),
    );
  }

  PurchaseItemModel _purchaseItemFromMap(
    Map<String, dynamic> data,
  ) {
    return PurchaseItemModel(
      productId:
          data['productId'] as String? ?? '',
      productName:
          data['productName'] as String? ?? '',
      quantity: _toDouble(
        data['quantity'],
      ),
      unit: data['unit'] as String? ?? '',
      purchaseRate: _toDouble(
        data['purchaseRate'],
      ),
      total: _toDouble(
        data['total'],
      ),
    );
  }

  double _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }
}
