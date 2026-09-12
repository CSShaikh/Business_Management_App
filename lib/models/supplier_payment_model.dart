import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierPaymentModel {
  final String id;
  final String businessId;
  final String supplierId;
  final String supplierName;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final String transactionReference;
  final String notes;
  final DateTime createdAt;

  const SupplierPaymentModel({
    required this.id,
    required this.businessId,
    required this.supplierId,
    required this.supplierName,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.transactionReference = '',
    this.notes = '',
    required this.createdAt,
  });

  SupplierPaymentModel copyWith({
    String? id,
    String? businessId,
    String? supplierId,
    String? supplierName,
    double? amount,
    DateTime? date,
    String? paymentMethod,
    String? transactionReference,
    String? notes,
    DateTime? createdAt,
  }) {
    return SupplierPaymentModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionReference:
          transactionReference ?? this.transactionReference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'businessId': businessId,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'paymentMethod': paymentMethod,
      'transactionReference': transactionReference,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SupplierPaymentModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return SupplierPaymentModel(
      id: id,
      businessId: _readString(map['businessId']),
      supplierId: _readString(map['supplierId']),
      supplierName: _readString(map['supplierName']),
      amount: _readDouble(map['amount']),
      date: _readDateTime(
        map['date'],
        fallback: DateTime.now(),
      ),
      paymentMethod: _readString(map['paymentMethod']),
      transactionReference:
          _readString(map['transactionReference']),
      notes: _readString(map['notes']),
      createdAt: _readDateTime(
        map['createdAt'],
        fallback: DateTime.now(),
      ),
    );
  }

  factory SupplierPaymentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data =
        snapshot.data() ?? <String, dynamic>{};

    return SupplierPaymentModel.fromMap(
      snapshot.id,
      data,
    );
  }

  static String _readString(Object? value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }

    return 0;
  }

  static DateTime _readDateTime(
    Object? value, {
    required DateTime fallback,
  }) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(
        value.trim(),
      );

      if (parsed != null) {
        return parsed;
      }
    }

    return fallback;
  }

  @override
  String toString() {
    return 'SupplierPaymentModel('
        'id: $id, '
        'businessId: $businessId, '
        'supplierId: $supplierId, '
        'supplierName: $supplierName, '
        'amount: $amount, '
        'date: $date, '
        'paymentMethod: $paymentMethod, '
        'transactionReference: $transactionReference, '
        'notes: $notes, '
        'createdAt: $createdAt'
        ')';
  }
}