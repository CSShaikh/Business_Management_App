import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_model.dart';
import 'base_repository.dart';

class PaymentRepository extends BaseRepository {
  PaymentRepository({
    super.firestore,
  });

  CollectionReference<Map<String, dynamic>> _payments(
    String businessId,
  ) {
    final normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    return firestore
        .collection('businesses')
        .doc(normalizedBusinessId)
        .collection('payments');
  }

  Future<PaymentModel> createPayment(
    PaymentModel payment,
  ) async {
    _validatePayment(payment);

    final businessId =
        payment.businessId.trim();

    final collectionRef =
        _payments(businessId);

    final documentRef =
        payment.id.trim().isEmpty
            ? collectionRef.doc()
            : collectionRef.doc(
                payment.id.trim(),
              );

    final paymentToSave = PaymentModel(
      id: documentRef.id,
      businessId: businessId,
      customerId:
          payment.customerId.trim(),
      customerName:
          payment.customerName.trim(),
      amount: payment.amount,
      date: payment.date,
      paymentMethod:
          payment.paymentMethod.trim(),
      transactionReference:
          payment.transactionReference.trim(),
      notes: payment.notes.trim(),
      createdAt: payment.createdAt,
    );

    await documentRef.set(
      _toMap(paymentToSave),
    );

    return paymentToSave;
  }

  Future<PaymentModel?> getPayment({
    required String businessId,
    required String paymentId,
  }) async {
    final normalizedBusinessId =
        businessId.trim();

    final normalizedPaymentId =
        paymentId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedPaymentId.isEmpty) {
      throw ArgumentError(
        'Payment ID cannot be empty.',
      );
    }

    final snapshot = await _payments(
      normalizedBusinessId,
    )
        .doc(normalizedPaymentId)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return _fromMap(
      snapshot.id,
      data,
      fallbackBusinessId:
          normalizedBusinessId,
    );
  }

  Future<List<PaymentModel>> getPayments({
    required String businessId,
  }) async {
    final normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    final snapshot = await _payments(
      normalizedBusinessId,
    )
        .orderBy(
          'date',
          descending: true,
        )
        .get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.id,
            doc.data(),
            fallbackBusinessId:
                normalizedBusinessId,
          ),
        )
        .toList();
  }

  Stream<List<PaymentModel>> watchPayments({
    required String businessId,
  }) {
    final normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    return _payments(
      normalizedBusinessId,
    )
        .orderBy(
          'date',
          descending: true,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _fromMap(
                  doc.id,
                  doc.data(),
                  fallbackBusinessId:
                      normalizedBusinessId,
                ),
              )
              .toList(),
        );
  }

  Future<List<PaymentModel>> getCustomerPayments({
    required String businessId,
    required String customerId,
  }) async {
    final normalizedBusinessId =
        businessId.trim();

    final normalizedCustomerId =
        customerId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedCustomerId.isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    final snapshot = await _payments(
      normalizedBusinessId,
    )
        .where(
          'customerId',
          isEqualTo: normalizedCustomerId,
        )
        .orderBy(
          'date',
          descending: true,
        )
        .get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.id,
            doc.data(),
            fallbackBusinessId:
                normalizedBusinessId,
          ),
        )
        .toList();
  }

  Stream<List<PaymentModel>> watchCustomerPayments({
    required String businessId,
    required String customerId,
  }) {
    final normalizedBusinessId =
        businessId.trim();

    final normalizedCustomerId =
        customerId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedCustomerId.isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    return _payments(
      normalizedBusinessId,
    )
        .where(
          'customerId',
          isEqualTo: normalizedCustomerId,
        )
        .orderBy(
          'date',
          descending: true,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _fromMap(
                  doc.id,
                  doc.data(),
                  fallbackBusinessId:
                      normalizedBusinessId,
                ),
              )
              .toList(),
        );
  }

  Future<void> updatePayment(
    PaymentModel payment,
  ) async {
    _validatePayment(payment);

    final normalizedPaymentId =
        payment.id.trim();

    if (normalizedPaymentId.isEmpty) {
      throw ArgumentError(
        'Payment ID cannot be empty when updating a payment.',
      );
    }

    final normalizedBusinessId =
        payment.businessId.trim();

    final existingDocument =
        await _payments(
      normalizedBusinessId,
    )
            .doc(normalizedPaymentId)
            .get();

    if (!existingDocument.exists) {
      throw StateError(
        'Payment not found.',
      );
    }

    final existingData =
        existingDocument.data();

    if (existingData == null) {
      throw StateError(
        'Payment data not found.',
      );
    }

    final existingPayment = _fromMap(
      existingDocument.id,
      existingData,
      fallbackBusinessId:
          normalizedBusinessId,
    );

    final updatedPayment = PaymentModel(
      id: existingPayment.id,
      businessId:
          existingPayment.businessId
                  .trim()
                  .isNotEmpty
              ? existingPayment.businessId
                  .trim()
              : normalizedBusinessId,
      customerId:
          payment.customerId.trim(),
      customerName:
          payment.customerName.trim(),
      amount: payment.amount,
      date: payment.date,
      paymentMethod:
          payment.paymentMethod.trim(),
      transactionReference:
          payment.transactionReference.trim(),
      notes: payment.notes.trim(),
      createdAt:
          existingPayment.createdAt,
    );

    await _payments(
      updatedPayment.businessId,
    )
        .doc(updatedPayment.id)
        .update(
          _toMap(updatedPayment),
        );
  }

  Future<void> deletePayment({
    required String businessId,
    required String paymentId,
  }) async {
    final normalizedBusinessId =
        businessId.trim();

    final normalizedPaymentId =
        paymentId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedPaymentId.isEmpty) {
      throw ArgumentError(
        'Payment ID cannot be empty.',
      );
    }

    final document = await _payments(
      normalizedBusinessId,
    )
        .doc(normalizedPaymentId)
        .get();

    if (!document.exists) {
      throw StateError(
        'Payment not found.',
      );
    }

    await document.reference.delete();
  }

  Future<List<PaymentModel>> searchPayments({
    required String businessId,
    required String query,
  }) async {
    final normalizedQuery =
        query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return getPayments(
        businessId: businessId,
      );
    }

    final payments = await getPayments(
      businessId: businessId,
    );

    return payments.where(
      (payment) {
        final customerName =
            payment.customerName
                .toLowerCase();

        final paymentMethod =
            payment.paymentMethod
                .toLowerCase();

        final transactionReference =
            payment.transactionReference
                .toLowerCase();

        final notes =
            payment.notes.toLowerCase();

        final amount =
            payment.amount
                .toStringAsFixed(2);

        return customerName.contains(
              normalizedQuery,
            ) ||
            paymentMethod.contains(
              normalizedQuery,
            ) ||
            transactionReference.contains(
              normalizedQuery,
            ) ||
            notes.contains(
              normalizedQuery,
            ) ||
            amount.contains(
              normalizedQuery,
            );
      },
    ).toList();
  }

  Future<double> getTotalPayments({
    required String businessId,
  }) async {
    final payments = await getPayments(
      businessId: businessId,
    );

    return payments.fold<double>(
      0,
      (total, payment) =>
          total + payment.amount,
    );
  }

  Future<double> getCustomerTotalPayments({
    required String businessId,
    required String customerId,
  }) async {
    final payments =
        await getCustomerPayments(
      businessId: businessId,
      customerId: customerId,
    );

    return payments.fold<double>(
      0,
      (total, payment) =>
          total + payment.amount,
    );
  }

  Future<List<PaymentModel>> getTodayPayments({
    required String businessId,
  }) async {
    final normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    final now = DateTime.now();

    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final endOfDay = startOfDay.add(
      const Duration(days: 1),
    );

    final snapshot = await _payments(
      normalizedBusinessId,
    )
        .where(
          'date',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(
            startOfDay,
          ),
        )
        .where(
          'date',
          isLessThan:
              Timestamp.fromDate(
            endOfDay,
          ),
        )
        .orderBy(
          'date',
          descending: true,
        )
        .get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.id,
            doc.data(),
            fallbackBusinessId:
                normalizedBusinessId,
          ),
        )
        .toList();
  }

  Future<double> getTodayPaymentsTotal({
    required String businessId,
  }) async {
    final payments =
        await getTodayPayments(
      businessId: businessId,
    );

    return payments.fold<double>(
      0,
      (total, payment) =>
          total + payment.amount,
    );
  }

  Future<List<PaymentModel>> getPaymentsByMethod({
    required String businessId,
    required String paymentMethod,
  }) async {
    final normalizedBusinessId =
        businessId.trim();

    final normalizedMethod =
        paymentMethod.trim();

    if (normalizedBusinessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (normalizedMethod.isEmpty) {
      return getPayments(
        businessId: normalizedBusinessId,
      );
    }

    final snapshot = await _payments(
      normalizedBusinessId,
    )
        .where(
          'paymentMethod',
          isEqualTo: normalizedMethod,
        )
        .orderBy(
          'date',
          descending: true,
        )
        .get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.id,
            doc.data(),
            fallbackBusinessId:
                normalizedBusinessId,
          ),
        )
        .toList();
  }

  Map<String, dynamic> _toMap(
    PaymentModel payment,
  ) {
    return {
      'businessId':
          payment.businessId.trim(),
      'customerId':
          payment.customerId.trim(),
      'customerName':
          payment.customerName.trim(),
      'amount':
          payment.amount,
      'date':
          Timestamp.fromDate(
        payment.date,
      ),
      'paymentMethod':
          payment.paymentMethod.trim(),
      'transactionReference':
          payment.transactionReference.trim(),
      'notes':
          payment.notes.trim(),
      'createdAt':
          Timestamp.fromDate(
        payment.createdAt,
      ),
    };
  }

  PaymentModel _fromMap(
    String id,
    Map<String, dynamic> map, {
    String fallbackBusinessId = '',
  }) {
    final storedBusinessId =
        (map['businessId'] ?? '')
            .toString()
            .trim();

    return PaymentModel(
      id: id.trim(),
      businessId:
          storedBusinessId.isNotEmpty
              ? storedBusinessId
              : fallbackBusinessId.trim(),
      customerId:
          (map['customerId'] ?? '')
              .toString()
              .trim(),
      customerName:
          (map['customerName'] ?? '')
              .toString()
              .trim(),
      amount:
          _toDouble(map['amount']),
      date:
          dateFromFirestore(
        map['date'],
      ),
      paymentMethod:
          (map['paymentMethod'] ?? '')
              .toString()
              .trim(),
      transactionReference:
          (map['transactionReference'] ?? '')
              .toString()
              .trim(),
      notes:
          (map['notes'] ?? '')
              .toString()
              .trim(),
      createdAt:
          dateFromFirestore(
        map['createdAt'],
      ),
    );
  }

  double _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      final result =
          value.toDouble();

      return result.isFinite
          ? result
          : 0;
    }

    if (value is String) {
      final result =
          double.tryParse(
        value.trim(),
      );

      if (result != null &&
          result.isFinite) {
        return result;
      }
    }

    return 0;
  }

  void _validatePayment(
    PaymentModel payment,
  ) {
    if (payment.businessId
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (payment.customerId
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    if (payment.customerName
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'Customer name cannot be empty.',
      );
    }

    if (!payment.amount.isFinite) {
      throw ArgumentError(
        'Payment amount must be a valid number.',
      );
    }

    if (payment.amount <= 0) {
      throw ArgumentError(
        'Payment amount must be greater than zero.',
      );
    }

    if (payment.paymentMethod
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'Payment method cannot be empty.',
      );
    }
  }
}