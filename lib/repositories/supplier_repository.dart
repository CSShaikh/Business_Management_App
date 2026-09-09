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
        .doc(businessId.trim())
        .collection('suppliers');
  }

  // ---------------------------------------------------------------------------
  // Create Supplier
  // ---------------------------------------------------------------------------

  Future<void> createSupplier(
    SupplierModel supplier,
  ) async {
    final String businessId = supplier.businessId.trim();
    final String supplierId = supplier.id.trim();
    final String name = supplier.name.trim();

    _validateIds(
      businessId: businessId,
      supplierId: supplierId,
    );

    if (name.isEmpty) {
      throw ArgumentError(
        'Supplier name cannot be empty.',
      );
    }

    final DateTime now = DateTime.now();

    await _suppliers(businessId)
        .doc(supplierId)
        .set({
      'id': supplierId,
      'businessId': businessId,
      'name': name,
      'contactPerson': supplier.contactPerson.trim(),
      'mobile': supplier.mobile.trim(),
      'email': supplier.email.trim(),
      'address': supplier.address.trim(),
      'gstNumber': supplier.gstNumber.trim(),
      'notes': supplier.notes.trim(),
      'createdAt': Timestamp.fromDate(
        supplier.createdAt,
      ),
      'updatedAt': Timestamp.fromDate(
        now,
      ),
    });
  }

  // ---------------------------------------------------------------------------
  // Get Supplier
  // ---------------------------------------------------------------------------

  Future<SupplierModel?> getSupplier(
    String businessId,
    String supplierId,
  ) async {
    final String normalizedBusinessId =
        businessId.trim();
    final String normalizedSupplierId =
        supplierId.trim();

    if (normalizedBusinessId.isEmpty ||
        normalizedSupplierId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _suppliers(normalizedBusinessId)
            .doc(normalizedSupplierId)
            .get();

    if (!snapshot.exists ||
        snapshot.data() == null) {
      return null;
    }

    return _fromMap(
      snapshot.data()!,
      snapshot.id,
      normalizedBusinessId,
    );
  }

  // ---------------------------------------------------------------------------
  // Get All Suppliers
  // ---------------------------------------------------------------------------

  Future<List<SupplierModel>> getSuppliers(
    String businessId,
  ) async {
    final String normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _suppliers(normalizedBusinessId)
            .orderBy('name')
            .get();

    return snapshot.docs
        .map(
          (doc) => _fromMap(
            doc.data(),
            doc.id,
            normalizedBusinessId,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Watch Suppliers
  // ---------------------------------------------------------------------------

  Stream<List<SupplierModel>> watchSuppliers(
    String businessId,
  ) {
    final String normalizedBusinessId =
        businessId.trim();

    if (normalizedBusinessId.isEmpty) {
      return const Stream<List<SupplierModel>>.empty();
    }

    return _suppliers(normalizedBusinessId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _fromMap(
                  doc.data(),
                  doc.id,
                  normalizedBusinessId,
                ),
              )
              .toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Update Supplier
  // ---------------------------------------------------------------------------

  Future<void> updateSupplier(
    SupplierModel supplier,
  ) async {
    final String businessId =
        supplier.businessId.trim();
    final String supplierId =
        supplier.id.trim();
    final String name =
        supplier.name.trim();

    _validateIds(
      businessId: businessId,
      supplierId: supplierId,
    );

    if (name.isEmpty) {
      throw ArgumentError(
        'Supplier name cannot be empty.',
      );
    }

    final DocumentReference<Map<String, dynamic>> document =
        _suppliers(businessId).doc(supplierId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await document.get();

    if (!snapshot.exists ||
        snapshot.data() == null) {
      throw StateError(
        'Supplier not found.',
      );
    }

    await document.update({
      'name': name,
      'contactPerson':
          supplier.contactPerson.trim(),
      'mobile': supplier.mobile.trim(),
      'email': supplier.email.trim(),
      'address': supplier.address.trim(),
      'gstNumber': supplier.gstNumber.trim(),
      'notes': supplier.notes.trim(),
      'updatedAt': Timestamp.fromDate(
        DateTime.now(),
      ),
    });
  }

  // ---------------------------------------------------------------------------
  // Delete Supplier
  // ---------------------------------------------------------------------------

  Future<void> deleteSupplier({
    required String businessId,
    required String supplierId,
  }) async {
    final String normalizedBusinessId =
        businessId.trim();
    final String normalizedSupplierId =
        supplierId.trim();

    _validateIds(
      businessId: normalizedBusinessId,
      supplierId: normalizedSupplierId,
    );

    await _suppliers(normalizedBusinessId)
        .doc(normalizedSupplierId)
        .delete();
  }

  // ---------------------------------------------------------------------------
  // Firestore -> Model
  // ---------------------------------------------------------------------------

  SupplierModel _fromMap(
    Map<String, dynamic> data,
    String documentId,
    String businessId,
  ) {
    return SupplierModel(
      id: _stringValue(
        data['id'],
        fallback: documentId,
      ),
      businessId: _stringValue(
        data['businessId'],
        fallback: businessId,
      ),
      name: _stringValue(
        data['name'],
      ),
      contactPerson: _stringValue(
        data['contactPerson'],
      ),
      mobile: _stringValue(
        data['mobile'],
      ),
      email: _stringValue(
        data['email'],
      ),
      address: _stringValue(
        data['address'],
      ),
      gstNumber: _stringValue(
        data['gstNumber'],
      ),
      notes: _stringValue(
        data['notes'],
      ),
      createdAt: dateFromFirestore(
        data['createdAt'],
      ),
      updatedAt: dateFromFirestore(
        data['updatedAt'],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  void _validateIds({
    required String businessId,
    required String supplierId,
  }) {
    if (businessId.isEmpty) {
      throw ArgumentError(
        'Business ID cannot be empty.',
      );
    }

    if (supplierId.isEmpty) {
      throw ArgumentError(
        'Supplier ID cannot be empty.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Safe String Conversion
  // ---------------------------------------------------------------------------

  String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value is String) {
      return value.trim();
    }

    if (value == null) {
      return fallback;
    }

    return value.toString().trim();
  }
}
