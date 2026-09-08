class PurchaseItemModel {
  final String productId;
  final String productName;
  final double quantity;
  final String unit;
  final double purchaseRate;
  final double total;

  const PurchaseItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.purchaseRate,
    required this.total,
  });
}

class PurchaseModel {
  final String id;
  final String businessId;
  final String supplierId;
  final String supplierName;
  final List<PurchaseItemModel> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paidAmount;
  final String paymentStatus;
  final String paymentMethod;
  final DateTime date;
  final String notes;
  final DateTime createdAt;

  const PurchaseModel({
    required this.id,
    required this.businessId,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    this.paidAmount = 0,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.date,
    this.notes = '',
    required this.createdAt,
  });
}