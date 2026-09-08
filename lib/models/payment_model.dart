class PaymentModel {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final String transactionReference;
  final String notes;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.transactionReference = '',
    this.notes = '',
    required this.createdAt,
  });
}