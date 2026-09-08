class ExpenseModel {
  final String id;
  final String businessId;
  final String category;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final String description;
  final String notes;
  final String receiptUrl;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.businessId,
    required this.category,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.description = '',
    this.notes = '',
    this.receiptUrl = '',
    required this.createdAt,
  });
}