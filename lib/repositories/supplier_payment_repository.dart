import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/supplier_payment_model.dart';

class SupplierPaymentRepository {
  final FirebaseFirestore _firestore;

  SupplierPaymentRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _payments(
    String businessId,
  ) {
    final String normalizedBusinessId = businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    return _firestore
        .collection('businesses')
        .doc(normalizedBusinessId)
        .collection('supplierPayments');
  }

  Future<SupplierPaymentModel> createPayment(
    SupplierPaymentModel payment,
  ) async {
    _validatePayment(payment);

    final String businessId = payment.businessId.trim();

    final DocumentReference<Map<String, dynamic>> document =
        _payments(businessId).doc();

    final SupplierPaymentModel paymentWithId = payment.copyWith(
      id: document.id,
    );

    await document.set(
      paymentWithId.toMap(),
    );

    return paymentWithId;
  }

  Future<SupplierPaymentModel?> getPayment({
    required String businessId,
    required String paymentId,
  }) async {
    final String normalizedPaymentId = paymentId.trim();

    if (normalizedPaymentId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _payments(businessId)
            .doc(normalizedPaymentId)
            .get();

    if (!snapshot.exists) {
      return null;
    }

    return SupplierPaymentModel.fromFirestore(snapshot);
  }

  Future<List<SupplierPaymentModel>> getPayments({
    required String businessId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _payments(businessId)
            .orderBy('date', descending: true)
            .get();

    return snapshot.docs
        .map(SupplierPaymentModel.fromFirestore)
        .toList();
  }

  Stream<List<SupplierPaymentModel>> watchPayments({
    required String businessId,
  }) {
    return _payments(businessId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            return snapshot.docs
                .map(SupplierPaymentModel.fromFirestore)
                .toList();
          },
        );
  }

  Future<List<SupplierPaymentModel>> getSupplierPayments({
    required String businessId,
    required String supplierId,
  }) async {
    final String normalizedSupplierId = supplierId.trim();

    if (normalizedSupplierId.isEmpty) {
      return <SupplierPaymentModel>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _payments(businessId)
            .where(
              'supplierId',
              isEqualTo: normalizedSupplierId,
            )
            .get();

    final payments = snapshot.docs
        .map(SupplierPaymentModel.fromFirestore)
        .toList();

    payments.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return payments;
  }

  Stream<List<SupplierPaymentModel>> watchSupplierPayments({
    required String businessId,
    required String supplierId,
  }) {
    final String normalizedSupplierId = supplierId.trim();

    if (normalizedSupplierId.isEmpty) {
      return Stream<List<SupplierPaymentModel>>.value(
        <SupplierPaymentModel>[],
      );
    }

    return _payments(businessId)
        .where(
          'supplierId',
          isEqualTo: normalizedSupplierId,
        )
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            final payments = snapshot.docs
                .map(SupplierPaymentModel.fromFirestore)
                .toList();

            payments.sort(
              (a, b) => b.date.compareTo(a.date),
            );

            return payments;
          },
        );
  }

  Future<void> updatePayment(
    SupplierPaymentModel payment,
  ) async {
    _validatePayment(payment);

    final String paymentId = payment.id.trim();

    if (paymentId.isEmpty) {
      throw ArgumentError(
        'Payment ID cannot be empty when updating a payment.',
      );
    }

    await _payments(payment.businessId)
        .doc(paymentId)
        .update(
          payment.toMap(),
        );
  }

  Future<void> deletePayment({
    required String businessId,
    required String paymentId,
  }) async {
    final String normalizedPaymentId = paymentId.trim();

    if (normalizedPaymentId.isEmpty) {
      throw ArgumentError(
        'Payment ID cannot be empty.',
      );
    }

    await _payments(businessId)
        .doc(normalizedPaymentId)
        .delete();
  }

  Future<double> getTotalPaid({
    required String businessId,
  }) async {
    final List<SupplierPaymentModel> payments =
        await getPayments(
      businessId: businessId,
    );

    return payments.fold<double>(
      0,
      (
        double total,
        SupplierPaymentModel payment,
      ) {
        return total + payment.amount;
      },
    );
  }

  Future<double> getSupplierTotalPaid({
    required String businessId,
    required String supplierId,
  }) async {
    final List<SupplierPaymentModel> payments =
        await getSupplierPayments(
      businessId: businessId,
      supplierId: supplierId,
    );

    return payments.fold<double>(
      0,
      (
        double total,
        SupplierPaymentModel payment,
      ) {
        return total + payment.amount;
      },
    );
  }

  Future<List<SupplierPaymentModel>> searchPayments({
    required String businessId,
    required String query,
  }) async {
    final String normalizedQuery =
        query.trim().toLowerCase();

    final List<SupplierPaymentModel> payments =
        await getPayments(
      businessId: businessId,
    );

    if (normalizedQuery.isEmpty) {
      return payments;
    }

    return payments.where(
      (SupplierPaymentModel payment) {
        final String supplierName =
            payment.supplierName.toLowerCase();

        final String supplierId =
            payment.supplierId.toLowerCase();

        final String method =
            payment.paymentMethod.toLowerCase();

        final String reference =
            payment.transactionReference.toLowerCase();

        final String notes =
            payment.notes.toLowerCase();

        final String amount =
            payment.amount.toStringAsFixed(2);

        return supplierName.contains(normalizedQuery) ||
            supplierId.contains(normalizedQuery) ||
            method.contains(normalizedQuery) ||
            reference.contains(normalizedQuery) ||
            notes.contains(normalizedQuery) ||
            amount.contains(normalizedQuery);
      },
    ).toList();
  }

  void _validatePayment(
    SupplierPaymentModel payment,
  ) {
    if (payment.businessId.trim().isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (payment.supplierId.trim().isEmpty) {
      throw ArgumentError(
        'Supplier ID cannot be empty.',
      );
    }

    if (payment.supplierName.trim().isEmpty) {
      throw ArgumentError(
        'Supplier name cannot be empty.',
      );
    }

    if (!payment.amount.isFinite || payment.amount <= 0) {
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
}