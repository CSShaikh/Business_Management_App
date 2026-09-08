class LedgerTransactionModel {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final String transactionType;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String referenceId;
  final DateTime date;
  final String notes;
  final DateTime createdAt;

  const LedgerTransactionModel({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.transactionType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.referenceId = '',
    required this.date,
    this.notes = '',
    required this.createdAt,
  });
}