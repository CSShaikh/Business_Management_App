class StockTransactionModel {
  final String id;
  final String businessId;
  final String productId;
  final String productName;
  final String transactionType;
  final double quantity;
  final double stockBefore;
  final double stockAfter;
  final double unitCost;
  final String referenceId;
  final DateTime date;
  final String notes;
  final DateTime createdAt;

  const StockTransactionModel({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.productName,
    required this.transactionType,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    required this.unitCost,
    this.referenceId = '',
    required this.date,
    this.notes = '',
    required this.createdAt,
  });
}