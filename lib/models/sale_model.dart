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
}

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
}