import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/supplier_model.dart';
import 'base_repository.dart';

class SupplierRepository extends BaseRepository {
  SupplierRepository({
    super.firestore,
  });

  CollectionReference<Map<String, dynamic>> _suppliers(
    String businessId,
  ) {
    return firestore
        .collection('businesses')
        .doc(businessId)
        .collection('suppliers');
  }

  Future<void> createSupplier(
    SupplierModel supplier,
  ) async {
    await _suppliers(supplier.businessId)
        .doc(supplier.id)
        .set({
      'id': supplier.id,
      'businessId': supplier.businessId,
      'name': supplier.name,
      'contactPerson': supplier.contactPerson,
      'mobile': supplier.mobile,
      'email': supplier.email,
      'address': supplier.address,
      'gstNumber': supplier.gstNumber,
      'notes': supplier.notes,
      'createdAt': Timestamp.fromDate(supplier.createdAt),
      'updatedAt': Timestamp.fromDate(supplier.updatedAt),
    });
  }

  Future<SupplierModel?> getSupplier(
    String businessId,
    String supplierId,
  ) async {
    final snapshot =
        await _suppliers(businessId).doc(supplierId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.data()!,
      snapshot.id,
    );
  }

  Future<List<SupplierModel>> getSuppliers(
    String businessId,
  ) async {
    final snapshot =
        await _suppliers(businessId).orderBy('name').get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.data(),
            doc.id,
          ),
        )
        .toList();
  }

  Stream<List<SupplierModel>> watchSuppliers(
    String businessId,
  ) {
    return _suppliers(businessId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<void> updateSupplier(
    SupplierModel supplier,
  ) async {
    await _suppliers(supplier.businessId)
        .doc(supplier.id)
        .update({
      'name': supplier.name,
      'contactPerson': supplier.contactPerson,
      'mobile': supplier.mobile,
      'email': supplier.email,
      'address': supplier.address,
      'gstNumber': supplier.gstNumber,
      'notes': supplier.notes,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteSupplier({
    required String businessId,
    required String supplierId,
  }) async {
    await _suppliers(businessId)
        .doc(supplierId)
        .delete();
  }

  SupplierModel _fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return SupplierModel(
      id: data['id'] as String? ?? documentId,
      businessId: data['businessId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      contactPerson: data['contactPerson'] as String? ?? '',
      mobile: data['mobile'] as String? ?? '',
      email: data['email'] as String? ?? '',
      address: data['address'] as String? ?? '',
      gstNumber: data['gstNumber'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      createdAt: dateFromFirestore(data['createdAt']),
      updatedAt: dateFromFirestore(data['updatedAt']),
    );
  }
}