import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sale_model.dart';
import 'base_repository.dart';

class SaleRepository extends BaseRepository {
  SaleRepository({super.firestore});

  CollectionReference<Map<String, dynamic>> _sales(
    String businessId,
  ) {
    return firestore
        .collection('businesses')
        .doc(businessId.trim())
        .collection('sales');
  }

  Future<SaleModel> createSale(
    SaleModel sale,
  ) async {
    _validateSale(
      sale,
      requireId: false,
    );

    final String businessId =
        sale.businessId.trim();

    final CollectionReference<Map<String, dynamic>>
        sales = _sales(businessId);

    final DocumentReference<Map<String, dynamic>>
        document = sale.id.trim().isEmpty
            ? sales.doc()
            : sales.doc(sale.id.trim());

    final SaleModel saleToSave =
        _normalizedSale(
      sale,
      id: document.id,
      businessId: businessId,
      createdAt: DateTime.now(),
    );

    await document.set(
      _toMap(saleToSave),
    );

    return saleToSave;
  }

  Future<SaleModel?> getSale({
    required String businessId,
    required String saleId,
  }) async {
    final String normalizedBusinessId =
        _requireId(
      businessId,
      'Business ID',
    );

    final String normalizedSaleId =
        _requireId(
      saleId,
      'Sale ID',
    );

    final DocumentSnapshot<
        Map<String, dynamic>> snapshot =
        await _sales(normalizedBusinessId)
            .doc(normalizedSaleId)
            .get();

    if (!snapshot.exists ||
        snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.id,
      snapshot.data()!,
      normalizedBusinessId,
    );
  }

  Future<List<SaleModel>> getSales({
    required String businessId,
  }) async {
    final String normalizedBusinessId =
        _requireId(
      businessId,
      'Business ID',
    );

    final QuerySnapshot<
        Map<String, dynamic>> snapshot =
        await _sales(normalizedBusinessId)
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
            normalizedBusinessId,
          ),
        )
        .toList();
  }

  Stream<List<SaleModel>> watchSales({
    required String businessId,
  }) {
    final String normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return const Stream.empty();
    }

    return _sales(normalizedBusinessId)
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
                  normalizedBusinessId,
                ),
              )
              .toList(),
        );
  }

  Future<List<SaleModel>> getCustomerSales({
    required String businessId,
    required String customerId,
  }) async {
    final String normalizedBusinessId =
        _requireId(
      businessId,
      'Business ID',
    );

    final String normalizedCustomerId =
        _requireId(
      customerId,
      'Customer ID',
    );

    final QuerySnapshot<
        Map<String, dynamic>> snapshot =
        await _sales(normalizedBusinessId)
            .where(
              'customerId',
              isEqualTo: normalizedCustomerId,
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
            normalizedBusinessId,
          ),
        )
        .toList();
  }

  Stream<List<SaleModel>> watchCustomerSales({
    required String businessId,
    required String customerId,
  }) {
    final String normalizedBusinessId =
        businessId.trim();

    final String normalizedCustomerId =
        customerId.trim();

    if (normalizedBusinessId.isEmpty ||
        normalizedCustomerId.isEmpty) {
      return const Stream.empty();
    }

    return _sales(normalizedBusinessId)
        .where(
          'customerId',
          isEqualTo: normalizedCustomerId,
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
                  normalizedBusinessId,
                ),
              )
              .toList(),
        );
  }

  Future<void> updateSale(
    SaleModel sale,
  ) async {
    _validateSale(
      sale,
      requireId: true,
    );

    final String businessId =
        sale.businessId.trim();

    final String saleId =
        sale.id.trim();

    final DocumentReference<
        Map<String, dynamic>> reference =
        _sales(businessId).doc(saleId);

    final DocumentSnapshot<
        Map<String, dynamic>> snapshot =
        await reference.get();

    if (!snapshot.exists) {
      throw Exception(
        'Sale not found.',
      );
    }

    final Map<String, dynamic>? existingData =
        snapshot.data();

    final DateTime createdAt =
        existingData?['createdAt'] != null
            ? dateFromFirestore(
                existingData!['createdAt'],
              )
            : sale.createdAt;

    final SaleModel saleToUpdate =
        _normalizedSale(
      sale,
      id: saleId,
      businessId: businessId,
      createdAt: createdAt,
    );

    await reference.update(
      _toMap(saleToUpdate),
    );
  }

  Future<void> deleteSale({
    required String businessId,
    required String saleId,
  }) async {
    final String normalizedBusinessId =
        _requireId(
      businessId,
      'Business ID',
    );

    final String normalizedSaleId =
        _requireId(
      saleId,
      'Sale ID',
    );

    final DocumentReference<
        Map<String, dynamic>> reference =
        _sales(normalizedBusinessId).doc(
      normalizedSaleId,
    );

    final DocumentSnapshot<
        Map<String, dynamic>> snapshot =
        await reference.get();

    if (!snapshot.exists) {
      throw Exception(
        'Sale not found.',
      );
    }

    await reference.delete();
  }

  Future<void> updatePaidAmount({
    required String businessId,
    required String saleId,
    required double paidAmount,
  }) async {
    final String normalizedBusinessId =
        _requireId(
      businessId,
      'Business ID',
    );

    final String normalizedSaleId =
        _requireId(
      saleId,
      'Sale ID',
    );

    if (!paidAmount.isFinite ||
        paidAmount < 0) {
      throw ArgumentError(
        'Paid amount must be a valid non-negative number.',
      );
    }

    final DocumentReference<
        Map<String, dynamic>> reference =
        _sales(normalizedBusinessId).doc(
      normalizedSaleId,
    );

    final DocumentSnapshot<
        Map<String, dynamic>> snapshot =
        await reference.get();

    if (!snapshot.exists ||
        snapshot.data() == null) {
      throw Exception(
        'Sale not found.',
      );
    }

    final double total =
        _toDouble(
      snapshot.data()!['total'],
    );

    if (paidAmount > total) {
      throw ArgumentError(
        'Paid amount cannot be greater than sale total.',
      );
    }

    await reference.update({
      'paidAmount': paidAmount,
      'paymentStatus':
          _calculatePaymentStatus(
        total: total,
        paidAmount: paidAmount,
      ),
    });
  }

  Future<List<SaleModel>> searchSales({
    required String businessId,
    required String query,
  }) async {
    final List<SaleModel> sales =
        await getSales(
      businessId: businessId,
    );

    final String searchQuery =
        query.trim().toLowerCase();

    if (searchQuery.isEmpty) {
      return sales;
    }

    return sales.where(
      (sale) {
        return sale.invoiceNumber
                .toLowerCase()
                .contains(searchQuery) ||
            sale.customerName
                .toLowerCase()
                .contains(searchQuery) ||
            sale.notes
                .toLowerCase()
                .contains(searchQuery) ||
            sale.items.any(
              (item) => item.productName
                  .toLowerCase()
                  .contains(searchQuery),
            );
      },
    ).toList();
  }

  Future<double> getTotalSales({
    required String businessId,
  }) async {
    final List<SaleModel> sales =
        await getSales(
      businessId: businessId,
    );

    return sales.fold<double>(
      0,
      (total, sale) =>
          total + sale.total,
    );
  }

  Future<double> getTotalPaid({
    required String businessId,
  }) async {
    final List<SaleModel> sales =
        await getSales(
      businessId: businessId,
    );

    return sales.fold<double>(
      0,
      (total, sale) =>
          total + sale.paidAmount,
    );
  }

  Future<double> getTotalOutstanding({
    required String businessId,
  }) async {
    final List<SaleModel> sales =
        await getSales(
      businessId: businessId,
    );

    return sales.fold<double>(
      0,
      (total, sale) =>
          total +
          (sale.total - sale.paidAmount)
              .clamp(
            0,
            double.infinity,
          ),
    );
  }

  Future<List<SaleModel>> getTodaySales({
    required String businessId,
  }) async {
    final List<SaleModel> sales =
        await getSales(
      businessId: businessId,
    );

    final DateTime now =
        DateTime.now();

    return sales.where(
      (sale) {
        return sale.date.year ==
                now.year &&
            sale.date.month ==
                now.month &&
            sale.date.day ==
                now.day;
      },
    ).toList();
  }

  Future<double> getTodaySalesTotal({
    required String businessId,
  }) async {
    final List<SaleModel> sales =
        await getTodaySales(
      businessId: businessId,
    );

    return sales.fold<double>(
      0,
      (runningTotal, sale) =>
          runningTotal + sale.total,
    );
  }

  Future<String> generateInvoiceNumber({
    required String businessId,
  }) async {
    final List<SaleModel> sales =
        await getSales(
      businessId: businessId,
    );

    int highestNumber = 0;

    for (final SaleModel sale in sales) {
      final RegExpMatch? match =
          RegExp(r'(\d+)$').firstMatch(
        sale.invoiceNumber.trim(),
      );

      if (match == null) {
        continue;
      }

      final int? number =
          int.tryParse(
        match.group(1)!,
      );

      if (number != null &&
          number > highestNumber) {
        highestNumber = number;
      }
    }

    return 'INV-${(highestNumber + 1).toString().padLeft(4, '0')}';
  }

  void _validateSale(
    SaleModel sale, {
    required bool requireId,
  }) {
    if (sale.businessId.trim().isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (requireId &&
        sale.id.trim().isEmpty) {
      throw ArgumentError(
        'Sale ID cannot be empty.',
      );
    }

    if (sale.items.isEmpty) {
      throw ArgumentError(
        'Sale must contain at least one item.',
      );
    }

    _validateNumber(
      sale.subtotal,
      'Sale subtotal',
    );

    _validateNumber(
      sale.discount,
      'Sale discount',
    );

    _validateNumber(
      sale.tax,
      'Sale tax',
    );

    _validateNumber(
      sale.total,
      'Sale total',
    );

    _validateNumber(
      sale.paidAmount,
      'Paid amount',
    );

    if (sale.subtotal < 0 ||
        sale.discount < 0 ||
        sale.tax < 0 ||
        sale.total < 0) {
      throw ArgumentError(
        'Sale amounts cannot be negative.',
      );
    }

    if (sale.paidAmount < 0) {
      throw ArgumentError(
        'Paid amount cannot be negative.',
      );
    }

    if (sale.paidAmount > sale.total) {
      throw ArgumentError(
        'Paid amount cannot be greater than sale total.',
      );
    }

    for (final SaleItemModel item
        in sale.items) {
      if (item.productId
          .trim()
          .isEmpty) {
        throw ArgumentError(
          'Product ID cannot be empty for sale item: '
          '${item.productName}',
        );
      }

      if (!item.quantity.isFinite ||
          item.quantity <= 0) {
        throw ArgumentError(
          'Sale quantity must be greater than zero for '
          '${item.productName}.',
        );
      }

      if (!item.sellingRate.isFinite ||
          item.sellingRate < 0) {
        throw ArgumentError(
          'Selling rate cannot be negative for '
          '${item.productName}.',
        );
      }

      if (!item.discount.isFinite ||
          item.discount < 0) {
        throw ArgumentError(
          'Item discount cannot be negative for '
          '${item.productName}.',
        );
      }

      if (!item.tax.isFinite ||
          item.tax < 0) {
        throw ArgumentError(
          'Item tax cannot be negative for '
          '${item.productName}.',
        );
      }

      if (!item.total.isFinite ||
          item.total < 0) {
        throw ArgumentError(
          'Item total cannot be negative for '
          '${item.productName}.',
        );
      }

      if (!item.costPrice.isFinite ||
          item.costPrice < 0) {
        throw ArgumentError(
          'Cost price cannot be negative for '
          '${item.productName}.',
        );
      }
    }
  }

  void _validateNumber(
    double value,
    String label,
  ) {
    if (!value.isFinite) {
      throw ArgumentError(
        '$label must be a valid number.',
      );
    }
  }

  String _requireId(
    String value,
    String label,
  ) {
    final String normalized =
        value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError(
        '$label cannot be empty.',
      );
    }

    return normalized;
  }

  SaleModel _normalizedSale(
    SaleModel sale, {
    required String id,
    required String businessId,
    required DateTime createdAt,
  }) {
    return SaleModel(
      id: id.trim(),
      businessId: businessId.trim(),
      customerId: sale.customerId.trim(),
      customerName: sale.customerName.trim(),
      items: sale.items
          .map(_normalizedItem)
          .toList(
            growable: false,
          ),
      subtotal: sale.subtotal,
      discount: sale.discount,
      tax: sale.tax,
      total: sale.total,
      paidAmount: sale.paidAmount,
      paymentStatus:
          _calculatePaymentStatus(
        total: sale.total,
        paidAmount: sale.paidAmount,
      ),
      paymentMethod:
          sale.paymentMethod.trim(),
      date: sale.date,
      notes: sale.notes.trim(),
      invoiceNumber:
          sale.invoiceNumber.trim(),
      createdAt: createdAt,
    );
  }

  SaleItemModel _normalizedItem(
    SaleItemModel item,
  ) {
    return SaleItemModel(
      productId: item.productId.trim(),
      productName:
          item.productName.trim(),
      quantity: item.quantity,
      unit: item.unit.trim(),
      sellingRate: item.sellingRate,
      discount: item.discount,
      tax: item.tax,
      total: item.total,
      costPrice: item.costPrice,
    );
  }

  String _calculatePaymentStatus({
    required double total,
    required double paidAmount,
  }) {
    if (total <= 0 ||
        paidAmount >= total) {
      return 'paid';
    }

    if (paidAmount <= 0) {
      return 'unpaid';
    }

    return 'partial';
  }

  Map<String, dynamic> _toMap(
    SaleModel sale,
  ) {
    return {
      'id': sale.id,
      'businessId': sale.businessId,
      'customerId': sale.customerId,
      'customerName': sale.customerName,
      'items': sale.items
          .map(_saleItemToMap)
          .toList(),
      'subtotal': sale.subtotal,
      'discount': sale.discount,
      'tax': sale.tax,
      'total': sale.total,
      'paidAmount': sale.paidAmount,
      'paymentStatus':
          sale.paymentStatus,
      'paymentMethod':
          sale.paymentMethod,
      'date': Timestamp.fromDate(
        sale.date,
      ),
      'notes': sale.notes,
      'invoiceNumber':
          sale.invoiceNumber,
      'createdAt':
          Timestamp.fromDate(
        sale.createdAt,
      ),
    };
  }

  Map<String, dynamic> _saleItemToMap(
    SaleItemModel item,
  ) {
    return {
      'productId': item.productId,
      'productName': item.productName,
      'quantity': item.quantity,
      'unit': item.unit,
      'sellingRate': item.sellingRate,
      'discount': item.discount,
      'tax': item.tax,
      'total': item.total,
      'costPrice': item.costPrice,
    };
  }

  SaleModel _fromMap(
    String documentId,
    Map<String, dynamic> data,
    String businessId,
  ) {
    final List<SaleItemModel> items =
        [];

    final dynamic rawItems =
        data['items'];

    if (rawItems is List) {
      for (final dynamic rawItem
          in rawItems) {
        if (rawItem is Map) {
          items.add(
            _saleItemFromMap(
              Map<String, dynamic>.from(
                rawItem,
              ),
            ),
          );
        }
      }
    }

    final double subtotal =
        _toDouble(
      data['subtotal'],
    );

    final double discount =
        _toDouble(
      data['discount'],
    );

    final double tax =
        _toDouble(
      data['tax'],
    );

    final double total =
        _toDouble(
      data['total'],
    );

    final double paidAmount =
        _toDouble(
      data['paidAmount'],
    );

    final String rawId =
        data['id']
                ?.toString()
                .trim() ??
            '';

    final String rawBusinessId =
        data['businessId']
                ?.toString()
                .trim() ??
            '';

    final String rawPaymentStatus =
        data['paymentStatus']
                ?.toString()
                .trim() ??
            '';

    return SaleModel(
      id: rawId.isEmpty
          ? documentId
          : rawId,
      businessId:
          rawBusinessId.isEmpty
              ? businessId
              : rawBusinessId,
      customerId:
          data['customerId']
                  ?.toString() ??
              '',
      customerName:
          data['customerName']
                  ?.toString() ??
              '',
      items: items,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: total,
      paidAmount: paidAmount,
      paymentStatus:
          rawPaymentStatus.isEmpty
              ? _calculatePaymentStatus(
                  total: total,
                  paidAmount:
                      paidAmount,
                )
              : rawPaymentStatus,
      paymentMethod:
          data['paymentMethod']
                  ?.toString() ??
              '',
      date: dateFromFirestore(
        data['date'],
      ),
      notes:
          data['notes']?.toString() ??
              '',
      invoiceNumber:
          data['invoiceNumber']
                  ?.toString() ??
              '',
      createdAt:
          dateFromFirestore(
        data['createdAt'],
      ),
    );
  }

  SaleItemModel _saleItemFromMap(
    Map<String, dynamic> data,
  ) {
    return SaleItemModel(
      productId:
          data['productId']
                  ?.toString() ??
              '',
      productName:
          data['productName']
                  ?.toString() ??
              '',
      quantity:
          _toDouble(
        data['quantity'],
      ),
      unit:
          data['unit']?.toString() ??
              '',
      sellingRate:
          _toDouble(
        data['sellingRate'],
      ),
      discount:
          _toDouble(
        data['discount'],
      ),
      tax:
          _toDouble(
        data['tax'],
      ),
      total:
          _toDouble(
        data['total'],
      ),
      costPrice:
          _toDouble(
        data['costPrice'],
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
      return double.tryParse(
            value.trim(),
          ) ??
          0;
    }

    return 0;
  }
}
     
