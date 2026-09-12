import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/supplier_payment_model.dart';
import '../repositories/supplier_payment_repository.dart';

class SupplierPaymentProvider extends ChangeNotifier {
  SupplierPaymentProvider({
    SupplierPaymentRepository? repository,
  }) : _repository =
            repository ?? SupplierPaymentRepository();

  final SupplierPaymentRepository _repository;

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  List<SupplierPaymentModel> _payments =
      <SupplierPaymentModel>[];

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;

  String _businessId = '';

  StreamSubscription<List<SupplierPaymentModel>>?
      _paymentSubscription;

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  List<SupplierPaymentModel> get payments =>
      List<SupplierPaymentModel>.unmodifiable(
        _payments,
      );

  bool get isLoading =>
      _isLoading;

  bool get isSaving =>
      _isSaving;

  bool get hasPayments =>
      _payments.isNotEmpty;

  bool get isEmpty =>
      _payments.isEmpty;

  String? get errorMessage =>
      _errorMessage;

  String get businessId =>
      _businessId;

  int get paymentCount =>
      _payments.length;

  // ---------------------------------------------------------------------------
  // TOTALS
  // ---------------------------------------------------------------------------

  double get totalPaidAmount {
    return _payments.fold<double>(
      0,
      (
        double total,
        SupplierPaymentModel payment,
      ) {
        return total + payment.amount;
      },
    );
  }

  double get todayPaidAmount {
    final DateTime now = DateTime.now();

    return _payments
        .where(
          (SupplierPaymentModel payment) {
            return payment.date.year == now.year &&
                payment.date.month == now.month &&
                payment.date.day == now.day;
          },
        )
        .fold<double>(
          0,
          (
            double total,
            SupplierPaymentModel payment,
          ) {
            return total + payment.amount;
          },
        );
  }

  // ---------------------------------------------------------------------------
  // PAYMENT METHOD GETTERS
  // ---------------------------------------------------------------------------

  List<SupplierPaymentModel> get cashPayments {
    return _payments
        .where(
          (SupplierPaymentModel payment) =>
              payment.paymentMethod
                  .trim()
                  .toLowerCase() ==
              'cash',
        )
        .toList();
  }

  List<SupplierPaymentModel> get upiPayments {
    return _payments
        .where(
          (SupplierPaymentModel payment) =>
              payment.paymentMethod
                  .trim()
                  .toLowerCase() ==
              'upi',
        )
        .toList();
  }

  List<SupplierPaymentModel> get bankTransferPayments {
    return _payments
        .where(
          (SupplierPaymentModel payment) =>
              payment.paymentMethod
                  .trim()
                  .toLowerCase() ==
              'bank transfer',
        )
        .toList();
  }

  List<SupplierPaymentModel> get chequePayments {
    return _payments
        .where(
          (SupplierPaymentModel payment) =>
              payment.paymentMethod
                  .trim()
                  .toLowerCase() ==
              'cheque',
        )
        .toList();
  }

  List<SupplierPaymentModel> get otherPayments {
    return _payments
        .where(
          (SupplierPaymentModel payment) =>
              payment.paymentMethod
                  .trim()
                  .toLowerCase() ==
              'other',
        )
        .toList();
  }

  int get cashPaymentCount =>
      cashPayments.length;

  int get upiPaymentCount =>
      upiPayments.length;

  int get bankTransferPaymentCount =>
      bankTransferPayments.length;

  int get chequePaymentCount =>
      chequePayments.length;

  int get otherPaymentCount =>
      otherPayments.length;

  // ---------------------------------------------------------------------------
  // BUSINESS ID
  // ---------------------------------------------------------------------------

  void setBusinessId(
    String businessId,
  ) {
    final String id =
        businessId.trim();

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

  Future<List<SupplierPaymentModel>>
      loadPayments({
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required to load supplier payments.',
      );

      return <SupplierPaymentModel>[];
    }

    _businessId = id;

    _setLoading(true);
    _clearError();

    try {
      final List<SupplierPaymentModel>
          payments =
          await _repository.getPayments(
        businessId: id,
      );

      _payments =
          List<SupplierPaymentModel>.from(
        payments,
      );

      return List<SupplierPaymentModel>.unmodifiable(
        _payments,
      );
    } catch (error) {
      _setError(
        _formatError(
          error,
          fallback:
              'Unable to load supplier payments.',
        ),
      );

      return <SupplierPaymentModel>[];
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
    final String id =
        (businessId ?? _businessId).trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required to watch supplier payments.',
      );

      return;
    }

    _businessId = id;

    _paymentSubscription?.cancel();

    _clearError();

    _paymentSubscription =
        _repository.watchPayments(
      businessId: id,
    ).listen(
      (
        List<SupplierPaymentModel> payments,
      ) {
        _payments =
            List<SupplierPaymentModel>.from(
          payments,
        );

        notifyListeners();
      },
      onError: (Object error) {
        _setError(
          _formatError(
            error,
            fallback:
                'Unable to receive supplier payment updates.',
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
    final String id =
        (businessId ?? _businessId).trim();

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

  Future<SupplierPaymentModel?>
      getPayment({
    required String paymentId,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String paymentDocumentId =
        paymentId.trim();

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
    } catch (error) {
      _setError(
        _formatError(
          error,
          fallback:
              'Unable to load supplier payment details.',
        ),
      );

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CREATE PAYMENT
  // ---------------------------------------------------------------------------
  //
  // IMPORTANT:
  // The supplier ledger is intentionally NOT updated inside this provider.
  //
  // Supplier payment creation has two related operations:
  //
  // 1. Save supplier payment record.
  // 2. Create SUPPLIER_PAYMENT ledger transaction.
  //
  // SupplierLedgerService handles the ledger/business rules.
  // AddSupplierPaymentScreen will coordinate both operations.
  // ---------------------------------------------------------------------------

  Future<SupplierPaymentModel?>
      createPayment(
    SupplierPaymentModel payment,
  ) async {
    final String id =
        payment.businessId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );

      return null;
    }

    if (payment.supplierId.trim().isEmpty) {
      _setError(
        'Supplier ID is required.',
      );

      return null;
    }

    if (payment.supplierName.trim().isEmpty) {
      _setError(
        'Supplier name is required.',
      );

      return null;
    }

    if (!payment.amount.isFinite ||
        payment.amount <= 0) {
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
      final SupplierPaymentModel
          savedPayment =
          await _repository.createPayment(
        payment,
      );

      _upsertLocalPayment(
        savedPayment,
      );

      return savedPayment;
    } catch (error) {
      _setError(
        _formatError(
          error,
          fallback:
              'Unable to create supplier payment.',
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
  // The screen/service must first reverse the old supplier ledger transaction
  // before updating the payment record and creating the new ledger entry.
  // ---------------------------------------------------------------------------

  Future<bool> updatePayment(
    SupplierPaymentModel payment,
  ) async {
    final String id =
        payment.businessId.trim();

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

    if (payment.supplierId.trim().isEmpty) {
      _setError(
        'Supplier ID is required.',
      );

      return false;
    }

    if (payment.supplierName.trim().isEmpty) {
      _setError(
        'Supplier name is required.',
      );

      return false;
    }

    if (!payment.amount.isFinite ||
        payment.amount <= 0) {
      _setError(
        'Payment amount must be greater than zero.',
      );

      return false;
    }

    if (payment.paymentMethod.trim().isEmpty) {
      _setError(
        'Payment method is required.',
      );

      return false;
    }

    _businessId = id;

    _setSaving(true);
    _clearError();

    try {
      await _repository.updatePayment(
        payment,
      );

      _upsertLocalPayment(
        payment,
      );

      return true;
    } catch (error) {
      _setError(
        _formatError(
          error,
          fallback:
              'Unable to update supplier payment.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE PAYMENT
  // ---------------------------------------------------------------------------
  //
  // The screen must create SUPPLIER_PAYMENT_REVERSAL before deleting the
  // payment record so the supplier payable remains correct.
  // ---------------------------------------------------------------------------

  Future<bool> deletePayment({
    required String paymentId,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String paymentDocumentId =
        paymentId.trim();

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

    _setSaving(true);
    _clearError();

    try {
      await _repository.deletePayment(
        businessId: id,
        paymentId: paymentDocumentId,
      );

      _payments.removeWhere(
        (SupplierPaymentModel payment) =>
            payment.id.trim() ==
            paymentDocumentId,
      );

      notifyListeners();

      return true;
    } catch (error) {
      _setError(
        _formatError(
          error,
          fallback:
              'Unable to delete supplier payment.',
        ),
      );

      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // SUPPLIER PAYMENTS
  // ---------------------------------------------------------------------------

  Future<List<SupplierPaymentModel>>
      getSupplierPayments({
    required String supplierId,
    String? businessId,
  }) async {
    final String id =
        (businessId ?? _businessId).trim();

    final String supplierDocumentId =
        supplierId.trim();

    if (id.isEmpty) {
      _setError(
        'Business ID is required.',
      );

      return <SupplierPaymentModel>[];
    }

    if (supplierDocumentId.isEmpty) {
      _setError(
        'Supplier ID is required.',
      );

      return <SupplierPaymentModel>[];
    }

    _businessId = id;

    _clearError();

    try {
      return await _repository.getSupplierPayments(
        businessId: id,
        supplierId: supplierDocumentId,
      );
    } catch (error) {
      _setError(
        _formatError(
          error,
          fallback:
              'Unable to load supplier payments.',
        ),
      );

      return <SupplierPaymentModel>[];
    }
  }

  // ---------------------------------------------------------------------------
  // WATCH SUPPLIER PAYMENTS
  // ---------------------------------------------------------------------------

  Stream<List<SupplierPaymentModel>>
      watchSupplierPayments({
    required String supplierId,
    String? businessId,
  }) {
    final String id =
        (businessId ?? _businessId).trim();

    final String supplierDocumentId =
        supplierId.trim();

    if (id.isEmpty ||
        supplierDocumentId.isEmpty) {
      return const Stream<
          List<SupplierPaymentModel>>.empty();
    }

    return _repository.watchSupplierPayments(
      businessId: id,
      supplierId: supplierDocumentId,
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH PAYMENTS
  // ---------------------------------------------------------------------------

  List<SupplierPaymentModel> searchPayments(
    String query,
  ) {
    final String normalized =
        query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return List<SupplierPaymentModel>.from(
        _payments,
      );
    }

    return _payments
        .where(
          (SupplierPaymentModel payment) {
            final String supplierName =
                payment.supplierName
                    .trim()
                    .toLowerCase();

            final String supplierId =
                payment.supplierId
                    .trim()
                    .toLowerCase();

            final String paymentMethod =
                payment.paymentMethod
                    .trim()
                    .toLowerCase();

            final String transactionReference =
                payment.transactionReference
                    .trim()
                    .toLowerCase();

            final String notes =
                payment.notes
                    .trim()
                    .toLowerCase();

            final String amount =
                payment.amount
                    .toStringAsFixed(2);

            final String date =
                '${payment.date.day.toString().padLeft(2, '0')}/'
                '${payment.date.month.toString().padLeft(2, '0')}/'
                '${payment.date.year}';

            return supplierName.contains(
                  normalized,
                ) ||
                supplierId.contains(
                  normalized,
                ) ||
                paymentMethod.contains(
                  normalized,
                ) ||
                transactionReference.contains(
                  normalized,
                ) ||
                notes.contains(
                  normalized,
                ) ||
                amount.contains(
                  normalized,
                ) ||
                date.contains(
                  normalized,
                );
          },
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // DATE FILTER
  // ---------------------------------------------------------------------------

  List<SupplierPaymentModel>
      filterByDateRange({
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
          (SupplierPaymentModel payment) {
            return !payment.date.isBefore(
                  start,
                ) &&
                !payment.date.isAfter(
                  end,
                );
          },
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // SUPPLIER FILTER
  // ---------------------------------------------------------------------------

  List<SupplierPaymentModel>
      filterBySupplier(
    String supplierId,
  ) {
    final String id =
        supplierId.trim();

    if (id.isEmpty) {
      return List<SupplierPaymentModel>.from(
        _payments,
      );
    }

    return _payments
        .where(
          (SupplierPaymentModel payment) =>
              payment.supplierId.trim() ==
              id,
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // PAYMENT METHOD FILTER
  // ---------------------------------------------------------------------------

  List<SupplierPaymentModel>
      filterByPaymentMethod(
    String paymentMethod,
  ) {
    final String normalized =
        paymentMethod.trim().toLowerCase();

    if (normalized.isEmpty) {
      return List<SupplierPaymentModel>.from(
        _payments,
      );
    }

    return _payments
        .where(
          (SupplierPaymentModel payment) =>
              payment.paymentMethod
                  .trim()
                  .toLowerCase() ==
              normalized,
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // FIND PAYMENT BY ID
  // ---------------------------------------------------------------------------

  SupplierPaymentModel? findPaymentById(
    String paymentId,
  ) {
    final String id =
        paymentId.trim();

    if (id.isEmpty) {
      return null;
    }

    for (
      final SupplierPaymentModel payment
          in _payments
    ) {
      if (payment.id.trim() == id) {
        return payment;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // FIND PAYMENTS BY SUPPLIER
  // ---------------------------------------------------------------------------

  List<SupplierPaymentModel>
      findPaymentsBySupplier(
    String supplierId,
  ) {
    final String id =
        supplierId.trim();

    if (id.isEmpty) {
      return <SupplierPaymentModel>[];
    }

    return _payments
        .where(
          (SupplierPaymentModel payment) =>
              payment.supplierId.trim() ==
              id,
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // SUPPLIER PAID TOTAL
  // ---------------------------------------------------------------------------

  double getSupplierPaidAmount(
    String supplierId,
  ) {
    final String id =
        supplierId.trim();

    if (id.isEmpty) {
      return 0;
    }

    return _payments
        .where(
          (SupplierPaymentModel payment) =>
              payment.supplierId.trim() ==
              id,
        )
        .fold<double>(
          0,
          (
            double total,
            SupplierPaymentModel payment,
          ) {
            return total + payment.amount;
          },
        );
  }

  // ---------------------------------------------------------------------------
  // DATE RANGE PAID TOTAL
  // ---------------------------------------------------------------------------

  double getPaidAmountForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final List<SupplierPaymentModel>
        filtered =
        filterByDateRange(
      startDate: startDate,
      endDate: endDate,
    );

    return filtered.fold<double>(
      0,
      (
        double total,
        SupplierPaymentModel payment,
      ) {
        return total + payment.amount;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // PAYMENT METHOD TOTALS
  // ---------------------------------------------------------------------------

  double getCashPaidAmount() {
    return cashPayments.fold<double>(
      0,
      (
        double total,
        SupplierPaymentModel payment,
      ) {
        return total + payment.amount;
      },
    );
  }

  double getUpiPaidAmount() {
    return upiPayments.fold<double>(
      0,
      (
        double total,
        SupplierPaymentModel payment,
      ) {
        return total + payment.amount;
      },
    );
  }

  double getBankTransferPaidAmount() {
    return bankTransferPayments.fold<double>(
      0,
      (
        double total,
        SupplierPaymentModel payment,
      ) {
        return total + payment.amount;
      },
    );
  }

  double getChequePaidAmount() {
    return chequePayments.fold<double>(
      0,
      (
        double total,
        SupplierPaymentModel payment,
      ) {
        return total + payment.amount;
      },
    );
  }

  double getOtherPaidAmount() {
    return otherPayments.fold<double>(
      0,
      (
        double total,
        SupplierPaymentModel payment,
      ) {
        return total + payment.amount;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // LOCAL UPSERT
  // ---------------------------------------------------------------------------

  void _upsertLocalPayment(
    SupplierPaymentModel payment,
  ) {
    final String paymentId =
        payment.id.trim();

    if (paymentId.isEmpty) {
      return;
    }

    final int index =
        _payments.indexWhere(
      (SupplierPaymentModel item) =>
          item.id.trim() == paymentId,
    );

    if (index == -1) {
      _payments.add(payment);
    } else {
      _payments[index] = payment;
    }

    _payments.sort(
      (
        SupplierPaymentModel a,
        SupplierPaymentModel b,
      ) {
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

    _payments =
        <SupplierPaymentModel>[];

    _clearError();

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> refresh() async {
    final String id =
        _businessId.trim();

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
          error.message?.toString().trim() ??
              '';

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
          message
              .substring(
                'Exception:'.length,
              )
              .trim();

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