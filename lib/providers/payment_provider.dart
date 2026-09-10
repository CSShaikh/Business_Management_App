import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/payment_model.dart';
import '../repositories/payment_repository.dart';

class PaymentProvider extends ChangeNotifier {
  PaymentProvider({
    PaymentRepository? repository,
  }) : _repository = repository ?? PaymentRepository();

  final PaymentRepository _repository;

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  List<PaymentModel> _payments = <PaymentModel>[];

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;

  String _businessId = '';

  StreamSubscription<List<PaymentModel>>? _paymentSubscription;

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  List<PaymentModel> get payments => List.unmodifiable(_payments);

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get hasPayments => _payments.isNotEmpty;

  bool get isEmpty => _payments.isEmpty;

  String? get errorMessage => _errorMessage;

  String get businessId => _businessId;

  int get paymentCount => _payments.length;

  // ---------------------------------------------------------------------------
  // TOTALS
  // ---------------------------------------------------------------------------

  double get totalReceivedAmount {
    return _payments.fold<double>(
      0,
      (double total, PaymentModel payment) {
        return total + payment.amount;
      },
    );
  }

  double get todayReceivedAmount {
    final DateTime now = DateTime.now();

    return _payments
        .where(
          (PaymentModel payment) {
            return payment.date.year == now.year &&
                payment.date.month == now.month &&
                payment.date.day == now.day;
          },
        )
        .fold<double>(
          0,
          (double total, PaymentModel payment) {
            return total + payment.amount;
          },
        );
  }

  // ---------------------------------------------------------------------------
  // PAYMENT METHOD GETTERS
  // ---------------------------------------------------------------------------

  List<PaymentModel> get cashPayments {
    return _payments
        .where(
          (PaymentModel payment) =>
              payment.paymentMethod.trim().toLowerCase() == 'cash',
        )
        .toList();
  }

  List<PaymentModel> get upiPayments {
    return _payments
        .where(
          (PaymentModel payment) =>
              payment.paymentMethod.trim().toLowerCase() == 'upi',
        )
        .toList();
  }

  List<PaymentModel> get bankTransferPayments {
    return _payments
        .where(
          (PaymentModel payment) =>
              payment.paymentMethod.trim().toLowerCase() == 'bank transfer',
        )
        .toList();
  }

  List<PaymentModel> get chequePayments {
    return _payments
        .where(
          (PaymentModel payment) =>
              payment.paymentMethod.trim().toLowerCase() == 'cheque',
        )
        .toList();
  }

  List<PaymentModel> get otherPayments {
    return _payments
        .where(
          (PaymentModel payment) =>
              payment.paymentMethod.trim().toLowerCase() == 'other',
        )
        .toList();
  }

  int get cashPaymentCount => cashPayments.length;

  int get upiPaymentCount => upiPayments.length;

  int get bankTransferPaymentCount => bankTransferPayments.length;

  int get chequePaymentCount => chequePayments.length;

  int get otherPaymentCount => otherPayments.length;

  // ---------------------------------------------------------------------------
  // BUSINESS ID
  // ---------------------------------------------------------------------------

  void setBusinessId(String businessId) {
    final String id = businessId.trim();

    if (_businessId == id) {
      return;
    }

    _businessId = id;

    if (id.isEmpty) {
      clearPayments();
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD PAYMENTS
  // ---------------------------------------------------------------------------

  Future<List<PaymentModel>> loadPayments({
    String? businessId,
  }) async {
    final String id = (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required to load payments.',
      );
      return <PaymentModel>[];
    }

    _businessId = id;

    _setLoading(true);
    _clearError();

    try {
      final List<PaymentModel> payments =
          await _repository.getPayments(
        businessId: id,
      );

      _payments = List<PaymentModel>.from(payments);

      return List<PaymentModel>.from(_payments);
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to load payments.',
        ),
      );

      return <PaymentModel>[];
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // WATCH PAYMENTS
  // ---------------------------------------------------------------------------

  void watchPayments({
    String? businessId,
  }) {
    final String id = (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required to watch payments.',
      );
      return;
    }

    _businessId = id;

    _paymentSubscription?.cancel();

    _clearError();

    _paymentSubscription = _repository
        .watchPayments(
          businessId: id,
        )
        .listen(
          (List<PaymentModel> payments) {
            _payments = List<PaymentModel>.from(payments);
            notifyListeners();
          },
          onError: (Object error) {
            _setError(
              _formatError(
                error,
                fallback: 'Unable to receive payment updates.',
              ),
            );
          },
        );
  }

  // ---------------------------------------------------------------------------
  // LOAD + WATCH
  // ---------------------------------------------------------------------------

  Future<void> loadAndWatchPayments({
    String? businessId,
  }) async {
    final String id = (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return;
    }

    await loadPayments(
      businessId: id,
    );

    watchPayments(
      businessId: id,
    );
  }

  // ---------------------------------------------------------------------------
  // GET SINGLE PAYMENT
  // ---------------------------------------------------------------------------

  Future<PaymentModel?> getPayment({
    required String paymentId,
    String? businessId,
  }) async {
    final String id = (businessId ?? _businessId).trim();

    final String paymentDocumentId = paymentId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return null;
    }

    if (paymentDocumentId.isEmpty) {
      _setError(
        'Payment ID is required.',
      );
      return null;
    }

    _businessId = id;

    _clearError();

    try {
      return await _repository.getPayment(
        businessId: id,
        paymentId: paymentDocumentId,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to load payment details.',
        ),
      );

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CREATE PAYMENT
  // ---------------------------------------------------------------------------

  Future<PaymentModel?> createPayment(
    PaymentModel payment,
  ) async {
    final String id = payment.businessId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return null;
    }

    if (payment.customerId.trim().isEmpty) {
      _setError(
        'Customer ID is required.',
      );
      return null;
    }

    if (payment.customerName.trim().isEmpty) {
      _setError(
        'Customer name is required.',
      );
      return null;
    }

    if (!payment.amount.isFinite || payment.amount <= 0) {
      _setError(
        'Payment amount must be greater than zero.',
      );
      return null;
    }

    if (payment.paymentMethod.trim().isEmpty) {
      _setError(
        'Payment method is required.',
      );
      return null;
    }

    _businessId = id;

    _setSaving(true);
    _clearError();

    try {
      final PaymentModel savedPayment =
          await _repository.createPayment(
        payment,
      );

      _upsertLocalPayment(
        savedPayment,
      );

      return savedPayment;
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to create payment.',
        ),
      );

      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE PAYMENT
  // ---------------------------------------------------------------------------
  //
  // IMPORTANT:
  // A payment is linked with a customer ledger PAYMENT transaction.
  //
  // Directly updating the payment document would make the payment record and
  // customer ledger inconsistent.
  //
  // Therefore this method intentionally blocks direct updates until a
  // ledger-safe edit/reversal workflow is implemented.
  // ---------------------------------------------------------------------------

  Future<bool> updatePayment(
    PaymentModel payment,
  ) async {
    final String id = payment.businessId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return false;
    }

    if (payment.id.trim().isEmpty) {
      _setError(
        'Payment ID is required.',
      );
      return false;
    }

    _businessId = id;

    _setError(
      'Payment editing is disabled because this payment is linked to the customer ledger. '
      'Use a ledger-safe correction workflow.',
    );

    return false;
  }

  // ---------------------------------------------------------------------------
  // DELETE PAYMENT
  // ---------------------------------------------------------------------------
  //
  // IMPORTANT:
  // Deleting only the payment document is NOT safe because AddPaymentScreen
  // also creates a PAYMENT transaction in the customer ledger.
  //
  // A future ledger-safe delete must:
  //
  // 1. Read the payment.
  // 2. Create a corresponding ledger reversal.
  // 3. Delete the payment record.
  // 4. Keep the ledger balance correct.
  //
  // Until that workflow is implemented, direct deletion is blocked.
  // ---------------------------------------------------------------------------

  Future<bool> deletePayment({
    required String paymentId,
    String? businessId,
  }) async {
    final String id = (businessId ?? _businessId).trim();

    final String paymentDocumentId = paymentId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return false;
    }

    if (paymentDocumentId.isEmpty) {
      _setError(
        'Payment ID is required.',
      );
      return false;
    }

    _businessId = id;

    _setError(
      'Payment deletion is disabled because this payment is linked to the '
      'customer ledger. A ledger-safe reversal is required.',
    );

    return false;
  }

  // ---------------------------------------------------------------------------
  // CUSTOMER PAYMENTS
  // ---------------------------------------------------------------------------

  Future<List<PaymentModel>> getCustomerPayments({
    required String customerId,
    String? businessId,
  }) async {
    final String id = (businessId ?? _businessId).trim();

    final String customerDocumentId = customerId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );
      return <PaymentModel>[];
    }

    if (customerDocumentId.isEmpty) {
      _setError(
        'Customer ID is required.',
      );
      return <PaymentModel>[];
    }

    _businessId = id;

    _clearError();

    try {
      return await _repository.getCustomerPayments(
        businessId: id,
        customerId: customerDocumentId,
      );
    } catch (e) {
      _setError(
        _formatError(
          e,
          fallback: 'Unable to load customer payments.',
        ),
      );

      return <PaymentModel>[];
    }
  }

  // ---------------------------------------------------------------------------
  // WATCH CUSTOMER PAYMENTS
  // ---------------------------------------------------------------------------

  Stream<List<PaymentModel>> watchCustomerPayments({
    required String customerId,
    String? businessId,
  }) {
    final String id = (businessId ?? _businessId).trim();

    final String customerDocumentId = customerId.trim();

    if (id.isEmpty || customerDocumentId.isEmpty) {
      return const Stream<List<PaymentModel>>.empty();
    }

    return _repository.watchCustomerPayments(
      businessId: id,
      customerId: customerDocumentId,
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH PAYMENTS
  // ---------------------------------------------------------------------------

  List<PaymentModel> searchPayments(
    String query,
  ) {
    final String normalized =
        query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return List<PaymentModel>.from(_payments);
    }

    return _payments
        .where(
          (PaymentModel payment) {
            final String customerName =
                payment.customerName.trim().toLowerCase();

            final String customerId =
                payment.customerId.trim().toLowerCase();

            final String paymentMethod =
                payment.paymentMethod.trim().toLowerCase();

            final String transactionReference =
                payment.transactionReference.trim().toLowerCase();

            final String notes =
                payment.notes.trim().toLowerCase();

            final String amount =
                payment.amount.toStringAsFixed(2);

            final String date =
                '${payment.date.day.toString().padLeft(2, '0')}/'
                '${payment.date.month.toString().padLeft(2, '0')}/'
                '${payment.date.year}';

            return customerName.contains(normalized) ||
                customerId.contains(normalized) ||
                paymentMethod.contains(normalized) ||
                transactionReference.contains(normalized) ||
                notes.contains(normalized) ||
                amount.contains(normalized) ||
                date.contains(normalized);
          },
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // DATE FILTER
  // ---------------------------------------------------------------------------

  List<PaymentModel> filterByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final DateTime start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final DateTime end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    return _payments
        .where(
          (PaymentModel payment) {
            return !payment.date.isBefore(start) &&
                !payment.date.isAfter(end);
          },
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // CUSTOMER FILTER
  // ---------------------------------------------------------------------------

  List<PaymentModel> filterByCustomer(
    String customerId,
  ) {
    final String id = customerId.trim();

    if (id.isEmpty) {
      return List<PaymentModel>.from(_payments);
    }

    return _payments
        .where(
          (PaymentModel payment) =>
              payment.customerId.trim() == id,
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // PAYMENT METHOD FILTER
  // ---------------------------------------------------------------------------

  List<PaymentModel> filterByPaymentMethod(
    String paymentMethod,
  ) {
    final String normalized =
        paymentMethod.trim().toLowerCase();

    if (normalized.isEmpty) {
      return List<PaymentModel>.from(_payments);
    }

    return _payments
        .where(
          (PaymentModel payment) =>
              payment.paymentMethod.trim().toLowerCase() ==
              normalized,
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // FIND PAYMENT BY ID
  // ---------------------------------------------------------------------------

  PaymentModel? findPaymentById(
    String paymentId,
  ) {
    final String id = paymentId.trim();

    if (id.isEmpty) {
      return null;
    }

    for (final PaymentModel payment in _payments) {
      if (payment.id.trim() == id) {
        return payment;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // FIND PAYMENTS BY CUSTOMER
  // ---------------------------------------------------------------------------

  List<PaymentModel> findPaymentsByCustomer(
    String customerId,
  ) {
    final String id = customerId.trim();

    if (id.isEmpty) {
      return <PaymentModel>[];
    }

    return _payments
        .where(
          (PaymentModel payment) =>
              payment.customerId.trim() == id,
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // CUSTOMER RECEIVED TOTAL
  // ---------------------------------------------------------------------------

  double getCustomerReceivedAmount(
    String customerId,
  ) {
    final String id = customerId.trim();

    if (id.isEmpty) {
      return 0;
    }

    return _payments
        .where(
          (PaymentModel payment) =>
              payment.customerId.trim() == id,
        )
        .fold<double>(
          0,
          (double total, PaymentModel payment) {
            return total + payment.amount;
          },
        );
  }

  // ---------------------------------------------------------------------------
  // DATE RANGE RECEIVED TOTAL
  // ---------------------------------------------------------------------------

  double getReceivedAmountForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final List<PaymentModel> filtered =
        filterByDateRange(
      startDate: startDate,
      endDate: endDate,
    );

    return filtered.fold<double>(
      0,
      (double total, PaymentModel payment) {
        return total + payment.amount;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // METHOD TOTALS
  // ---------------------------------------------------------------------------

  double getCashReceivedAmount() {
    return cashPayments.fold<double>(
      0,
      (double total, PaymentModel payment) {
        return total + payment.amount;
      },
    );
  }

  double getUpiReceivedAmount() {
    return upiPayments.fold<double>(
      0,
      (double total, PaymentModel payment) {
        return total + payment.amount;
      },
    );
  }

  double getBankTransferReceivedAmount() {
    return bankTransferPayments.fold<double>(
      0,
      (double total, PaymentModel payment) {
        return total + payment.amount;
      },
    );
  }

  double getChequeReceivedAmount() {
    return chequePayments.fold<double>(
      0,
      (double total, PaymentModel payment) {
        return total + payment.amount;
      },
    );
  }

  double getOtherReceivedAmount() {
    return otherPayments.fold<double>(
      0,
      (double total, PaymentModel payment) {
        return total + payment.amount;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // LOCAL UPSERT
  // ---------------------------------------------------------------------------

  void _upsertLocalPayment(
    PaymentModel payment,
  ) {
    final String paymentId = payment.id.trim();

    if (paymentId.isEmpty) {
      return;
    }

    final int index = _payments.indexWhere(
      (PaymentModel item) =>
          item.id.trim() == paymentId,
    );

    if (index == -1) {
      _payments.add(payment);
    } else {
      _payments[index] = payment;
    }

    _payments.sort(
      (PaymentModel a, PaymentModel b) {
        final int dateCompare =
            b.date.compareTo(a.date);

        if (dateCompare != 0) {
          return dateCompare;
        }

        return b.createdAt.compareTo(
          a.createdAt,
        );
      },
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CLEAR
  // ---------------------------------------------------------------------------

  void clearPayments() {
    _paymentSubscription?.cancel();

    _paymentSubscription = null;

    _payments = <PaymentModel>[];

    _clearError();

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> refresh() async {
    final String id = _businessId.trim();

    if (id.isEmpty) {
      return;
    }

    await loadPayments(
      businessId: id,
    );
  }

  // ---------------------------------------------------------------------------
  // LOADING
  // ---------------------------------------------------------------------------

  void _setLoading(
    bool value,
  ) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SAVING
  // ---------------------------------------------------------------------------

  void _setSaving(
    bool value,
  ) {
    if (_isSaving == value) {
      return;
    }

    _isSaving = value;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ERROR
  // ---------------------------------------------------------------------------

  void _setError(
    String message,
  ) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ERROR FORMATTER
  // ---------------------------------------------------------------------------

  String _formatError(
    Object error, {
    required String fallback,
  }) {
    if (error is ArgumentError) {
      final String message =
          error.message?.toString().trim() ?? '';

      if (message.isNotEmpty) {
        return message;
      }
    }

    if (error is StateError) {
      final String message =
          error.message.trim();

      if (message.isNotEmpty) {
        return message;
      }
    }

    final String message =
        error.toString().trim();

    if (message.isEmpty ||
        message == 'Exception') {
      return fallback;
    }

    if (message.startsWith('Exception:')) {
      final String cleaned =
          message.substring('Exception:'.length).trim();

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return message;
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    _paymentSubscription = null;

    super.dispose();
  }
}