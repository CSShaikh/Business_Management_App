import '../../models/ledger_transaction_model.dart';
import '../../models/payment_model.dart';
import '../ledger/ledger_service.dart';

class PaymentLedgerService {
  PaymentLedgerService({
    LedgerService? ledgerService,
  }) : _ledgerService =
            ledgerService ?? LedgerService();

  final LedgerService _ledgerService;

  // ---------------------------------------------------------------------------
  // CREATE PAYMENT LEDGER ENTRY
  // ---------------------------------------------------------------------------

  Future<LedgerTransactionModel> createPaymentLedgerEntry({
    required PaymentModel payment,
    required double balanceBefore,
  }) async {
    final String businessId =
        payment.businessId.trim();

    final String customerId =
        payment.customerId.trim();

    final String customerName =
        payment.customerName.trim();

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (customerId.isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    if (customerName.isEmpty) {
      throw ArgumentError(
        'Customer name cannot be empty.',
      );
    }

    if (!payment.amount.isFinite ||
        payment.amount <= 0) {
      throw ArgumentError(
        'Payment amount must be greater than zero.',
      );
    }

    if (!balanceBefore.isFinite) {
      throw ArgumentError(
        'Balance before must be a valid number.',
      );
    }

    final double balanceAfter =
        balanceBefore - payment.amount;

    return _ledgerService.createTransaction(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      transactionType: 'PAYMENT',
      amount: payment.amount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      referenceId: payment.id.trim(),
      date: payment.date,
      notes: _buildPaymentNotes(payment),
    );
  }

  // ---------------------------------------------------------------------------
  // CREATE REVERSAL ENTRY
  // ---------------------------------------------------------------------------
  //
  // A payment decreases customer outstanding.
  //
  // If that payment is cancelled/deleted, the amount must be added back to
  // outstanding.
  //
  // Example:
  //
  // Before payment:
  // outstanding = 5000
  //
  // Payment:
  // 1000
  //
  // After payment:
  // outstanding = 4000
  //
  // Reversal:
  // outstanding = 5000
  //
  // We therefore create a PAYMENT_REVERSAL ledger transaction.
  // ---------------------------------------------------------------------------

  Future<LedgerTransactionModel> createPaymentReversal({
    required PaymentModel payment,
    required double balanceBefore,
  }) async {
    final String businessId =
        payment.businessId.trim();

    final String customerId =
        payment.customerId.trim();

    final String customerName =
        payment.customerName.trim();

    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (customerId.isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    if (customerName.isEmpty) {
      throw ArgumentError(
        'Customer name cannot be empty.',
      );
    }

    if (!payment.amount.isFinite ||
        payment.amount <= 0) {
      throw ArgumentError(
        'Payment amount must be greater than zero.',
      );
    }

    if (!balanceBefore.isFinite) {
      throw ArgumentError(
        'Balance before must be a valid number.',
      );
    }

    final double balanceAfter =
        balanceBefore + payment.amount;

    return _ledgerService.createTransaction(
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      transactionType: 'PAYMENT_REVERSAL',
      amount: payment.amount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      referenceId: payment.id.trim(),
      date: DateTime.now(),
      notes: _buildReversalNotes(payment),
    );
  }

  // ---------------------------------------------------------------------------
  // VALIDATE PAYMENT
  // ---------------------------------------------------------------------------

  void validatePayment(
    PaymentModel payment,
  ) {
    if (payment.businessId.trim().isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (payment.customerId.trim().isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    if (payment.customerName.trim().isEmpty) {
      throw ArgumentError(
        'Customer name cannot be empty.',
      );
    }

    if (!payment.amount.isFinite ||
        payment.amount <= 0) {
      throw ArgumentError(
        'Payment amount must be greater than zero.',
      );
    }

    if (payment.paymentMethod.trim().isEmpty) {
      throw ArgumentError(
        'Payment method cannot be empty.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PAYMENT NOTES
  // ---------------------------------------------------------------------------

  String _buildPaymentNotes(
    PaymentModel payment,
  ) {
    final List<String> parts =
        <String>[];

    final String method =
        payment.paymentMethod.trim();

    final String reference =
        payment.transactionReference.trim();

    final String notes =
        payment.notes.trim();

    if (method.isNotEmpty) {
      parts.add(
        'Method: $method',
      );
    }

    if (reference.isNotEmpty) {
      parts.add(
        'Reference: $reference',
      );
    }

    if (notes.isNotEmpty) {
      parts.add(notes);
    }

    return parts.join(' | ');
  }

  // ---------------------------------------------------------------------------
  // REVERSAL NOTES
  // ---------------------------------------------------------------------------

  String _buildReversalNotes(
    PaymentModel payment,
  ) {
    final String paymentId =
        payment.id.trim();

    final String method =
        payment.paymentMethod.trim();

    final String reference =
        payment.transactionReference.trim();

    final List<String> parts =
        <String>[
      'Reversal of payment',
    ];

    if (paymentId.isNotEmpty) {
      parts.add(
        'Payment ID: $paymentId',
      );
    }

    if (method.isNotEmpty) {
      parts.add(
        'Method: $method',
      );
    }

    if (reference.isNotEmpty) {
      parts.add(
        'Reference: $reference',
      );
    }

    return parts.join(' | ');
  }
}