class SaleItemModel {
  final String productId;
  final String productName;
  final double quantity;
  final String unit;
  final double sellingRate;
  final double discount;
  final double tax;
  final double total;
  final double costPrice;

  const SaleItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.sellingRate,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    required this.costPrice,
  });

  // ---------------------------------------------------------------------------
  // COPY
  // ---------------------------------------------------------------------------

  SaleItemModel copyWith({
    String? productId,
    String? productName,
    double? quantity,
    String? unit,
    double? sellingRate,
    double? discount,
    double? tax,
    double? total,
    double? costPrice,
  }) {
    return SaleItemModel(
      productId:
          productId ?? this.productId,
      productName:
          productName ?? this.productName,
      quantity:
          quantity ?? this.quantity,
      unit:
          unit ?? this.unit,
      sellingRate:
          sellingRate ?? this.sellingRate,
      discount:
          discount ?? this.discount,
      tax:
          tax ?? this.tax,
      total:
          total ?? this.total,
      costPrice:
          costPrice ?? this.costPrice,
    );
  }

  // ---------------------------------------------------------------------------
  // SERIALIZATION
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unit': unit,
      'sellingRate': sellingRate,
      'discount': discount,
      'tax': tax,
      'total': total,
      'costPrice': costPrice,
    };
  }

  factory SaleItemModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return SaleItemModel(
      productId:
          map['productId']?.toString() ?? '',
      productName:
          map['productName']?.toString() ?? '',
      quantity:
          _toDouble(map['quantity']),
      unit:
          map['unit']?.toString() ?? '',
      sellingRate:
          _toDouble(map['sellingRate']),
      discount:
          _toDouble(map['discount']),
      tax:
          _toDouble(map['tax']),
      total:
          _toDouble(map['total']),
      costPrice:
          _toDouble(map['costPrice']),
    );
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  bool get isValid {
    return productId.trim().isNotEmpty &&
        quantity.isFinite &&
        quantity > 0 &&
        sellingRate.isFinite &&
        sellingRate >= 0 &&
        discount.isFinite &&
        discount >= 0 &&
        tax.isFinite &&
        tax >= 0 &&
        total.isFinite &&
        total >= 0 &&
        costPrice.isFinite &&
        costPrice >= 0;
  }

  static double _toDouble(
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
}

// =============================================================================
// SALE MODEL
// =============================================================================

class SaleModel {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final List<SaleItemModel> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paidAmount;
  final String paymentStatus;
  final String paymentMethod;
  final DateTime date;
  final String notes;
  final String invoiceNumber;
  final DateTime createdAt;

  const SaleModel({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    this.paidAmount = 0,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.date,
    required this.notes,
    required this.invoiceNumber,
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // COPY
  // ---------------------------------------------------------------------------

  SaleModel copyWith({
    String? id,
    String? businessId,
    String? customerId,
    String? customerName,
    List<SaleItemModel>? items,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    double? paidAmount,
    String? paymentStatus,
    String? paymentMethod,
    DateTime? date,
    String? notes,
    String? invoiceNumber,
    DateTime? createdAt,
  }) {
    return SaleModel(
      id: id ?? this.id,
      businessId:
          businessId ?? this.businessId,
      customerId:
          customerId ?? this.customerId,
      customerName:
          customerName ?? this.customerName,
      items: List<SaleItemModel>.unmodifiable(
        items ?? this.items,
      ),
      subtotal:
          subtotal ?? this.subtotal,
      discount:
          discount ?? this.discount,
      tax:
          tax ?? this.tax,
      total:
          total ?? this.total,
      paidAmount:
          paidAmount ?? this.paidAmount,
      paymentStatus:
          paymentStatus ?? this.paymentStatus,
      paymentMethod:
          paymentMethod ?? this.paymentMethod,
      date:
          date ?? this.date,
      notes:
          notes ?? this.notes,
      invoiceNumber:
          invoiceNumber ?? this.invoiceNumber,
      createdAt:
          createdAt ?? this.createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // CALCULATED VALUES
  // ---------------------------------------------------------------------------

  double get pendingAmount {
    final double value =
        total - paidAmount;

    if (!value.isFinite ||
        value <= 0) {
      return 0;
    }

    return value;
  }

  bool get isFullyPaid {
    if (!total.isFinite ||
        !paidAmount.isFinite) {
      return false;
    }

    return paidAmount >=
        total - 0.000001;
  }

  bool get isPartiallyPaid {
    if (!total.isFinite ||
        !paidAmount.isFinite) {
      return false;
    }

    return paidAmount > 0 &&
        paidAmount <
            total - 0.000001;
  }

  bool get isUnpaid {
    return paidAmount <=
        0.000001;
  }

  double get paymentPercentage {
    if (!total.isFinite ||
        total <= 0 ||
        !paidAmount.isFinite) {
      return 0;
    }

    final double percentage =
        (paidAmount / total) * 100;

    if (!percentage.isFinite) {
      return 0;
    }

    if (percentage < 0) {
      return 0;
    }

    if (percentage > 100) {
      return 100;
    }

    return percentage;
  }

  // ---------------------------------------------------------------------------
  // SERIALIZATION
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'customerId': customerId,
      'customerName': customerName,
      'items': items
          .map(
            (
              SaleItemModel item,
            ) =>
                item.toMap(),
          )
          .toList(
            growable: false,
          ),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'paidAmount': paidAmount,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'date': date,
      'notes': notes,
      'invoiceNumber': invoiceNumber,
      'createdAt': createdAt,
    };
  }

  factory SaleModel.fromMap(
    Map<String, dynamic> map,
  ) {
    final dynamic rawItems =
        map['items'];

    final List<SaleItemModel> parsedItems =
        <SaleItemModel>[];

    if (rawItems is List) {
      for (final dynamic item
          in rawItems) {
        if (item is Map) {
          parsedItems.add(
            SaleItemModel.fromMap(
              Map<String, dynamic>.from(
                item,
              ),
            ),
          );
        }
      }
    }

    final double total =
        _toDouble(
      map['total'],
    );

    final double paidAmount =
        _toDouble(
      map['paidAmount'],
    );

    return SaleModel(
      id:
          map['id']?.toString() ?? '',
      businessId:
          map['businessId']?.toString() ?? '',
      customerId:
          map['customerId']?.toString() ?? '',
      customerName:
          map['customerName']?.toString() ?? '',
      items:
          List<SaleItemModel>.unmodifiable(
        parsedItems,
      ),
      subtotal:
          _toDouble(map['subtotal']),
      discount:
          _toDouble(map['discount']),
      tax:
          _toDouble(map['tax']),
      total:
          total,
      paidAmount:
          paidAmount,
      paymentStatus:
          _normalizePaymentStatus(
        map['paymentStatus'],
        total: total,
        paidAmount: paidAmount,
      ),
      paymentMethod:
          map['paymentMethod']?.toString() ?? '',
      date:
          _dateFromMap(
        map['date'],
      ),
      notes:
          map['notes']?.toString() ?? '',
      invoiceNumber:
          map['invoiceNumber']?.toString() ?? '',
      createdAt:
          _dateFromMap(
        map['createdAt'],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  bool get isValid {
    if (businessId.trim().isEmpty) {
      return false;
    }

    if (items.isEmpty) {
      return false;
    }

    if (!subtotal.isFinite ||
        subtotal < 0) {
      return false;
    }

    if (!discount.isFinite ||
        discount < 0) {
      return false;
    }

    if (!tax.isFinite ||
        tax < 0) {
      return false;
    }

    if (!total.isFinite ||
        total < 0) {
      return false;
    }

    if (!paidAmount.isFinite ||
        paidAmount < 0 ||
        paidAmount > total) {
      return false;
    }

    if (!date.isUtc &&
        date.millisecondsSinceEpoch <= 0) {
      return false;
    }

    for (final SaleItemModel item
        in items) {
      if (!item.isValid) {
        return false;
      }
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // PRIVATE HELPERS
  // ---------------------------------------------------------------------------

  static double _toDouble(
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

  static String _normalizePaymentStatus(
    dynamic value, {
    required double total,
    required double paidAmount,
  }) {
    final String status =
        value?.toString().trim() ?? '';

    if (status.isNotEmpty) {
      return status;
    }

    if (total <= 0 ||
        paidAmount >=
            total - 0.000001) {
      return 'Paid';
    }

    if (paidAmount <=
        0.000001) {
      return 'Unpaid';
    }

    return 'Partial';
  }

  static DateTime _dateFromMap(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final DateTime? parsed =
          DateTime.tryParse(
        value,
      );

      if (parsed != null) {
        return parsed;
      }
    }

    // Keep the model safe for legacy/malformed records.
    return DateTime.fromMillisecondsSinceEpoch(
      0,
    );
  }
}